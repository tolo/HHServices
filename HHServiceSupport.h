//
//  HHServiceSupport.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <dns_sd.h>

@interface HHServiceSupport : NSObject {
    @private
        CFRunLoopRef runLoop;
    @protected
        DNSServiceRef sdRef;
}

@property (nonatomic, readonly) DNSServiceRef sdRef;

@property (nonatomic, assign) DNSServiceErrorType lastError;
@property (nonatomic, readonly) BOOL hasFailed;

- (void) doDestroy;
- (void) dnsServiceError:(DNSServiceErrorType)error;

- (void) openConnection;
- (void) closeConnection;

@end
