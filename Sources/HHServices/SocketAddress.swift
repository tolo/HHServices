import Foundation

/// Represents a socket address (IPv4 or IPv6)
public struct SocketAddress: Sendable, Hashable {
    public private(set) var data: Data
    public let family: AddressFamily
    
    public enum AddressFamily: Sendable {
        case ipv4
        case ipv6
        case unknown
    }
    
    init(sockaddr: UnsafePointer<sockaddr>) {
        let length = Int(sockaddr.pointee.sa_len)
        self.data = Data(bytes: sockaddr, count: length)
        
        switch Int32(sockaddr.pointee.sa_family) {
        case AF_INET:
            self.family = .ipv4
        case AF_INET6:
            self.family = .ipv6
        default:
            self.family = .unknown
        }
    }
    
    public init(data: Data) {
        self.data = data
        
        var detectedFamily: AddressFamily = .unknown
        if data.count >= MemoryLayout<sockaddr>.size {
            data.withUnsafeBytes { bytes in
                let sockaddr = bytes.bindMemory(to: sockaddr.self).baseAddress!
                switch Int32(sockaddr.pointee.sa_family) {
                case AF_INET:
                    detectedFamily = .ipv4
                case AF_INET6:
                    detectedFamily = .ipv6
                default:
                    detectedFamily = .unknown
                }
            }
        }
        self.family = detectedFamily
    }
    
    /// Get the presentation string for this address (e.g., "192.168.1.1" or "fe80::1")
    public var presentation: String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        let result = data.withUnsafeBytes { bytes -> Int32 in
            guard let sockaddr = bytes.bindMemory(to: sockaddr.self).baseAddress else {
                return -1
            }
            
            return getnameinfo(
                sockaddr,
                socklen_t(data.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }
        
        guard result == 0 else { return nil }
        return String(cString: hostname)
    }
    
    /// Get the port number from this socket address
    public var port: Int? {
        switch family {
        case .ipv4:
            return data.withUnsafeBytes { bytes in
                guard let sin = bytes.bindMemory(to: sockaddr_in.self).baseAddress else {
                    return nil
                }
                return Int(UInt16(bigEndian: sin.pointee.sin_port))
            }
        case .ipv6:
            return data.withUnsafeBytes { bytes in
                guard let sin6 = bytes.bindMemory(to: sockaddr_in6.self).baseAddress else {
                    return nil
                }
                return Int(UInt16(bigEndian: sin6.pointee.sin6_port))
            }
        case .unknown:
            return nil
        }
    }
    
    /// Set the port number for this socket address
    public mutating func setPort(_ port: Int) {
        var mutableData = data
        
        switch family {
        case .ipv4:
            mutableData.withUnsafeMutableBytes { bytes in
                guard let sin = bytes.bindMemory(to: sockaddr_in.self).baseAddress else { return }
                sin.pointee.sin_port = UInt16(port).bigEndian
            }
        case .ipv6:
            mutableData.withUnsafeMutableBytes { bytes in
                guard let sin6 = bytes.bindMemory(to: sockaddr_in6.self).baseAddress else { return }
                sin6.pointee.sin6_port = UInt16(port).bigEndian
            }
        case .unknown:
            break
        }
        
        self.data = mutableData
    }
    
    /// Check if this is a link-local address
    public var isLinkLocal: Bool {
        switch family {
        case .ipv4:
            guard let presentation = presentation else { return false }
            return presentation.hasPrefix("169.254.")
        case .ipv6:
            guard let presentation = presentation else { return false }
            return presentation.lowercased().hasPrefix("fe80:")
        case .unknown:
            return false
        }
    }
}