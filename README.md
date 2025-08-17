# HHServices - DNS-SD Service Discovery for iOS

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20tvOS-lightgrey.svg)](https://github.com/tolo/HHServices)
[![Language](https://img.shields.io/badge/language-Swift-orange.svg)](https://github.com/tolo/HHServices)
[![CocoaPods](https://img.shields.io/badge/pod-v3.0.0-green.svg)](https://cocoapods.org/pods/HHServices)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**The only iOS framework providing true Bluetooth P2P connectivity without WiFi degradation.**

## Why HHServices?

✅ **True Bluetooth P2P** - The only solution for iOS 11+ Bluetooth connectivity  
✅ **Zero WiFi Impact** - No performance degradation (unlike MultipeerConnectivity)  
✅ **100% Pure Swift** - Modern implementation with async/await support  
✅ **Production Ready** - Battle-tested in apps like WiFi Booth and BluePrint  

## Installation

### Swift Package Manager (Recommended)
```swift
dependencies: [
    .package(url: "https://github.com/tolo/HHServices.git", from: "3.0.0")
]
```

### CocoaPods
```ruby
pod 'HHServices', '~> 3.0'
```

## Quick Start

### 1. Configure Info.plist (iOS 14+)
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover nearby devices</string>

<key>NSBonjourServices</key>
<array>
    <string>_yourservice._tcp</string>
</array>
```

### 2. Publish a Service
```swift
import HHServices

let publisher = HHServicePublisher(
    name: "MyDevice",
    type: "_myapp._tcp.",
    domain: "local.",
    txtData: nil,
    port: 8080
)

Task {
    try await publisher.publishBluetoothOnly()
    print("Service published over Bluetooth")
}
```

### 3. Discover Services
```swift
let browser = HHServiceBrowser(type: "_myapp._tcp.", domain: "local.")

Task {
    for try await discovery in browser.browseBluetoothOnly() {
        print("Found: \(discovery.service.name)")
        
        // Resolve and connect
        let resolved = try await discovery.service.resolve()
        print("Connect to: \(resolved.hostName ?? ""):\(resolved.port)")
    }
}
```

## When to Use HHServices

| Use Case | Recommendation |
|----------|---------------|
| Need Bluetooth P2P on iOS 11+ | ✅ **HHServices** (only option) |
| WiFi performance is critical | ✅ **HHServices** (no degradation) |
| General networking (no P2P) | ❌ Use Network.framework |
| WiFi P2P is sufficient | ❌ Use Network.framework |

## Documentation

📚 [**Code Examples**](docs/EXAMPLES.md) - Swift and Objective-C examples  
🔒 [**Bluetooth P2P Guide**](docs/BLUETOOTH_P2P.md) - Technical deep dive  
📋 [**Changelog**](CHANGELOG.md) - Version history and migration notes  
🔄 [**Migration Guide**](MIGRATION_GUIDE.md) - Migrate from NSNetService  
🛡️ [**Local Network Privacy**](LOCAL_NETWORK_PRIVACY.md) - iOS 14+ requirements  

## Sample Projects

Working examples are available in the [`samples/`](samples/) directory:
- **BrowserSample** - Service discovery implementation
- **PublisherSample** - Service publishing implementation

## Apps Using HHServices

- [PlayMyQ - Music Player](https://itunes.apple.com/app/playmyq-hd-music-player-remote/id432506056?mt=8)
- [WiFi Booth](http://wifibooth.com) - Photo transfer for Canon, Nikon, Sony
- [BluePrint](https://wifibooth.com/blueprint/) - Bluetooth printing
- [Bluepeer Framework](https://github.com/xaphod/Bluepeer) - MultipeerConnectivity alternative

## Contributing

Contributions welcome! Please:
- Test on real devices (Bluetooth requires hardware)
- Include unit tests for new features
- Follow existing code style

## Support

🐛 [Report Issues](https://github.com/tolo/HHServices/issues)  
💬 [Discussions](https://github.com/tolo/HHServices/discussions)  
📧 Contact: tobias@leafnode.se

## License

MIT - See [LICENSE](LICENSE) file