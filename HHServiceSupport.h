//
//  HHServiceSupport.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dns_sd.h>

@interface HHServiceSupport : NSObject

@property (nonatomic, assign) DNSServiceErrorType lastError;
@property (nonatomic, readonly) BOOL hasFailed;

- (void) dnsServiceError:(DNSServiceErrorType)error;

- (BOOL) setServiceRef:(DNSServiceRef)serviceRef;
- (void) resetServiceRef;

@end
