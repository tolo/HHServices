# HHServices - DNS-SD Service Discovery for iOS

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20tvOS-lightgrey.svg)](https://github.com/tolo/HHServices)
[![Language](https://img.shields.io/badge/language-Objective--C-blue.svg)](https://github.com/tolo/HHServices)
[![CocoaPods](https://img.shields.io/badge/pod-v2.1.0-green.svg)](https://cocoapods.org/pods/HHServices)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**The only iOS framework providing true Bluetooth P2P connectivity without WiFi degradation.**

## Why HHServices in 2025?

While Apple deprecated NSNetService and removed its Bluetooth P2P support in iOS 11, HHServices remains the **only solution** for:

- ✅ **True Bluetooth-only P2P** connectivity on iOS 11+
- ✅ **Zero WiFi performance impact** (unlike MultipeerConnectivity which degrades WiFi from 2MB/s to 150KB/s)
- ✅ **Direct DNS-SD API access** via low-level `dns_sd.h` bindings
- ✅ **Modern Swift support** with async/await and Combine
- ✅ **iOS 14+ Local Network privacy** compatibility
- ✅ **Production-tested** in apps like WiFi Booth and BluePrint

## When to Use HHServices

| Use Case | Recommendation |
|----------|---------------|
| Need Bluetooth P2P on iOS 11+ | ✅ **HHServices** (only option) |
| WiFi performance is critical | ✅ **HHServices** (no degradation) |
| General networking (no P2P) | ❌ Use Network.framework |
| WiFi P2P is sufficient | ❌ Use Network.framework with `includePeerToPeer` |
| Need both WiFi + Bluetooth P2P | ⚠️ Consider MultipeerConnectivity (with performance tradeoff) |


## Installation

### Swift Package Manager (Recommended)
```swift
dependencies: [
    .package(url: "https://github.com/tolo/HHServices.git", from: "2.1.0")
]
```

### CocoaPods
```ruby
pod 'HHServices', '~> 2.1'
```

### Manual
1. Add all files from the `HHServices` directory to your project
2. Link against `Foundation.framework`

## Quick Start

### iOS 14+ Requirements
Add to your `Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover nearby devices</string>

<key>NSBonjourServices</key>
<array>
    <string>_yourservice._tcp</string>
</array>
```

### Modern Swift (iOS 13+)
```swift
import HHServices

// Publishing a service
let publisher = HHServicePublisher(
    name: "MyDevice",
    type: "_myapp._tcp.",
    domain: "local.",
    txtData: nil,
    port: 8080
)

Task {
    try await publisher.publishBluetoothOnly() // Unique to HHServices!
    print("Service published over Bluetooth")
}

// Discovering services
let browser = HHServiceBrowser(type: "_myapp._tcp.", domain: "local.")

Task {
    for try await discovery in browser.browseBluetoothOnly() {
        print("Found: \(discovery.service.name)")
        
        // Resolve and connect
        let resolved = try await discovery.service.resolve()
        print("Connect to: \(resolved.hostName ?? "unknown"):\(resolved.port)")
    }
}
```

### Classic Objective-C
See examples below for traditional delegate-based usage.

# Changes in 2.0

* Converted to ARC
* Added IPv6 support ( ```HHService``` is now capable of supporting both ```sockaddr_in``` and ```sockaddr_in6``` addresses)
* API changes in class ```HHService``` related to resolving of host name and addresses (method changes, property changes, introduced class ```HHAddressInfo``` etc)
* Added ```moreComing``` parameter to ```serviceDidResolve``` method in ```HHServiceDelegate```
* Added nullability support for better Swift interoperability
* Added Cocoapods support
* Added support for restricting service discovery and publishing to Bluetooth only (thanks [@xaphod](https://github.com/xaphod)), as well as to a specific interface index

### Note: More details about restricting service discovery and publishing to Bluetooth only (description provided by [@xaphod](https://github.com/xaphod)):
Version 2.0 adds the ability to specify that service browsing, publishing, and resolution should be done over Bluetooth only. This is as per Apple's Technical Q&A 1753: https://developer.apple.com/library/ios/qa/qa1753/_index.html. Note that this doesn't stop peers from discovering non-Bluetooth IP addresses of your device(s), but it DOES stop the wifi radio from being placed into adhoc mode multiple times a second (the cause of wifi throughput / performance degradation when using Apple's MultipeerConnectivity framework). NSNetService and Multipeer both have this problem because you cannot limit them to Bluetooth (or wifi) only, and (as of iOS 9.3) calling stopAdvertise() only takes effect after 30 seconds or so, meaning you cannot micro-manage stop/start advertising.

### Note: Important info on iOS 11 and above (reported by [@bigfish24](https://github.com/bigfish24))
Starting in iOS 11, ```NSNetService``` does not support P2P Bluetooth anymore. If this kind of connectivity is required in your app, ```HHServices``` might be a good alternative, either as a replacement for ```NSNetService``` or used in combination. 
Read more about this in [issue 22](https://github.com/tolo/HHServices/issues/22).

# Usage examples

Below are comprehensive examples for both Swift and Objective-C. There are also sample projects in the `samples` directory.

## Publishing a Service

<details>
<summary><b>Swift Example</b></summary>

```swift
import HHServices

class ServicePublisher {
    private var publisher: HHServicePublisher?
    
    func startPublishing(port: UInt16) async throws {
        // Create TXT record data if needed
        let txtData = HHServiceValidation.txtData(from: [
            "version": "1.0",
            "platform": "iOS"
        ])
        
        // Initialize publisher
        publisher = HHServicePublisher(
            name: "MyDevice",
            type: "_myservice._tcp.",
            domain: "local.",
            txtData: txtData,
            port: port
        )
        
        // Publish over Bluetooth only (unique to HHServices!)
        try await publisher?.publishBluetoothOnly()
        print("✅ Service published on port \(port)")
    }
    
    func stopPublishing() {
        publisher?.endPublish()
        publisher = nil
    }
}

// Using Combine instead of async/await
import Combine

class CombinePublisher {
    private var publisher: HHServicePublisher?
    private var cancellables = Set<AnyCancellable>()
    
    func startPublishing(port: UInt16) {
        publisher = HHServicePublisher(
            name: "MyDevice",
            type: "_myservice._tcp.",
            domain: "local.",
            txtData: nil,
            port: port
        )
        
        publisher?.publisherStream()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Publishing failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    print("✅ Service published successfully")
                }
            )
            .store(in: &cancellables)
        
        publisher?.beginPublishOverBluetoothOnly()
    }
}
```
</details>

<details>
<summary><b>Objective-C Example</b></summary>

```objective-c
@interface ServicePublisher : NSObject <HHServicePublisherDelegate>
@property (nonatomic, strong) HHServicePublisher *publisher;
@end

@implementation ServicePublisher

- (void)startPublishingOnPort:(NSUInteger)serverPort {
    // Create TXT record data if needed
    NSDictionary *txtDict = @{
        @"version": @"1.0",
        @"platform": @"iOS"
    };
    NSData *txtData = [HHServiceValidation txtDataFromDictionary:txtDict];
    
    // Initialize publisher
    self.publisher = [[HHServicePublisher alloc] initWithName:@"MyDevice"
                                                          type:@"_myservice._tcp."
                                                        domain:@"local."
                                                       txtData:txtData
                                                          port:serverPort];
    self.publisher.delegate = self;
    
    // Publish over Bluetooth only (unique to HHServices!)
    [self.publisher beginPublishOverBluetoothOnly];
}

#pragma mark - HHServicePublisherDelegate

- (void)serviceDidPublish:(HHServicePublisher *)servicePublisher {
    NSLog(@"✅ Service published successfully");
}

- (void)serviceDidNotPublish:(HHServicePublisher *)servicePublisher {
    NSLog(@"❌ Failed to publish service (error: %d)", servicePublisher.lastError);
    
    if (servicePublisher.lastError == -65570) {
        NSLog(@"💡 Tip: Add NSLocalNetworkUsageDescription to Info.plist");
    }
}

@end
```
</details>

## Discovering Services

<details>
<summary><b>Swift Example</b></summary>

```swift
import HHServices

class ServiceDiscoverer {
    private var browser: HHServiceBrowser?
    private var discoveredServices: [HHService] = []
    
    func startDiscovery() async {
        browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")
        
        // Browse for Bluetooth-only services
        guard let stream = browser?.browseBluetoothOnly() else { return }
        
        do {
            for try await discovery in stream {
                print("📱 Found: \(discovery.service.name)")
                
                if discovery.moreComing {
                    // More services are being discovered
                    discoveredServices.append(discovery.service)
                } else {
                    // Discovery batch complete
                    print("Found \(discoveredServices.count) services total")
                }
            }
        } catch {
            print("❌ Discovery error: \(error)")
        }
    }
    
    func stopDiscovery() {
        browser?.endBrowse()
        browser = nil
    }
}

// Using Combine
import Combine

class CombineDiscoverer {
    private var browser: HHServiceBrowser?
    private var cancellables = Set<AnyCancellable>()
    
    func startDiscovery() {
        browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")
        
        browser?.browsePublisher()
            .sink(
                receiveCompletion: { _ in
                    print("Discovery completed")
                },
                receiveValue: { discovery in
                    print("📱 Found: \(discovery.service.name)")
                }
            )
            .store(in: &cancellables)
        
        browser?.beginBrowseOverBluetoothOnly()
    }
}
```
</details>

<details>
<summary><b>Objective-C Example</b></summary>

```objective-c
@interface ServiceDiscoverer : NSObject <HHServiceBrowserDelegate>
@property (nonatomic, strong) HHServiceBrowser *browser;
@property (nonatomic, strong) NSMutableArray<HHService *> *discoveredServices;
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
    self.browser = [[HHServiceBrowser alloc] initWithType:@"_myservice._tcp." 
                                                    domain:@"local."];
    self.browser.delegate = self;
    
    // Browse over Bluetooth only (unique to HHServices!)
    [self.browser beginBrowseOverBluetoothOnly];
}

#pragma mark - HHServiceBrowserDelegate

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser 
        didFindService:(HHService *)service 
            moreComing:(BOOL)moreComing {
    
    NSLog(@"📱 Found service: %@", service.name);
    [self.discoveredServices addObject:service];
    
    if (!moreComing) {
        NSLog(@"Discovery complete. Found %lu services", 
              (unsigned long)self.discoveredServices.count);
    }
}

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser 
         didLoseService:(HHService *)service 
             moreComing:(BOOL)moreComing {
    
    NSLog(@"📴 Lost service: %@", service.name);
    [self.discoveredServices removeObject:service];
}

@end
```
</details>

## Resolving & Connecting to Services

<details>
<summary><b>Swift Example</b></summary>

```swift
import HHServices

class ServiceResolver {
    private var resolvingServices: Set<HHService> = []
    
    func resolveService(_ service: HHService) async throws {
        // Keep strong reference during resolution
        resolvingServices.insert(service)
        defer { resolvingServices.remove(service) }
        
        // Resolve the service
        let resolved = try await service.resolve()
        
        // Get connection info
        if let hostName = resolved.hostName {
            print("🔗 Connect to: \(hostName):\(resolved.port)")
            try await connectToHost(hostName, port: resolved.port)
        } else {
            // Fall back to IP addresses
            for addressInfo in resolved.addresses {
                print("🔗 Trying address: \(addressInfo.addressAndPort ?? "unknown")")
                if try await connectToAddress(addressInfo) {
                    break
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
    
    private func connectToAddress(_ addressInfo: HHAddressInfo) async throws -> Bool {
        // Connect using resolved address
        // Implementation depends on your networking stack
        return true
    }
}

// Using delegate pattern for more control
class DelegateResolver: NSObject {
    private var resolvingServices: NSMutableSet = NSMutableSet()
    
    func resolveService(_ service: HHService) {
        resolvingServices.add(service)
        service.delegate = self
        service.beginResolve()
    }
}

extension DelegateResolver: HHServiceDelegate {
    func serviceDidResolve(_ service: HHService, moreComing: Bool) {
        if let hostName = service.resolvedHostName {
            print("🔗 Resolved: \(hostName):\(service.resolvedPortNumber)")
        }
        
        if !moreComing {
            service.delegate = nil
            service.endResolve()
            resolvingServices.remove(service)
        }
    }
    
    func serviceDidNotResolve(_ service: HHService) {
        print("❌ Failed to resolve: \(service.name)")
        service.delegate = nil
        resolvingServices.remove(service)
    }
}
```
</details>

<details>
<summary><b>Objective-C Example</b></summary>

```objective-c
@interface ServiceResolver : NSObject <HHServiceBrowserDelegate, HHServiceDelegate>
@property (nonatomic, strong) NSMutableSet<HHService *> *resolvingServices;
@end

@implementation ServiceResolver

- (instancetype)init {
    if (self = [super init]) {
        _resolvingServices = [NSMutableSet set];
    }
    return self;
}

#pragma mark - HHServiceBrowserDelegate

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser 
        didFindService:(HHService *)service 
            moreComing:(BOOL)moreComing {
    
    // Start resolving immediately
    [self.resolvingServices addObject:service];
    service.delegate = self;
    
    // Choose resolution method based on needs:
    [service beginResolve];  // Resolve everything
    // OR
    // [service beginResolveOfHostName];  // Just resolve hostname
    // OR  
    // [service beginResolveOfHostNameAndPort];  // Hostname and port only
}

#pragma mark - HHServiceDelegate

- (void)serviceDidResolve:(HHService *)service moreComing:(BOOL)moreComing {
    // Try connecting with hostname first (recommended)
    if (service.resolvedHostName != nil) {
        NSLog(@"🔗 Connecting to %@:%d", 
              service.resolvedHostName, 
              service.resolvedPortNumber);
        
        [self connectToHost:service.resolvedHostName 
                       port:service.resolvedPortNumber];
    } 
    else {
        // Fall back to IP addresses
        for (HHAddressInfo *addressInfo in service.resolvedAddressInfo) {
            struct sockaddr *address = addressInfo.address;
            
            if (address->sa_family == AF_INET6) {
                NSLog(@"🔗 IPv6: %@", addressInfo.addressAndPortString);
            } else {
                NSLog(@"🔗 IPv4: %@", addressInfo.addressAndPortString);
            }
            
            if ([self connectToAddress:address]) {
                break;
            }
        }
    }
    
    // Clean up when done
    if (!moreComing) {
        service.delegate = nil;
        [service endResolve];
        [self.resolvingServices removeObject:service];
    }
}

- (void)serviceDidNotResolve:(HHService *)service {
    NSLog(@"❌ Failed to resolve: %@", service.name);
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

- (BOOL)connectToAddress:(struct sockaddr *)address {
    // Connect using BSD sockets, GCDAsyncSocket, or your preferred method
    // This is just a placeholder
    return YES;
}

@end
```
</details>


# Apps and frameworks using HHServices

* [PlayMyQ - Music Player • Remote Control • Jukebox](https://itunes.apple.com/app/playmyq-hd-music-player-remote/id432506056?mt=8)
* [Bluepeer - Framework providing MultipeerConnectivity-like functionality, but without wifi performance issues](https://github.com/xaphod/Bluepeer)
* [WiFi Booth for Canon, Nikon, Sony, and Eye-Fi](http://wifibooth.com)
* [BluePrint for sharing printing over Bluetooth](https://wifibooth.com/blueprint/)

## Documentation

- 📚 [Migration Guide](MIGRATION_GUIDE.md) - Migrate from NSNetService to HHServices
- 🔒 [Local Network Privacy](LOCAL_NETWORK_PRIVACY.md) - iOS 14+ privacy requirements
- 💡 [Sample Projects](samples/) - Example implementations

## Project Status

**Active Maintenance (2025)**: While the core functionality is stable, we're modernizing the framework for current iOS versions:

- ✅ Swift Package Manager support
- ✅ Async/await and Combine support
- ✅ iOS 14+ Local Network privacy compliance
- ✅ Privacy manifest for iOS 17+
- 🚧 Testing on iOS 18

## Contributing

Contributions are welcome! Please:
1. Test on real devices (Bluetooth P2P requires physical hardware)
2. Include unit tests for new features
3. Update documentation as needed
4. Follow existing code style

## License

MIT - See [LICENSE](LICENSE) file for details

## Support

- 🐛 [Report Issues](https://github.com/tolo/HHServices/issues)
- 💬 [Discussions](https://github.com/tolo/HHServices/discussions)
- 📧 Contact: tobias@leafnode.se

