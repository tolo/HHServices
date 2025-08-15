import Foundation

/// Resolves service information including hostname, port, and addresses
public final class ServiceResolver: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let service: Service
    private let includeP2P: Bool
    private let timeout: TimeInterval
    
    private let lock = NSLock()
    private var resolveDNSService: DNSService?
    private var addressDNSService: DNSService?
    private var isResolving = false
    private var timeoutTask: Task<Void, Never>?
    
    // For delegate support
    public weak var delegate: ServiceResolverDelegate?
    
    // MARK: - Initialization
    
    /// Initialize a service resolver
    /// - Parameters:
    ///   - service: The service to resolve
    ///   - includeP2P: Whether to include P2P interfaces
    ///   - timeout: Resolution timeout in seconds (default: 30)
    public init(service: Service, includeP2P: Bool = false, timeout: TimeInterval = 30.0) {
        self.service = service
        self.includeP2P = includeP2P
        self.timeout = timeout
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Resolve the service (async/await)
    /// - Returns: The resolved service with address information
    @discardableResult
    public func resolve() async throws -> Service {
        try startResolving()
        
        // Wait for resolution to complete
        return try await withCheckedThrowingContinuation { continuation in
            var observer: NSObjectProtocol?
            var errorObserver: NSObjectProtocol?
            
            observer = NotificationCenter.default.addObserver(
                forName: .serviceResolverDidResolve,
                object: self,
                queue: .main
            ) { [weak self] _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                if let errorObserver = errorObserver {
                    NotificationCenter.default.removeObserver(errorObserver)
                }
                
                if let service = self?.service {
                    continuation.resume(returning: service)
                } else {
                    continuation.resume(throwing: HHServicesError.failedToResolve)
                }
            }
            
            errorObserver = NotificationCenter.default.addObserver(
                forName: .serviceResolverDidFail,
                object: self,
                queue: .main
            ) { notification in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                if let errorObserver = errorObserver {
                    NotificationCenter.default.removeObserver(errorObserver)
                }
                
                let error = notification.userInfo?["error"] as? Error ?? HHServicesError.failedToResolve
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Start resolving the service (delegate-based)
    public func startResolving() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isResolving else {
            throw HHServicesError.alreadyStarted
        }
        
        // Clear any existing addresses
        service.clearAddresses()
        
        // Start resolution
        let dns = DNSService()
        
        try dns.resolve(
            name: service.name,
            type: service.type,
            domain: service.domain,
            interfaceIndex: service.interfaceIndex,
            includeP2P: includeP2P
        ) { [weak self] result in
            self?.handleResolveResult(result)
        }
        
        resolveDNSService = dns
        isResolving = true
        
        // Set up timeout
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.timeout ?? 30) * 1_000_000_000)
            self?.handleTimeout()
        }
    }
    
    /// Stop resolving
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isResolving = false
        timeoutTask?.cancel()
        timeoutTask = nil
        resolveDNSService?.stop()
        resolveDNSService = nil
        addressDNSService?.stop()
        addressDNSService = nil
    }
    
    // MARK: - Private Methods
    
    private func handleResolveResult(_ result: ResolveResult) {
        switch result {
        case .success(let info):
            handleResolveSuccess(info)
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func handleResolveSuccess(_ info: ResolveInfo) {
        // Update service with resolved info
        service.updateResolvedInfo(
            hostName: info.hostName,
            port: info.port,
            txtData: info.txtData
        )
        
        // Now get address info
        let dns = DNSService()
        
        do {
            try dns.getAddressInfo(
                hostName: info.hostName,
                interfaceIndex: info.interfaceIndex
            ) { [weak self] result in
                self?.handleAddressResult(result)
            }
            
            lock.lock()
            addressDNSService = dns
            lock.unlock()
            
        } catch {
            handleError(error)
        }
    }
    
    private func handleAddressResult(_ result: AddressResult) {
        switch result {
        case .success(let info):
            service.addAddress(info.address)
            
            // If no more addresses coming, we're done
            if !info.moreComing {
                handleResolutionComplete()
            }
            
        case .failure(let error):
            // Address resolution failed, but we still have hostname/port
            // Consider this a success if we have basic info
            if service.isResolved {
                handleResolutionComplete()
            } else {
                handleError(error)
            }
        }
    }
    
    private func handleResolutionComplete() {
        stop()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.serviceResolver(self, didResolveService: self.service)
        }
        
        // Post notification for async/await
        NotificationCenter.default.post(
            name: .serviceResolverDidResolve,
            object: self
        )
    }
    
    private func handleError(_ error: Error) {
        stop()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.serviceResolver(self, didFailWithError: error)
        }
        
        // Post notification for async/await
        NotificationCenter.default.post(
            name: .serviceResolverDidFail,
            object: self,
            userInfo: ["error": error]
        )
    }
    
    private func handleTimeout() {
        guard isResolving else { return }
        handleError(HHServicesError.resolveTimeout)
    }
}

// MARK: - Service Extension for Resolution

public extension Service {
    /// Resolve this service to get address information
    /// - Parameters:
    ///   - includeP2P: Whether to include P2P interfaces
    ///   - timeout: Resolution timeout in seconds
    /// - Returns: Self with resolved information
    @discardableResult
    func resolve(includeP2P: Bool = false, timeout: TimeInterval = 30.0) async throws -> Service {
        let resolver = ServiceResolver(service: self, includeP2P: includeP2P, timeout: timeout)
        try await resolver.resolve()
        return self
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for service resolution events
public protocol ServiceResolverDelegate: AnyObject {
    func serviceResolver(_ resolver: ServiceResolver, didResolveService service: Service)
    func serviceResolver(_ resolver: ServiceResolver, didFailWithError error: Error)
}

// MARK: - Notifications

private extension Notification.Name {
    static let serviceResolverDidResolve = Notification.Name("HHServices.ServiceResolverDidResolve")
    static let serviceResolverDidFail = Notification.Name("HHServices.ServiceResolverDidFail")
}