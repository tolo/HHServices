//
//  HHServiceSupport.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dns_sd.h>


@interface ContextWrapper : NSObject

@property (assign) id context;
@property (readonly) id contextRetained;

@end


@interface HHServiceSupport : NSObject

@property (nonatomic, assign) DNSServiceErrorType lastError;
@property (nonatomic, readonly) BOOL hasFailed;
@property (nonatomic, strong) ContextWrapper* currentCallbackContext;

/** If you use HHServices in a different dispatch queue than the main dispatch queue, set this property to that queue. */
@property (nonatomic, assign) dispatch_queue_t mainDispatchQueue;


- (void) dnsServiceError:(DNSServiceErrorType)error;

- (BOOL) setServiceRef:(DNSServiceRef)serviceRef;
- (void) resetServiceRef;

- (ContextWrapper*) setCurrentCallbackContextWithContext:(id)context;

@end


#pragma mark -
#pragma mark Utility categories


@interface NSDictionary (HHServices)

- (NSData*) dataFromTXTRecordDictionary;

@end

@interface NSData (HHServices)

- (NSDictionary*) dictionaryFromTXTRecordData;

@end
