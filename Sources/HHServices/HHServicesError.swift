import Foundation

/// Errors that can occur during service discovery operations
public enum HHServicesError: LocalizedError, Sendable, Equatable {
    case dnsFailed(Int32)
    case alreadyStarted
    case notStarted
    case failedToResolve
    case failedToPublish
    case localNetworkPermissionDenied
    case bluetoothNotAvailable
    case resolveTimeout
    case invalidServiceName
    case invalidServiceType
    case invalidDomain
    case internalError
    case unknownError(Int32)
    
    public var errorDescription: String? {
        switch self {
        case .dnsFailed(let code):
            return "DNS service failed with error code: \(code)"
        case .alreadyStarted:
            return "Service discovery already started"
        case .notStarted:
            return "Service discovery not started"
        case .failedToResolve:
            return "Failed to resolve service"
        case .failedToPublish:
            return "Failed to publish service"
        case .localNetworkPermissionDenied:
            return "Local network permission denied. Please enable in Settings."
        case .bluetoothNotAvailable:
            return "Bluetooth is not available"
        case .resolveTimeout:
            return "Service resolution timed out"
        case .invalidServiceName:
            return "Invalid service name"
        case .invalidServiceType:
            return "Invalid service type"
        case .invalidDomain:
            return "Invalid domain"
        case .internalError:
            return "Internal error occurred"
        case .unknownError(let code):
            return "Unknown error occurred: \(code)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .localNetworkPermissionDenied:
            return "iOS 14+ requires local network permission for service discovery"
        case .bluetoothNotAvailable:
            return "Bluetooth must be enabled for P2P discovery"
        case .invalidServiceType:
            return "Service type must be in format '_service._tcp.' or '_service._udp.'"
        default:
            return nil
        }
    }
    
    /// Convert DNS-SD error codes to HHServicesError
    internal static func from(dnsErrorCode: Int32) -> HHServicesError {
        switch dnsErrorCode {
        case -65570: // kDNSServiceErr_PolicyDenied
            return .localNetworkPermissionDenied
        case -65563: // kDNSServiceErr_Timeout
            return .resolveTimeout
        default:
            return .dnsFailed(dnsErrorCode)
        }
    }
}