# HHServices v3.0 CocoaPods Specification
# This version uses XCFramework binary distribution

Pod::Spec.new do |s|
  
  # ――― Spec Metadata ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.name         = 'HHServices'
  s.version      = '3.0.0'
  s.summary      = 'iOS framework for DNS-SD (Bonjour) service discovery with Bluetooth P2P support'
  
  s.description  = <<-DESC
    HHServices is a lightweight framework for service discovery using DNS-SD (Bonjour) on iOS.
    
    Key Features:
    • Bluetooth P2P support without WiFi degradation (unique!)
    • Modern Swift async/await and Combine support
    • Battle-tested Objective-C core
    • iOS 13+ and tvOS 13+ support
    • 100% backward compatible API
    
    Version 3.0 introduces XCFramework distribution for consistent API across all package managers.
  DESC
  
  s.homepage     = 'https://github.com/tolo/HHServices'
  s.screenshots  = 'https://raw.githubusercontent.com/tolo/HHServices/master/docs/screenshot.png'
  
  
  # ――― Spec License ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  
  
  # ――― Author Metadata ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.author             = { 'Tobias Löfstrand' => 'tobias@leafnode.se' }
  s.social_media_url   = 'https://twitter.com/tobias_lofstrand'
  
  
  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  
  
  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.source       = { 
    :git => 'https://github.com/tolo/HHServices.git', 
    :tag => "v#{s.version}"
  }
  
  
  # ――― Binary Distribution ―――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  # Use pre-built XCFramework for consistent API experience
  s.vendored_frameworks = 'Binary/HHServices.xcframework'
  
  
  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.swift_version = '5.0'
  s.requires_arc = true
  
  # Module configuration
  s.module_name = 'HHServices'
  
  # Ensure framework includes both ObjC and Swift
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_EMIT_MODULE_INTERFACE' => 'YES',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES'
  }
  
  
  # ――― Frameworks ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.frameworks = 'Foundation'
  s.weak_frameworks = 'Combine'  # Optional for iOS 13+
  
  
  # ――― Documentation ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
  s.documentation_url = 'https://github.com/tolo/HHServices/blob/master/README.md'
  
end

# MARK: - Migration Notes for v3.0
#
# This version uses XCFramework distribution instead of source files.
# Benefits:
# • Faster build times
# • Consistent API across package managers
# • Full Swift support included
# • No API changes - 100% backward compatible
#
# For migration guide, see:
# https://github.com/tolo/HHServices/blob/master/ai_docs/v3_implementation/04_migration_guide.md