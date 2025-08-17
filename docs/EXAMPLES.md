# HHServices Code Examples

This document contains comprehensive code examples for using HHServices v3.0.

> **Important:** HHServices v3.0 is a pure Swift implementation. While basic Objective-C interoperability is possible through bridging, the async/await APIs and some Swift-specific features require wrapper methods for full Objective-C compatibility. For new projects, Swift usage is strongly recommended.

## Table of Contents
- [Publishing a Service](#publishing-a-service)
- [Discovering Services](#discovering-services)
- [Resolving & Connecting to Services](#resolving--connecting-to-services)

## Publishing a Service

### Swift Example

```swift
import HHServices

class MyServicePublisher {
    private var publisher: ServicePublisher?
    
    func startPublishing(port: UInt16) async throws {
        // Create TXT record data if needed
        // Create TXT record data if needed
        let txtRecord = TXTRecord(dictionary: [
            "version": "1.0",
            "platform": "iOS"
        ])
        
        // Initialize publisher
        publisher = ServicePublisher(
            name: "MyDevice",
            type: "_myservice._tcp.",
            domain: "local.",
            port: port
        )
        publisher?.setTXTRecord(txtRecord.dictionary)
        
        // Publish over Bluetooth only (unique to HHServices!)
        try await publisher?.publishBluetoothOnly()
        print("✅ Service published on port \(port)")
    }
    
    func stopPublishing() {
        publisher?.stop()
        publisher = nil
    }
}

// Using Combine instead of async/await
import Combine

class CombinePublisher {
    private var publisher: ServicePublisher?
    private var cancellables = Set<AnyCancellable>()
    
    func startPublishing(port: UInt16) {
        publisher = ServicePublisher(
            name: "MyDevice",
            type: "_myservice._tcp.",
            domain: "local.",
            port: port
        )
        
        publisher?.delegate = self
        
        Task {
            do {
                try await publisher?.publishBluetoothOnly()
                print("✅ Service published successfully")
            } catch {
                print("❌ Publishing failed: \(error)")
            }
        }
    }
}
```

### Objective-C Example

**Note:** HHServices v3.0 is written in pure Swift. While it can be used from Objective-C, some APIs may require bridging headers and Swift-specific features like async/await are not directly available.

```objective-c
// HHServices v3.0 is pure Swift - Objective-C usage requires bridging
// Import the Swift module in your bridging header:
// @import HHServices;

@interface ServicePublisher : NSObject
@property (nonatomic, strong) HHServices.ServicePublisher *publisher;
@end

@implementation ServicePublisher

- (void)startPublishingOnPort:(NSUInteger)serverPort {
    // Note: In v3.0, ServicePublisher is a Swift class
    // Some initialization patterns may differ
    self.publisher = [[HHServices.ServicePublisher alloc] 
                      initWithName:@"MyDevice"
                              type:@"_myservice._tcp."
                            domain:@"local."
                              port:serverPort
                     interfaceIndex:0];
    
    // TXT records need to be set separately
    NSDictionary *txtDict = @{
        @"version": @"1.0",
        @"platform": @"iOS"
    };
    [self.publisher setTXTRecord:txtDict];
    
    // Publishing requires using completion handlers or delegates
    // Async/await is not available from Objective-C
    NSError *error = nil;
    [self.publisher startPublishing:&error];
    
    if (error) {
        NSLog(@"❌ Failed to publish: %@", error);
    }
}

@end
```

## Discovering Services

### Swift Example

```swift
import HHServices

class ServiceDiscoverer {
    private var browser: ServiceBrowser?
    private var discoveredServices: [Service] = []
    
    func startDiscovery() async {
        browser = ServiceBrowser(type: "_myservice._tcp.", domain: "local.")
        
        // Browse for Bluetooth-only services
        guard let stream = browser?.browseBluetoothOnly() else { return }
        
        do {
            for try await event in stream {
                switch event {
                case .serviceAdded(let service, let moreComing):
                    print("📱 Found: \(service.name)")
                    discoveredServices.append(service)
                    if !moreComing {
                        print("Found \(discoveredServices.count) services total")
                    }
                case .serviceRemoved(let service, _):
                    print("📴 Lost: \(service.name)")
                    discoveredServices.removeAll { $0.name == service.name }
                }
            }
        } catch {
            print("❌ Discovery error: \(error)")
        }
    }
    
    func stopDiscovery() {
        browser?.stop()
        browser = nil
    }
}

// Using Combine
import Combine

class CombineDiscoverer {
    private var browser: ServiceBrowser?
    private var cancellables = Set<AnyCancellable>()
    
    func startDiscovery() {
        browser = ServiceBrowser(type: "_myservice._tcp.", domain: "local.")
        
        // Note: browsePublisher is not available in current API
        // Use async/await approach instead
        Task {
            for await event in browser?.browseBluetoothOnly() ?? AsyncStream { _ in } {
                switch event {
                case .serviceAdded(let service, _):
                    print("📱 Found: \(service.name)")
                case .serviceRemoved(let service, _):
                    print("📴 Lost: \(service.name)")
                }
            }
        }
    }
}
```

### Objective-C Example

```objective-c
// HHServices v3.0 usage from Objective-C
@interface ServiceDiscoverer : NSObject
@property (nonatomic, strong) HHServices.ServiceBrowser *browser;
@property (nonatomic, strong) NSMutableArray<HHServices.Service *> *discoveredServices;
@end

@implementation ServiceDiscoverer

- (instancetype)init {
    if (self = [super init]) {
        _discoveredServices = [NSMutableArray array];
    }
    return self;
}

- (void)startDiscovery {
    // Browse for services
    self.browser = [[HHServices.ServiceBrowser alloc] 
                    initWithType:@"_myservice._tcp." 
                          domain:@"local."
                   interfaceIndex:0];
    
    // Note: v3.0 uses async streams, which require Swift wrapper methods
    // for Objective-C compatibility
    NSError *error = nil;
    [self.browser startBrowsing:&error];
    
    if (error) {
        NSLog(@"❌ Failed to start browsing: %@", error);
    }
}

// Note: ServiceBrowserDelegate methods in v3.0
// You may need to implement a Swift wrapper to bridge delegate callbacks
// or use a different approach for Objective-C compatibility

@end
```

## Resolving & Connecting to Services

### Swift Example

```swift
import HHServices

class ServiceResolver {
    private var resolvingServices: Set<Service> = []
    
    func resolveService(_ service: Service) async throws {
        // Keep strong reference during resolution
        resolvingServices.insert(service)
        defer { resolvingServices.remove(service) }
        
        // Resolve the service using ServiceResolver
        let resolver = ServiceResolver(service: service)
        let resolved = try await resolver.resolve()
        
        // Get connection info
        if let hostName = resolved.hostName, let port = resolved.port {
            print("🔗 Connect to: \(hostName):\(port)")
            try await connectToHost(hostName, port: UInt16(port))
        } else {
            // Fall back to IP addresses
            for address in resolved.addresses {
                if let presentation = address.presentation, let port = address.port {
                    print("🔗 Trying address: \(presentation):\(port)")
                    if try await connectToAddress(address) {
                        break
                    }
                }
            }
        }
    }
    
    private func connectToHost(_ host: String, port: UInt16) async throws {
        // Use URLSession, Network.framework, or your preferred networking library
        let url = URL(string: "http://\(host):\(port)/api")!
        let (data, _) = try await URLSession.shared.data(from: url)
        print("✅ Connected! Received \(data.count) bytes")
    }
    
    private func connectToAddress(_ address: SocketAddress) async throws -> Bool {
        // Connect using resolved address
        // Implementation depends on your networking stack
        return true
    }
}

// Using delegate pattern for more control
class DelegateResolver: NSObject {
    private var resolvingServices: NSMutableSet = NSMutableSet()
    
    func resolveService(_ service: Service) {
        resolvingServices.add(service)
        // Note: In v3.0, Service doesn't have delegate methods
        // Use ServiceResolver with async/await instead
        Task {
            do {
                let resolver = ServiceResolver(service: service)
                let resolved = try await resolver.resolve()
                handleResolvedService(resolved)
            } catch {
                print("❌ Failed to resolve: \(service.name)")
            }
        }
    }
}

extension DelegateResolver {
    func handleResolvedService(_ service: Service) {
        if let hostName = service.hostName, let port = service.port {
            print("🔗 Resolved: \(hostName):\(port)")
        }
        resolvingServices.remove(service)
    }
}
```

### Objective-C Example

```objective-c
// HHServices v3.0 - Resolution from Objective-C
@interface ServiceResolver : NSObject
@property (nonatomic, strong) NSMutableSet<HHServices.Service *> *resolvingServices;
@property (nonatomic, strong) HHServices.ServiceResolver *resolver;
@end

@implementation ServiceResolver

- (instancetype)init {
    if (self = [super init]) {
        _resolvingServices = [NSMutableSet set];
    }
    return self;
}

// Service discovery and resolution

- (void)resolveService:(HHServices.Service *)service {
    // Start resolving using ServiceResolver
    [self.resolvingServices addObject:service];
    
    self.resolver = [[HHServices.ServiceResolver alloc] initWithService:service];
    
    // Note: v3.0 uses async/await which requires Swift wrapper for Objective-C
    // You'll need to create a completion handler wrapper or use delegates
}

// Handle resolved service
- (void)handleResolvedService:(HHServices.Service *)service {
    // Try connecting with hostname first (recommended)
    if (service.hostName != nil && service.port != nil) {
        NSLog(@"🔗 Connecting to %@:%@", 
              service.hostName, 
              service.port);
        
        [self connectToHost:service.hostName 
                       port:[service.port unsignedIntegerValue]];
    } 
    else {
        // Fall back to IP addresses
        for (HHServices.SocketAddress *address in service.addresses) {
            if (address.presentation && address.port) {
                NSLog(@"🔗 Address: %@:%@", address.presentation, address.port);
                // Connect using address
            }
        }
    }
    
    [self.resolvingServices removeObject:service];
}

#pragma mark - Networking

- (void)connectToHost:(NSString *)host port:(NSUInteger)port {
    // Example using NSURLSession
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%lu/api", 
                          host, (unsigned long)port];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] 
        dataTaskWithURL:url 
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"❌ Connection failed: %@", error);
            } else {
                NSLog(@"✅ Connected! Received %lu bytes", (unsigned long)data.length);
            }
        }];
    [task resume];
}

// Note: In v3.0, addresses are SocketAddress objects, not raw sockaddr structs
// You may need to adapt your connection logic accordingly

@end
```