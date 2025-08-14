# Migration Guide: NSNetService to HHServices

This guide helps you migrate from NSNetService (deprecated) to HHServices for DNS-SD service discovery, especially when you need Bluetooth P2P support.

## Why Migrate?

- **NSNetService is deprecated** as of iOS 13
- **No Bluetooth P2P support** in NSNetService since iOS 11
- **Network.framework lacks P2P features** as of iOS 18
- **HHServices provides Bluetooth-only P2P** without WiFi degradation

## Quick Comparison

| Feature | NSNetService | HHServices |
|---------|-------------|------------|
| Service Publishing | NSNetService | HHServicePublisher |
| Service Browsing | NSNetServiceBrowser | HHServiceBrowser |
| Service Resolution | NSNetService.resolve() | HHService.beginResolve() |
| Bluetooth P2P | ❌ (iOS 11+) | ✅ |
| WiFi P2P | ✅ | ❌ (LAN only) |
| Async/Await | ❌ | ✅ (with extensions) |
| Swift Package Manager | ✅ | ✅ |

## Migration Steps

### 1. Update Dependencies

#### CocoaPods
```ruby
# Replace
pod 'YourNetServicePod'

# With
pod 'HHServices', '~> 2.0'
```

#### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/tolo/HHServices.git", from: "2.0.0")
]
```

### 2. Update Info.plist

Add required keys for iOS 14+ (same as NSNetService):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover nearby devices.</string>

<key>NSBonjourServices</key>
<array>
    <string>_yourservice._tcp</string>
</array>
```

### 3. Service Publishing

#### NSNetService (Old)
```objc
// Publishing with NSNetService
self.netService = [[NSNetService alloc] initWithDomain:@"local." 
                                                   type:@"_myservice._tcp." 
                                                   name:@"MyDevice" 
                                                   port:12345];
self.netService.delegate = self;
[self.netService publish];

// Delegate methods
- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"Service published");
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"Failed to publish: %@", errorDict);
}
```

#### HHServices (New)
```objc
// Publishing with HHServices
self.publisher = [[HHServicePublisher alloc] initWithName:@"MyDevice"
                                                      type:@"_myservice._tcp."
                                                    domain:@"local."
                                                   txtData:nil
                                                      port:12345];
self.publisher.delegate = self;
[self.publisher beginPublish];

// For Bluetooth-only (unique to HHServices!)
[self.publisher beginPublishOverBluetoothOnly];

// Delegate methods
- (void)servicePublisherDidPublish:(HHServicePublisher *)servicePublisher {
    NSLog(@"Service published");
}

- (void)servicePublisher:(HHServicePublisher *)servicePublisher didNotPublish:(NSError *)error {
    NSLog(@"Failed to publish: %@", error);
}
```

### 4. Service Browsing

#### NSNetServiceBrowser (Old)
```objc
// Browsing with NSNetServiceBrowser
self.browser = [[NSNetServiceBrowser alloc] init];
self.browser.delegate = self;
[self.browser searchForServicesOfType:@"_myservice._tcp." inDomain:@"local."];

// Delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
           didFindService:(NSNetService *)service 
               moreComing:(BOOL)moreComing {
    [self.services addObject:service];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
         didRemoveService:(NSNetService *)service 
               moreComing:(BOOL)moreComing {
    [self.services removeObject:service];
}
```

#### HHServiceBrowser (New)
```objc
// Browsing with HHServices
self.browser = [[HHServiceBrowser alloc] initWithType:@"_myservice._tcp." 
                                                 domain:@"local."];
self.browser.delegate = self;
[self.browser beginBrowse];

// For Bluetooth-only (unique to HHServices!)
[self.browser beginBrowseOverBluetoothOnly];

// Delegate methods
- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser 
        didFindService:(HHService *)service 
            moreComing:(BOOL)moreComing {
    [self.services addObject:service];
}

- (void)serviceBrowser:(HHServiceBrowser *)serviceBrowser 
      didRemoveService:(HHService *)service 
            moreComing:(BOOL)moreComing {
    [self.services removeObject:service];
}
```

### 5. Service Resolution

#### NSNetService (Old)
```objc
// Resolution with NSNetService
service.delegate = self;
[service resolveWithTimeout:5.0];

// Delegate methods
- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSString *host = sender.hostName;
    NSInteger port = sender.port;
    NSArray *addresses = sender.addresses;
    // Connect to service...
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"Failed to resolve: %@", errorDict);
}
```

#### HHService (New)
```objc
// Resolution with HHServices
service.delegate = self;
[service beginResolve];

// Delegate methods
- (void)serviceDidResolve:(HHService *)service moreComing:(BOOL)moreComing {
    NSString *host = service.resolvedHostName;
    uint16_t port = service.resolvedPortNumber;
    NSArray<HHAddressInfo *> *addresses = service.resolvedAddressInfo;
    
    if (!moreComing) {
        [service endResolve];
        // Connect to service...
    }
}

- (void)serviceDidNotResolve:(HHService *)service error:(NSError *)error {
    NSLog(@"Failed to resolve: %@", error);
}
```

## Swift Migration

### Modern Async/Await Pattern (iOS 13+)

```swift
import HHServices

// Publishing
let publisher = HHServicePublisher(
    name: "MyDevice",
    type: "_myservice._tcp.",
    domain: "local.",
    txtData: nil,
    port: 12345
)

Task {
    do {
        // Regular publishing
        try await publisher.publish()
        
        // Or Bluetooth-only
        try await publisher.publishBluetoothOnly()
    } catch {
        print("Failed to publish: \(error)")
    }
}

// Browsing
let browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")

Task {
    do {
        for try await discovery in browser.browse() {
            print("Found service: \(discovery.service.name)")
            
            // Resolve the service
            let resolved = try await discovery.service.resolve()
            print("Resolved: \(resolved.hostName ?? "unknown") port: \(resolved.port)")
        }
    } catch {
        print("Browse error: \(error)")
    }
}
```

### Combine Pattern (iOS 13+)

```swift
import Combine
import HHServices

let browser = HHServiceBrowser(type: "_myservice._tcp.", domain: "local.")

browser.browsePublisher()
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Browse completed")
            case .failure(let error):
                print("Browse error: \(error)")
            }
        },
        receiveValue: { discovery in
            print("Found service: \(discovery.service.name)")
        }
    )
    .store(in: &cancellables)
```

## Key Differences to Note

### 1. Explicit Bluetooth Support
HHServices provides explicit methods for Bluetooth-only operations:
- `beginBrowseOverBluetoothOnly`
- `beginPublishOverBluetoothOnly`
- `beginBrowse:interfaceIndex:includeP2P:`

### 2. Resolution Cleanup
HHServices requires explicit cleanup after resolution:
```objc
if (!moreComing) {
    service.delegate = nil;
    [service endResolve];
}
```

### 3. Address Handling
HHServices uses `HHAddressInfo` objects instead of raw `NSData`:
```objc
// NSNetService
for (NSData *addressData in service.addresses) {
    // Parse sockaddr from NSData
}

// HHServices
for (HHAddressInfo *addressInfo in service.resolvedAddressInfo) {
    struct sockaddr *address = addressInfo.address;
    NSString *addressString = addressInfo.addressAndPortString;
}
```

### 4. TXT Record Handling
```objc
// NSNetService
NSDictionary *txtDict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];

// HHServices
NSData *txtData = service.txtData;
// Parse as needed
```

## Performance Considerations

### WiFi Performance
- **NSNetService/MultipeerConnectivity**: Severe WiFi degradation during P2P (2MB/s → 150KB/s)
- **HHServices with Bluetooth-only**: No WiFi impact

### When to Use Which
- **Use HHServices when**:
  - You need Bluetooth P2P on iOS 11+
  - WiFi performance is critical
  - You want to avoid WiFi ad-hoc mode

- **Use Network.framework when**:
  - You don't need P2P at all
  - You're building new apps targeting iOS 12+
  - You need advanced networking features

- **Use MultipeerConnectivity when**:
  - You need both WiFi and Bluetooth P2P
  - WiFi performance degradation is acceptable
  - You want higher-level abstractions

## Troubleshooting

### Common Issues

1. **Service not discovered**
   - Check Info.plist has correct service types
   - Verify local network permission is granted
   - Ensure devices are on same network/in Bluetooth range

2. **Error -65570 (PolicyDenied)**
   - Local network permission denied
   - Guide users to Settings > Privacy > Local Network

3. **Bluetooth-only not working**
   - Verify Bluetooth is enabled
   - Check both devices support Bluetooth LE
   - Ensure apps are in foreground (background has limitations)

4. **Resolution fails**
   - Service might have disappeared
   - Network connectivity issues
   - Try increasing timeout or retrying

## Sample Projects

See the existing sample projects in the `samples` directory:
- `BrowserSample` - Service discovery implementation
- `PublisherSample` - Service publishing implementation

## Need Help?

- [GitHub Issues](https://github.com/tolo/HHServices/issues)
- [API Documentation](https://github.com/tolo/HHServices/wiki)
- [Sample Projects](https://github.com/tolo/HHServices/tree/master/samples)