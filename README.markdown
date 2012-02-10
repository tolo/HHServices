HHServices (also known as Hejsan-Hoppsan-Services)
==================================================
This little project came about when we wanted to upgrade two of our apps, PlayMeNext & PlayMyQ, to use some nifty new iOS5 features, just to be rudely awakened by the fact that bluetooth networking via NSNetService was no longer possible. So what to do? Well, the only option seemed to be to go low-level and dive right down into the DNSService* (dns-sd) APIs. This is the result. And to spare others from having to take this low-level road, I decided to share it with those having the same problem/need. 

This framework may not be perfect and it doesn't do everything that NSNetService does, but it handles the most important stuff and hopefully it can be of some use to you too. Enjoy.


Usage examples
===============

Publish service
---------------

    publisher = [[HHServicePublisher alloc] initWithName:@"MyDisplayName"
                                    type:@"_myservice._tcp." domain:@"local." txtData:nil port:12345];
    publisher.delegate = self;
    [publisher beginPublish];

Discover service
----------------

    browser = [[HHServiceBrowser alloc] initWithType:@"_myservice._tcp." domain:@"local."];
    browser.delegate = self;
    [browser beginBrowse];
    
Resolve service
---------------

    - (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didFindService:(HHService*)service moreComing:(BOOL)moreComing {
        ...
        service.delegate = self;
        [service beginResolve];
        ...
    }
    
    - (void) serviceDidResolve:(HHService*)service {
    	...
    	NSArray* rawAddresses = service.resolvedAddresses;
	    for (NSData* addressData in rawAddresses) {
		    struct sockaddr* address = (struct sockaddr*)[addressData bytes];
		    ...
	    }
    	...
    }
