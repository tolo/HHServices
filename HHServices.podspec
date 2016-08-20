Pod::Spec.new do |s|
  s.name         = 'HHServices'
  s.version      = '2.0'
  s.summary      = 'An Objective-C framework that greatly simplifies publishing, browsing, and resolution of DNS-SD (Bonjour) services'
  s.description  = 'HHServices is an Objective-C framework that makes publishing, browsing, and resolving DNS-SD (Bonjour) services easy. This is useful for creating Bluetooth and Wifi P2P (adhoc) networks on iOS (in combination with a socket or server package, ie. CocoaAsyncSocket).'
  s.homepage     = 'https://github.com/tolo/HHServices'
  s.license      = 'MIT'
  s.authors      = { 'Tobias Löfstrand' => 'tobias@leafnode.se' }
  s.source       = { :git => 'https://github.com/tolo/HHServices.git', :tag => s.version.to_s }
  s.ios.deployment_target = '7.0'
if defined?(s.tvos)
  s.tvos.deployment_target = '9.0'
end
  s.source_files = 'HHServices/*.{h,m}'
  s.requires_arc = true
  s.frameworks   = 'Foundation'
end
