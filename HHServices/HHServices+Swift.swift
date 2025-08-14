//
//  HHServices+Swift.swift
//  HHServices
//
//  Swift extensions and async/await wrappers for HHServices
//

import Foundation

// MARK: - Swift-friendly Service Discovery Result Types

/// Result of a service discovery operation
public struct DiscoveredService {
    public let service: HHService
    public let moreComing: Bool
}

/// Result of service resolution
public struct ResolvedService {
    public let service: HHService
    public let hostName: String?
    public let port: UInt16
    public let addresses: [HHAddressInfo]
    public let txtRecord: Data?
}

// MARK: - Async/Await Extensions

@available(iOS 13.0, tvOS 13.0, *)
public extension HHServiceBrowser {
    
    /// Browse for services asynchronously
    /// - Returns: AsyncStream of discovered services
    func browse() -> AsyncThrowingStream<DiscoveredService, Error> {
        AsyncThrowingStream { continuation in
            let delegateProxy = ServiceBrowserDelegateProxy { service, moreComing in
                continuation.yield(DiscoveredService(service: service, moreComing: moreComing))
                if !moreComing {
                    continuation.finish()
                }
            } onRemove: { service, moreComing in
                // Handle service removal if needed
            } onError: { error in
                continuation.finish(throwing: error)
            }
            
            self.delegate = delegateProxy
            
            // Start browsing
            guard self.beginBrowse() else {
                continuation.finish(throwing: HHServicesError.failedToStartBrowsing)
                return
            }
            
            // Handle cancellation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.endBrowse()
                    self.delegate = nil
                    // Clear associated object to prevent retain cycle
                    objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN)
                }
            }
            
            // Keep delegate proxy alive using a unique key to avoid conflicts
            objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Browse for services over Bluetooth only
    func browseBluetoothOnly() -> AsyncThrowingStream<DiscoveredService, Error> {
        AsyncThrowingStream { continuation in
            let delegateProxy = ServiceBrowserDelegateProxy { service, moreComing in
                continuation.yield(DiscoveredService(service: service, moreComing: moreComing))
                if !moreComing {
                    continuation.finish()
                }
            } onRemove: { service, moreComing in
                // Handle service removal if needed
            } onError: { error in
                continuation.finish(throwing: error)
            }
            
            self.delegate = delegateProxy
            
            // Start Bluetooth-only browsing
            guard self.beginBrowseOverBluetoothOnly() else {
                continuation.finish(throwing: HHServicesError.failedToStartBrowsing)
                return
            }
            
            // Handle cancellation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.endBrowse()
                    self.delegate = nil
                    // Clear associated object to prevent retain cycle
                    objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN)
                }
            }
            
            // Keep delegate proxy alive using a unique key to avoid conflicts
            objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
public extension HHService {
    
    /// Resolve the service asynchronously
    /// - Returns: Resolved service information
    func resolve() async throws -> ResolvedService {
        try await withCheckedThrowingContinuation { continuation in
            let delegateProxy = ServiceDelegateProxy { service, moreComing in
                if !moreComing {
                    let resolved = ResolvedService(
                        service: service,
                        hostName: service.resolvedHostName,
                        port: service.resolvedPortNumber,
                        addresses: service.resolvedAddressInfo ?? [],
                        txtRecord: service.txtData
                    )
                    continuation.resume(returning: resolved)
                    service.endResolve()
                }
            } onError: { error in
                continuation.resume(throwing: error)
            }
            
            self.delegate = delegateProxy
            
            // Start resolution
            guard self.beginResolve() else {
                continuation.resume(throwing: HHServicesError.failedToResolve)
                return
            }
            
            // Keep delegate proxy alive using a unique key to avoid conflicts
            objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Resolve only the host name asynchronously with timeout
    func resolveHostName(timeout: TimeInterval = 30.0) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw HHServicesError.resolveTimeout
            }
            
            // Add resolution task
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { continuation in
                    let delegateProxy = ServiceDelegateProxy { service, moreComing in
                        if let hostName = service.resolvedHostName, !moreComing {
                            continuation.resume(returning: hostName)
                            service.endResolve()
                        } else if !moreComing {
                            // No host name resolved
                            continuation.resume(throwing: HHServicesError.failedToResolve)
                        }
                    } onError: { error in
                        continuation.resume(throwing: error)
                    }
                    
                    self.delegate = delegateProxy
                    
                    // Start host name resolution
                    guard self.beginResolveOfHostName() else {
                        continuation.resume(throwing: HHServicesError.failedToResolve)
                        return
                    }
                    
                    // Keep delegate proxy alive using a unique key to avoid conflicts
                    objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
                }
            }
            
            // Return first result (either success or timeout)
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            
            throw HHServicesError.failedToResolve
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
public extension HHServicePublisher {
    
    /// Publish the service asynchronously
    /// - Returns: True when successfully published
    @discardableResult
    func publish() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let delegateProxy = ServicePublisherDelegateProxy { _ in
                continuation.resume(returning: true)
            } onError: { error in
                continuation.resume(throwing: error)
            }
            
            self.delegate = delegateProxy
            
            // Start publishing
            guard self.beginPublish() else {
                continuation.resume(throwing: HHServicesError.failedToPublish)
                return
            }
            
            // Keep delegate proxy alive using a unique key to avoid conflicts
            objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Publish the service over Bluetooth only
    @discardableResult
    func publishBluetoothOnly() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let delegateProxy = ServicePublisherDelegateProxy { _ in
                continuation.resume(returning: true)
            } onError: { error in
                continuation.resume(throwing: error)
            }
            
            self.delegate = delegateProxy
            
            // Start Bluetooth-only publishing
            guard self.beginPublishOverBluetoothOnly() else {
                continuation.resume(throwing: HHServicesError.failedToPublish)
                return
            }
            
            // Keep delegate proxy alive using a unique key to avoid conflicts
            objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - Error Types

public enum HHServicesError: LocalizedError {
    case failedToStartBrowsing
    case failedToResolve
    case failedToPublish
    case localNetworkPermissionDenied
    case bluetoothNotAvailable
    case resolveTimeout
    case invalidServiceName
    case invalidServiceType
    case invalidDomain
    case unknownError(Int32)
    
    public var errorDescription: String? {
        switch self {
        case .failedToStartBrowsing:
            return "Failed to start service browsing"
        case .failedToResolve:
            return "Failed to resolve service"
        case .failedToPublish:
            return "Failed to publish service"
        case .localNetworkPermissionDenied:
            return "Local network permission denied. Please enable in Settings > Privacy > Local Network"
        case .bluetoothNotAvailable:
            return "Bluetooth is not available or permission denied"
        case .resolveTimeout:
            return "Service resolution timed out"
        case .invalidServiceName:
            return "Invalid service name format"
        case .invalidServiceType:
            return "Invalid service type format (must be _service._tcp. or _service._udp.)"
        case .invalidDomain:
            return "Invalid domain format"
        case .unknownError(let code):
            return "Unknown error occurred (code: \(code))"
        }
    }
}

// MARK: - Delegate Proxy Classes

private class ServiceBrowserDelegateProxy: NSObject, HHServiceBrowserDelegate {
    let onFind: (HHService, Bool) -> Void
    let onRemove: (HHService, Bool) -> Void
    let onError: (Error) -> Void
    
    init(onFind: @escaping (HHService, Bool) -> Void,
         onRemove: @escaping (HHService, Bool) -> Void,
         onError: @escaping (Error) -> Void) {
        self.onFind = onFind
        self.onRemove = onRemove
        self.onError = onError
    }
    
    func serviceBrowser(_ serviceBrowser: HHServiceBrowser, didFind service: HHService, moreComing: Bool) {
        onFind(service, moreComing)
    }
    
    func serviceBrowser(_ serviceBrowser: HHServiceBrowser, didRemove service: HHService, moreComing: Bool) {
        onRemove(service, moreComing)
    }
}

private class ServiceDelegateProxy: NSObject, HHServiceDelegate {
    let onResolve: (HHService, Bool) -> Void
    let onError: (Error) -> Void
    
    init(onResolve: @escaping (HHService, Bool) -> Void,
         onError: @escaping (Error) -> Void) {
        self.onResolve = onResolve
        self.onError = onError
    }
    
    func serviceDidResolve(_ service: HHService, moreComing: Bool) {
        onResolve(service, moreComing)
    }
    
    func serviceDidNotResolve(_ service: HHService) {
        // The original protocol doesn't provide error details
        onError(HHServicesError.failedToResolve)
    }
}

private class ServicePublisherDelegateProxy: NSObject, HHServicePublisherDelegate {
    let onPublish: (HHServicePublisher) -> Void
    let onError: (Error) -> Void
    
    init(onPublish: @escaping (HHServicePublisher) -> Void,
         onError: @escaping (Error) -> Void) {
        self.onPublish = onPublish
        self.onError = onError
    }
    
    func serviceDidPublish(_ servicePublisher: HHServicePublisher) {
        onPublish(servicePublisher)
    }
    
    func serviceDidNotPublish(_ servicePublisher: HHServicePublisher) {
        // The original protocol doesn't provide error details
        // Check if lastError indicates permission denied
        if servicePublisher.lastError == -65570 {
            onError(HHServicesError.localNetworkPermissionDenied)
        } else {
            onError(HHServicesError.failedToPublish)
        }
    }
}

// MARK: - Combine Support

#if canImport(Combine)
import Combine

@available(iOS 13.0, tvOS 13.0, *)
public extension HHServiceBrowser {
    
    /// Publisher for discovered services
    func browsePublisher() -> AnyPublisher<DiscoveredService, Error> {
        let subject = PassthroughSubject<DiscoveredService, Error>()
        
        let delegateProxy = ServiceBrowserDelegateProxy { service, moreComing in
            subject.send(DiscoveredService(service: service, moreComing: moreComing))
            if !moreComing {
                subject.send(completion: .finished)
            }
        } onRemove: { _, _ in
            // Handle removal if needed
        } onError: { error in
            subject.send(completion: .failure(error))
        }
        
        self.delegate = delegateProxy
        
        guard self.beginBrowse() else {
            subject.send(completion: .failure(HHServicesError.failedToStartBrowsing))
            return subject.eraseToAnyPublisher()
        }
        
        // Keep delegate proxy alive
        objc_setAssociatedObject(self, "delegateProxy", delegateProxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return subject
            .handleEvents(receiveCancel: { [weak self] in
                // Clean up on cancellation
                self?.endBrowse()
                self?.delegate = nil
                if let self = self {
                    objc_setAssociatedObject(self, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN)
                }
            })
            .eraseToAnyPublisher()
    }
}
#endif