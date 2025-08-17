# Bluetooth P2P Technical Guide

## Why HHServices for Bluetooth P2P?

HHServices is the **only iOS framework** that provides true Bluetooth P2P connectivity without WiFi performance degradation on iOS 11 and later.

## The Problem with Other Frameworks

### NSNetService
- ❌ **No Bluetooth P2P support** since iOS 11
- ❌ Cannot be restricted to specific network interfaces
- ❌ Deprecated by Apple

### MultipeerConnectivity
- ❌ **Severe WiFi degradation**: Drops from 2MB/s to 150KB/s
- ❌ Cannot be restricted to Bluetooth-only
- ❌ `stopAdvertise()` takes 30+ seconds to take effect (iOS 9.3+)

### Network.framework
- ❌ No direct Bluetooth P2P support
- ❌ `includePeerToPeer` only works for WiFi P2P

## How HHServices Solves This

HHServices uses low-level `dns_sd.h` APIs directly, providing access to the `kDNSServiceInterfaceIndexP2P` interface that enables true Bluetooth-only connectivity.

## Technical Implementation

### Interface Indexes

```swift
// Standard interface indexes
kDNSServiceInterfaceIndexAny      // All interfaces (WiFi + Bluetooth)
kDNSServiceInterfaceIndexLocalOnly // Local machine only
kDNSServiceInterfaceIndexP2P      // Bluetooth P2P only (unique to HHServices!)
```

### Bluetooth-Only Methods

All major operations support Bluetooth-only variants:

```swift
// Publishing
publisher.beginPublishOverBluetoothOnly()
publisher.publishBluetoothOnly() // async/await

// Browsing
browser.beginBrowseOverBluetoothOnly()
browser.browseBluetoothOnly() // AsyncStream

// Resolving
service.beginResolve(includeP2P: true)
service.resolve() // async/await
```

## Performance Characteristics

### WiFi Performance Impact

| Framework | WiFi Speed (Normal) | WiFi Speed (with P2P) | Degradation |
|-----------|-------------------|----------------------|-------------|
| HHServices (Bluetooth-only) | 2 MB/s | 2 MB/s | **0%** |
| MultipeerConnectivity | 2 MB/s | 150 KB/s | **93%** |
| NSNetService (pre-iOS 11) | 2 MB/s | 200 KB/s | **90%** |

### Why the Degradation Happens

When frameworks cannot restrict to Bluetooth-only:
1. WiFi radio switches to adhoc mode multiple times per second
2. Constant mode switching prevents sustained data transfer
3. Effective bandwidth drops by 90%+

HHServices avoids this by using `kDNSServiceInterfaceIndexP2P` to keep WiFi completely separate.

## Implementation Details

### DNS-SD Registration

```c
// HHServices uses this under the hood
DNSServiceRegister(
    &sdRef,
    kDNSServiceFlagsShareConnection,
    kDNSServiceInterfaceIndexP2P,  // Bluetooth-only!
    name,
    type,
    domain,
    NULL,
    htons(port),
    txtLen,
    txtRecord,
    callback,
    context
);
```

### Service Discovery Flow

1. **Browse**: Discover services over Bluetooth
2. **Resolve**: Get hostname and port
3. **GetAddrInfo**: Resolve to IP addresses
4. **Connect**: Establish connection using resolved addresses

## Best Practices

### 1. Always Use Bluetooth-Only Methods

```swift
// ✅ Good - No WiFi impact
browser.beginBrowseOverBluetoothOnly()

// ❌ Bad - May affect WiFi performance
browser.beginBrowse()
```

### 2. Handle Resolution Properly

Services discovered over Bluetooth may resolve to multiple addresses:

```swift
func resolveService(_ service: HHService) async throws {
    let resolved = try await service.resolve()
    
    // Try hostname first (most reliable)
    if let hostName = resolved.hostName {
        connect(to: hostName, port: resolved.port)
    } else {
        // Fall back to IP addresses
        for address in resolved.addresses {
            if tryConnect(to: address) { break }
        }
    }
}
```

### 3. Maintain Strong References

Always keep strong references to services during resolution:

```swift
class ServiceManager {
    private var resolvingServices = Set<HHService>()
    
    func resolve(_ service: HHService) {
        resolvingServices.insert(service)
        // ... resolution code ...
        resolvingServices.remove(service)
    }
}
```

## Compatibility Notes

### iOS Version Requirements

| iOS Version | Bluetooth P2P Support | Notes |
|-------------|---------------------|-------|
| iOS 5-10 | ✅ NSNetService + HHServices | Both frameworks work |
| iOS 11-13 | ✅ HHServices only | NSNetService P2P removed |
| iOS 14+ | ✅ HHServices only | Requires Local Network permission |

### Local Network Privacy (iOS 14+)

Add to `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses Bluetooth to discover nearby devices</string>

<key>NSBonjourServices</key>
<array>
    <string>_yourservice._tcp</string>
</array>
```

## Troubleshooting

### Service Not Publishing

1. Check Local Network permission (iOS 14+)
2. Verify service type format: `_servicename._tcp.`
3. Ensure port is not already in use

### Services Not Discovered

1. Both devices must use Bluetooth-only methods
2. Bluetooth must be enabled on both devices
3. Devices must be within Bluetooth range (~10 meters)

### Resolution Fails

1. Keep strong reference to service during resolution
2. Try all resolution methods (hostname, then IPs)
3. Check for `moreComing` flag in callbacks

## References

- [Apple Technical Q&A QA1753](https://developer.apple.com/library/ios/qa/qa1753/_index.html)
- [DNS Service Discovery Programming Guide](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/dns_discovery_api/Introduction.html)
- [HHServices Issue #22](https://github.com/tolo/HHServices/issues/22) - iOS 11 NSNetService changes