import Foundation

/// Publishes a service for discovery on the network
public final class ServicePublisher: @unchecked Sendable {
    
    // MARK: - Properties
    
    public let name: String
    public let type: String
    public let domain: String
    public let port: UInt16
    public let interfaceIndex: UInt32
    
    private let lock = NSLock()
    private var dnsService: DNSService?
    private var txtRecord: TXTRecord?
    private var isPublished = false
    private var registeredName: String?
    
    // For delegate support
    public weak var delegate: ServicePublisherDelegate?
    
    // MARK: - Initialization
    
    /// Initialize a service publisher
    /// - Parameters:
    ///   - name: The service name (empty string for automatic naming)
    ///   - type: The service type (e.g., "_http._tcp.")
    ///   - domain: The domain to publish in (default: empty for all)
    ///   - port: The port number for the service
    ///   - interfaceIndex: The interface to publish on (0 for all)
    public init(
        name: String = "",
        type: String,
        domain: String = "",
        port: UInt16,
        interfaceIndex: UInt32 = 0
    ) {
        self.name = name
        self.type = type
        self.domain = domain
        self.port = port
        self.interfaceIndex = interfaceIndex
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Start publishing the service
    public func publish() async throws {
        try startPublishing()
        
        // Wait for initial registration
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .servicePublisherDidPublish,
                object: self,
                queue: .main
            ) { _ in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume()
            }
            
            // Set timeout
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(throwing: HHServicesError.failedToPublish)
            }
        }
    }
    
    /// Start publishing the service (delegate-based)
    public func startPublishing() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isPublished else {
            throw HHServicesError.alreadyStarted
        }
        
        // Validate service name if provided
        if !name.isEmpty {
            guard ServiceValidation.isValidServiceName(name) else {
                throw HHServicesError.invalidServiceName
            }
        }
        
        // Validate service type
        guard ServiceValidation.isValidServiceType(type) else {
            throw HHServicesError.invalidServiceType
        }
        
        // Validate domain
        guard ServiceValidation.isValidDomain(domain) else {
            throw HHServicesError.invalidDomain
        }
        
        let dns = DNSService()
        
        try dns.register(
            name: name,
            type: type,
            domain: domain,
            port: port,
            txtData: txtRecord?.data,
            interfaceIndex: interfaceIndex
        ) { [weak self] result in
            self?.handleRegisterResult(result)
        }
        
        dnsService = dns
        isPublished = true
    }
    
    /// Stop publishing the service
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPublished = false
        registeredName = nil
        dnsService?.stop()
        dnsService = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.servicePublisherDidStop(self)
        }
    }
    
    /// Publish over Bluetooth only
    public func publishBluetoothOnly() async throws {
        let publisher = ServicePublisher(
            name: name,
            type: type,
            domain: domain,
            port: port,
            interfaceIndex: kHHServiceInterfaceIndexP2P
        )
        publisher.setTXTRecord(txtRecord?.dictionary ?? [:])
        try await publisher.publish()
    }
    
    /// Update the TXT record for the service
    /// - Parameter dictionary: Dictionary of key-value pairs for the TXT record
    public func setTXTRecord(_ dictionary: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        
        txtRecord = TXTRecord(dictionary: dictionary)
        
        // If already publishing, update the record
        // Note: DNS-SD doesn't provide a direct update method, would need to re-register
        if isPublished {
            // For simplicity, we'll just store it for next publish
            // In production, you might want to stop and restart with new TXT
        }
    }
    
    /// Get the actual registered name (may differ from requested name)
    public var actualName: String? {
        lock.lock()
        defer { lock.unlock() }
        return registeredName ?? name
    }
    
    // MARK: - Private Methods
    
    private func handleRegisterResult(_ result: RegisterResult) {
        switch result {
        case .success(let info):
            handleRegisterSuccess(info)
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func handleRegisterSuccess(_ info: RegisterInfo) {
        lock.lock()
        registeredName = info.name
        lock.unlock()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.servicePublisher(self, didPublishWithName: info.name)
        }
        
        // Post notification for async/await
        NotificationCenter.default.post(
            name: .servicePublisherDidPublish,
            object: self,
            userInfo: ["name": info.name]
        )
    }
    
    private func handleError(_ error: Error) {
        stop()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.servicePublisher(self, didFailWithError: error)
        }
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for service publishing events
public protocol ServicePublisherDelegate: AnyObject {
    func servicePublisher(_ publisher: ServicePublisher, didPublishWithName name: String)
    func servicePublisherDidStop(_ publisher: ServicePublisher)
    func servicePublisher(_ publisher: ServicePublisher, didFailWithError error: Error)
}

// Optional methods with default implementations
public extension ServicePublisherDelegate {
    func servicePublisherDidStop(_ publisher: ServicePublisher) {}
    func servicePublisher(_ publisher: ServicePublisher, didFailWithError error: Error) {}
}

// MARK: - Notifications

private extension Notification.Name {
    static let servicePublisherDidPublish = Notification.Name("HHServices.ServicePublisherDidPublish")
}