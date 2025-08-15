import Foundation

/// Represents a discovered network service
public final class Service: @unchecked Sendable {
    // Basic properties
    public let name: String
    public let type: String
    public let domain: String
    public let interfaceIndex: UInt32
    
    // Resolved properties (populated during resolution)
    private let lock = NSLock()
    private var _hostName: String?
    private var _port: Int?
    private var _addresses: [SocketAddress] = []
    private var _txtRecord: TXTRecord?
    
    public var hostName: String? {
        lock.lock()
        defer { lock.unlock() }
        return _hostName
    }
    
    public var port: Int? {
        lock.lock()
        defer { lock.unlock() }
        return _port
    }
    
    public var addresses: [SocketAddress] {
        lock.lock()
        defer { lock.unlock() }
        return _addresses
    }
    
    public var txtRecord: TXTRecord? {
        lock.lock()
        defer { lock.unlock() }
        return _txtRecord
    }
    
    /// Check if this service has been resolved
    public var isResolved: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hostName != nil && _port != nil
    }
    
    /// Check if this service has address information
    public var hasAddresses: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !_addresses.isEmpty
    }
    
    public init(name: String, type: String, domain: String, interfaceIndex: UInt32 = 0) {
        self.name = name
        self.type = type
        self.domain = domain
        self.interfaceIndex = interfaceIndex
    }
    
    internal func updateResolvedInfo(hostName: String, port: Int, txtData: Data?) {
        lock.lock()
        defer { lock.unlock() }
        
        _hostName = hostName
        _port = port
        
        if let txtData = txtData {
            _txtRecord = TXTRecord(data: txtData)
        }
    }
    
    internal func addAddress(_ address: SocketAddress) {
        lock.lock()
        defer { lock.unlock() }
        
        // Update port in address if we have it
        var addressWithPort = address
        if let port = _port {
            addressWithPort.setPort(port)
        }
        
        // Avoid duplicates
        if !_addresses.contains(where: { $0.data == addressWithPort.data }) {
            _addresses.append(addressWithPort)
        }
    }
    
    internal func clearAddresses() {
        lock.lock()
        defer { lock.unlock() }
        _addresses.removeAll()
    }
    
    /// Get IPv4 addresses only
    public var ipv4Addresses: [SocketAddress] {
        addresses.filter { $0.family == .ipv4 }
    }
    
    /// Get IPv6 addresses only
    public var ipv6Addresses: [SocketAddress] {
        addresses.filter { $0.family == .ipv6 }
    }
    
    /// Get the first non-link-local address (preferred for connections)
    public var preferredAddress: SocketAddress? {
        // Prefer non-link-local IPv4 first
        if let addr = ipv4Addresses.first(where: { !$0.isLinkLocal }) {
            return addr
        }
        // Then non-link-local IPv6
        if let addr = ipv6Addresses.first(where: { !$0.isLinkLocal }) {
            return addr
        }
        // Fall back to any IPv4
        if let addr = ipv4Addresses.first {
            return addr
        }
        // Finally any IPv6
        return ipv6Addresses.first
    }
}

// MARK: - Equatable

extension Service: Equatable {
    public static func == (lhs: Service, rhs: Service) -> Bool {
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.domain == rhs.domain &&
        lhs.interfaceIndex == rhs.interfaceIndex
    }
}

// MARK: - Hashable

extension Service: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(domain)
        hasher.combine(interfaceIndex)
    }
}

// MARK: - CustomStringConvertible

extension Service: CustomStringConvertible {
    public var description: String {
        var desc = "Service(\(name).\(type)\(domain))"
        if let hostName = hostName, let port = port {
            desc += " -> \(hostName):\(port)"
        }
        if !addresses.isEmpty {
            let addrs = addresses.compactMap { $0.presentation }.joined(separator: ", ")
            desc += " [\(addrs)]"
        }
        return desc
    }
}