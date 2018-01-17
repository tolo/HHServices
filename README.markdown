# HHServices (also known as Hejsan-Hoppsan-Services)

This little project came about when we wanted to upgrade two of our apps, PlayMeNext & PlayMyQ, to use some nifty new iOS5 features, just to be rudely awakened by the fact that bluetooth networking via NSNetService was no longer possible. So what to do? Well, the only option seemed to be to go low-level and dive right down into the DNSService* (dns-sd) APIs. This is the result. And to spare others from having to take this low-level road, I decided to share it with those having the same problem/need.

This framework may not be perfect and it doesn't do everything that NSNetService does, but it handles the most important stuff and hopefully it can be of some use to you too. Enjoy.


# Changes in 2.0

* Converted to ARC
* Added IPv6 support ( ```HHService``` is now capable of supporting both ```sockaddr_in``` and ```sockaddr_in6``` addresses)
* API changes in class ```HHService``` related to resolving of host name and addresses (method changes, property changes, introduced class ```HHAddressInfo``` etc)
* Added ```moreComing``` parameter to ```serviceDidResolve``` method in ```HHServiceDelegate```
* Added nullability support for better Swift interoperability
* Added Cocoapods support
* Added support for restricting service discovery and publishing to Bluetooth only (thanks @xaphod), as well as to a specific interface index

### More details about restricting service discovery and publishing to Bluetooth only (description provided by @xaphod):
Version 2.0 adds the ability to specify that service browsing, publishing, and resolution should be done over Bluetooth only. This is as per Apple's Technical Q&A 1753: https://developer.apple.com/library/ios/qa/qa1753/_index.html. Note that this doesn't stop peers from discovering non-Bluetooth IP addresses of your device(s), but it DOES stop the wifi radio from being placed into adhoc mode multiple times a second (the cause of wifi throughput / performance degradation when using Apple's MultipeerConnectivity framework). NSNetService and Multipeer both have this problem because you cannot limit them to Bluetooth (or wifi) only, and (as of iOS 9.3) calling stopAdvertise() only takes effect after 30 seconds or so, meaning you cannot micro-manage stop/start advertising.


# Usage examples

Below are some quick usage examples. There are also sample projects for publishing and browsing/resolving in the `samples` directory.

## Publish service

```objective-c
NSUInteger serverPort;
// Setup your server (maybe using something like GCDAsyncSocket or CocoaHTTPServer etc)
...

// Setup the service publisher - remember to update the type parameter with your actual service type
publisher = [[HHServicePublisher alloc] initWithName:@"MyDisplayName"
                                  type:@"_myexampleservice._tcp." domain:@"local." txtData:nil port:serverPort];
publisher.delegate = self;
[publisher beginPublish];
```


## Discover service

```objective-c
// Browse for services - make sure you set the type parameter to your service type
browser = [[HHServiceBrowser alloc] initWithType:@"_myexampleservice._tcp." domain:@"local."];
browser.delegate = self;
[browser beginBrowse];
```

## Resolve service

```objective-c
- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didFindService:(HHService*)service moreComing:(BOOL)moreComing {
    ...
    service.delegate = self;
    [service beginResolve]; // There are also a bunch of other methods for resolving the service - 
    // for instance, if you're only interested in the host name, you could instead use beginResolveOfHostName

    // Make sure you retain the service object (for instance add it to a list of services currently
    // being resolved), otherwise it will be deallocated upon return of this method.
    ...
}

- (void) serviceDidResolve:(HHService*)service moreComing:(BOOL)moreComing {
    ...
    // Create yourself a nice little socket. For example if you're using HTTP, set up
    // the connection using for example NSURLSession or AFNetworking. Or if you
    // want to use a custom TCP protocol, have a look GCDAsyncSocket for instance.

    // It's always good to do a bit of clean-up when you're done resolving:
    if( !moreComing ) {
        service.delegate = nil;
        [service endResolve];
    }

    // It's usually a good idea to attempt to connect using the host name of the service...
    if( service.resolvedHostName != nil ) {
        NSLog(@"Attempting to connect to %@:%d", service.resolvedHostName, service.resolvedPortNumber);
        [self myNiftyMethodToCreateSocketForHost:service.resolvedHostName port:service.resolvedPortNumber];
    }
    else {
        // ...but you can of course also connect using the resolved IPv4/IPv6 address
        for(HHAddressInfo* addressInfo in service.resolvedAddressInfo) {
            struct sockaddr* address = addressInfo.address
            if ( address->sa_family == AF_INET6 ) {
                NSLog(@"Attempting to connect to IPv6 address %@", addressInfo.addressAndPortString);
            } else {
                NSLog(@"Attempting to connect to IPv4 address %@", addressInfo.addressAndPortString);
            }

            BOOL connected = [self myNiftyMethodToCreateSocketForAddress:address];
            if( connected ) break;
        }
    }
}
```


# Apps and frameworks using HHServices

* [PlayMyQ - Music Player • Remote Control • Jukebox](https://itunes.apple.com/app/playmyq-hd-music-player-remote/id432506056?mt=8)
* [Bluepeer - Framework providing MultipeerConnectivity-like functionality, but without wifi performance issues](https://github.com/xaphod/Bluepeer)
* [WiFi Booth for Canon, Nikon, Sony, and Eye-Fi](http://wifibooth.com)
* [BluePrint for sharing printing over Bluetooth](https://wifibooth.com/blueprint/)

