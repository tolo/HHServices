//
//  HHServiceSupport.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"
#import "HHServiceSupport+Private.h"


@implementation HHServiceSupport {
    DNSServiceRef sdRef;
    dispatch_queue_t sdDispatchQueue;
}

@synthesize sdDispatchQueue, lastError;


- (void) HHLogDebug:(NSString*)format, ... {
#ifdef DEBUG
    va_list vl;
    va_start(vl, format);
    NSString* logMessage = [[[NSString alloc] initWithFormat:format arguments:vl] autorelease];
    NSLog(@"%@ - %@", self, logMessage);
    va_end(vl);
#endif
}


#pragma mark -
#pragma mark Creation and destruction


- (id) init {
    self = [super init];
    if (self) {
        sdDispatchQueue = dispatch_queue_create("se.leafnode.HHServices.sdDispatchQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void) dealloc {
    [self doDestroy];
    
    dispatch_release(sdDispatchQueue);
    
    [super dealloc];
}


#pragma mark -
#pragma mark "protected" methods


- (void) doDestroy {
    if ( sdRef != NULL ) {
        DNSServiceRefDeallocate(sdRef);
        sdRef = NULL;
    }
}

- (void) dnsServiceError:(DNSServiceErrorType)error {
    [self HHLogDebug:@"Error: %d", error];
    lastError = error;
}


#pragma mark -
#pragma mark HHServiceSupport


- (BOOL) setServiceRef:(DNSServiceRef)serviceRef {
    if( sdRef ) DNSServiceRefDeallocate(sdRef);
    sdRef = serviceRef;
    DNSServiceErrorType err = DNSServiceSetDispatchQueue(sdRef, sdDispatchQueue);
    if( err != kDNSServiceErr_NoError ) {
        [self dnsServiceError:err];
        return NO;
    } else return YES;
}

- (void) resetServiceRef {
    if ( sdRef != NULL ) {
        DNSServiceRefDeallocate(sdRef);
        sdRef = NULL;
    }
}

- (BOOL) hasFailed {
    return lastError != kDNSServiceErr_NoError;
}


@end
