Pod::Spec.new do |s|
  s.name         = 'HHServices'
  s.version      = '3.0.0'
  s.summary      = 'iOS Bluetooth P2P DNS-SD with async/await support via XCFramework'
  s.description  = 'HHServices is a framework that makes publishing, browsing, and resolving DNS-SD (Bonjour) services easy, with full async/await and Combine support. This is useful for creating Bluetooth and WiFi P2P (adhoc) networks on iOS. Version 3.0 distributes the framework as an XCFramework for improved Swift Package Manager compatibility.'
  s.homepage     = 'https://github.com/tolo/HHServices'
  s.license      = 'MIT'
  s.authors      = { 'Tobias Löfstrand' => 'tobias@leafnode.se' }
  s.source       = { :git => 'https://github.com/tolo/HHServices.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  
  # Use vendored XCFramework instead of source files
  s.vendored_frameworks = 'Binary/HHServices.xcframework'
  
  s.frameworks   = 'Foundation'
end
