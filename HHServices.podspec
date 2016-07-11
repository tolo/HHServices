Pod::Spec.new do |s|
  s.name     = 'HHServices'
  s.version  = '1.0.2'
  s.platform = :ios, '6.1'
  s.summary  = 'An Objective-C framework that greatly simplifies publishing, browsing, and resolution of DNS-SD (Bonjour) services'
  s.description  = 'HHServices is an Objective-C framework that makes publishing, browsing, and resolving DNS-SD (Bonjour) services easy. This is useful for creating Bluetooth and Wifi P2P (adhoc) networks on iOS (in combination with a socket or server package, ie. CocoaAsyncSocket).'
  s.homepage = 'https://github.com/tolo/HHServices'
  s.author   = { 'Leafnode AB' => 'unknown@unknown.com' }
  s.source   = { :git => 'https://github.com/xaphod/HHServices.git', :tag => s.version.to_s }
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source_files = "HHServices/*.{h,m}"
  s.requires_arc = false
  #s.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include' }
  #s.xcconfig = {'OTHER_LDFLAGS' => '-ObjC -all_load'}
end
