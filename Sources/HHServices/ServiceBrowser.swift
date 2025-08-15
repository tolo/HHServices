import Foundation
import Combine

/// Discovers services on the network using DNS-SD
public final class ServiceBrowser: @unchecked Sendable {
    
    // MARK: - Properties
    
    public let serviceType: String
    public let domain: String
    public let interfaceIndex: UInt32
    
    private let lock = NSLock()
    private var dnsService: DNSService?
    private var discoveredServices: Set<Service> = []
    private var isActive = false
    
    // For async/await support
    private var continuations: [UUID: AsyncStream<DiscoveryEvent>.Continuation] = [:]
    
    // For Combine support
    private let subject = PassthroughSubject<DiscoveryEvent, Error>()
    
    // For delegate support
    public weak var delegate: ServiceBrowserDelegate?
    
    // MARK: - Initialization
    
    /// Initialize a service browser
    /// - Parameters:
    ///   - type: The service type to browse for (e.g., "_http._tcp.")
    ///   - domain: The domain to browse (default: "local.")
    ///   - interfaceIndex: The interface to use (0 for all interfaces)
    public init(type: String, domain: String = "local.", interfaceIndex: UInt32 = 0) {
        self.serviceType = type
        self.domain = domain
        self.interfaceIndex = interfaceIndex
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Start browsing for services (async/await)
    /// - Returns: An async stream of discovery events
    public func browse() -> AsyncStream<DiscoveryEvent> {
        AsyncStream { continuation in
            let id = UUID()
            
            lock.lock()
            // Check if we should start browsing
            let shouldStart = !isActive
            continuations[id] = continuation
            lock.unlock()
            
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations[id] = nil
                let shouldStop = self?.continuations.isEmpty ?? true
                self?.lock.unlock()
                
                if shouldStop {
                    self?.stop()
                }
            }
            
            // Only start browsing if not already active
            if shouldStart {
                do {
                    try startBrowsing()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
    
    /// Start browsing for services (Combine)
    /// - Returns: A publisher of discovery events
    @available(iOS 13.0, tvOS 13.0, *)
    public func browsePublisher() -> AnyPublisher<DiscoveryEvent, Error> {
        do {
            try startBrowsing()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Start browsing for services (delegate-based)
    public func startBrowsing() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isActive else {
            throw HHServicesError.alreadyStarted
        }
        
        // Validate service type
        guard ServiceValidation.isValidServiceType(serviceType) else {
            throw HHServicesError.invalidServiceType
        }
        
        // Validate domain
        guard ServiceValidation.isValidDomain(domain) else {
            throw HHServicesError.invalidDomain
        }
        
        let dns = DNSService()
        
        do {
            try dns.browse(
                type: serviceType,
                domain: domain,
                interfaceIndex: interfaceIndex
            ) { [weak self] result in
                self?.handleBrowseResult(result)
            }
            
            dnsService = dns
            isActive = true
        } catch {
            // Clean up on error
            dns.stop()
            throw error
        }
    }
    
    /// Stop browsing for services
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isActive = false
        dnsService?.stop()
        dnsService = nil
        
        // Complete all continuations
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        
        // Complete Combine subject
        subject.send(completion: .finished)
    }
    
    /// Browse for services over Bluetooth only
    public func browseBluetoothOnly() -> AsyncStream<DiscoveryEvent> {
        let browser = ServiceBrowser(
            type: serviceType,
            domain: domain,
            interfaceIndex: kHHServiceInterfaceIndexP2P
        )
        return browser.browse()
    }
    
    /// Get all currently discovered services
    public var services: [Service] {
        lock.lock()
        defer { lock.unlock() }
        return Array(discoveredServices)
    }
    
    // MARK: - Private Methods
    
    private func handleBrowseResult(_ result: BrowseResult) {
        switch result {
        case .success(let event):
            handleBrowseEvent(event)
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func handleBrowseEvent(_ event: BrowseEvent) {
        let service = Service(
            name: event.name,
            type: event.type,
            domain: event.domain,
            interfaceIndex: event.interfaceIndex
        )
        
        lock.lock()
        let discoveryEvent: DiscoveryEvent
        
        if event.isAdd {
            discoveredServices.insert(service)
            discoveryEvent = .serviceAdded(service, moreComing: event.moreComing)
        } else {
            discoveredServices.remove(service)
            discoveryEvent = .serviceRemoved(service, moreComing: event.moreComing)
        }
        
        // Notify continuations
        for continuation in continuations.values {
            continuation.yield(discoveryEvent)
        }
        lock.unlock()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch discoveryEvent {
            case .serviceAdded(let service, let moreComing):
                self.delegate?.serviceBrowser(self, didFindService: service, moreComing: moreComing)
            case .serviceRemoved(let service, let moreComing):
                self.delegate?.serviceBrowser(self, didRemoveService: service, moreComing: moreComing)
            }
        }
        
        // Notify Combine
        subject.send(discoveryEvent)
    }
    
    private func handleError(_ error: Error) {
        lock.lock()
        
        // Notify continuations
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        
        lock.unlock()
        
        // Notify delegate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.serviceBrowser(self, didFailWithError: error)
        }
        
        // Notify Combine
        subject.send(completion: .failure(error))
        
        stop()
    }
}

// MARK: - Discovery Event

/// Events emitted during service discovery
public enum DiscoveryEvent: Sendable {
    case serviceAdded(Service, moreComing: Bool)
    case serviceRemoved(Service, moreComing: Bool)
    
    public var service: Service {
        switch self {
        case .serviceAdded(let service, _), .serviceRemoved(let service, _):
            return service
        }
    }
    
    public var isAdded: Bool {
        switch self {
        case .serviceAdded:
            return true
        case .serviceRemoved:
            return false
        }
    }
    
    public var moreComing: Bool {
        switch self {
        case .serviceAdded(_, let more), .serviceRemoved(_, let more):
            return more
        }
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for service discovery events
public protocol ServiceBrowserDelegate: AnyObject {
    func serviceBrowser(_ browser: ServiceBrowser, didFindService service: Service, moreComing: Bool)
    func serviceBrowser(_ browser: ServiceBrowser, didRemoveService service: Service, moreComing: Bool)
    func serviceBrowser(_ browser: ServiceBrowser, didFailWithError error: Error)
}

// Optional methods with default implementations
public extension ServiceBrowserDelegate {
    func serviceBrowser(_ browser: ServiceBrowser, didRemoveService service: Service, moreComing: Bool) {}
    func serviceBrowser(_ browser: ServiceBrowser, didFailWithError error: Error) {}
}