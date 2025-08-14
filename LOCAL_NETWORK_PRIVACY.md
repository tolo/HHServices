# Local Network Privacy Requirements (iOS 14+)

Since iOS 14, apps using local network features must request permission from users. This affects HHServices and any DNS-SD/Bonjour-based service discovery.

## Required Info.plist Entries

### 1. Local Network Usage Description

Add this key to explain why your app needs local network access:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover and connect to nearby devices for [your specific use case].</string>
```

### 2. Bonjour Services Declaration

Declare all Bonjour service types your app will browse or advertise:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_myservice._tcp</string>
    <string>_myservice._udp</string>
</array>
```

**Important**: The service types must match exactly what you use in your code. Include the underscore prefix and protocol suffix (._tcp or ._udp).

## Privacy Manifest (iOS 17+)

For iOS 17 and later, you may need to include a Privacy Manifest file (`PrivacyInfo.xcprivacy`) declaring your use of DNS-SD APIs:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## Permission Request Behavior

### When Permission is Triggered

The local network permission dialog appears when:
- Your app calls `beginBrowse` or `beginPublish`
- The system detects DNS-SD/Bonjour activity
- Your app attempts to connect to a local IP address

### Permission States

```objc
// Check if permission was granted (indirect method)
// There's no direct API to check permission status
// Monitor for browse/publish failures with error code -65570 (PolicyDenied)

- (void)serviceBrowserDidNotStart:(HHServiceBrowser *)browser error:(NSError *)error {
    if (error.code == -65570) { // kDNSServiceErr_PolicyDenied
        // Local network permission was denied
        // Guide user to Settings > Privacy > Local Network
    }
}
```

## Bluetooth P2P Considerations

When using `beginBrowseOverBluetoothOnly` or `kDNSServiceInterfaceIndexP2P`:
- Local network permission is **still required** even for Bluetooth-only
- The system treats all DNS-SD operations as local network activity
- Bluetooth permissions (if applicable) are separate from local network permissions

## Testing Recommendations

1. **Reset permissions for testing**:
   ```bash
   # On device: Settings > General > Transfer or Reset > Reset > Reset Location & Privacy
   ```

2. **Test permission flows**:
   - Fresh install (permission not determined)
   - Permission denied scenario
   - Permission granted scenario
   - App backgrounded during permission request

3. **Simulator limitations**:
   - Local network permission dialog may not appear in simulator
   - Test on real devices for accurate behavior

## Common Issues and Solutions

### Issue: Service discovery fails silently
**Solution**: Implement error handlers and check for error code -65570

### Issue: Permission dialog doesn't appear
**Solution**: Verify Info.plist entries match service types exactly

### Issue: Bluetooth P2P not working despite permission
**Solution**: Ensure both local network and Bluetooth permissions are granted

## Migration Checklist

- [ ] Add `NSLocalNetworkUsageDescription` to Info.plist
- [ ] Add all service types to `NSBonjourServices` array
- [ ] Implement error handling for permission denied (-65570)
- [ ] Test on real devices running iOS 14+
- [ ] Update app's privacy policy to mention local network usage
- [ ] Consider adding user guidance for Settings navigation
- [ ] Add Privacy Manifest for iOS 17+ if required

## Additional Resources

- [Apple Documentation: Local Network Privacy](https://developer.apple.com/documentation/bundleresources/information_property_list/nslocalnetworkusagedescription)
- [WWDC 2020: Support Local Network Privacy](https://developer.apple.com/videos/play/wwdc2020/10110/)
- [Technical Q&A QA1753: Bonjour over Bluetooth](https://developer.apple.com/library/archive/qa/qa1753/_index.html)