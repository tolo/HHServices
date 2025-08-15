Pod::Spec.new do |s|
  s.name         = 'HHServices'
  s.version      = '3.0.0'
  s.summary      = 'Pure Swift DNS-SD (Bonjour) service discovery with Bluetooth P2P'
  s.description  = 'HHServices is a pure Swift framework for DNS-SD service discovery with full async/await and Combine support. It provides the only solution for Bluetooth P2P connectivity on iOS 11+ without WiFi degradation.'
  s.homepage     = 'https://github.com/tolo/HHServices'
  s.license      = 'MIT'
  s.authors      = { 'Tobias Löfstrand' => 'tobias@leafnode.se' }
  s.source       = { :git => 'https://github.com/tolo/HHServices.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.swift_version = '5.0'
  
  s.source_files = 'Sources/HHServices/**/*.swift'
  s.frameworks   = 'Foundation'
end
