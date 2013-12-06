//
//  HHServiceSupport.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"
#import "HHServiceSupport+Private.h"


@implementation ContextWrapper {
    id context;
}

- (id) initWithContext:(id)ctx {
    if (self = [super init]) {
        context = ctx;
    }
    return self;
}

- (id) context {
    @synchronized(self) {
        return context;
    }
}

- (id) contextRetained {
    @synchronized(self) {
        return [context retain];
    }
}

- (void) setContext:(id)ctx {
    @synchronized(self) {
        ctx = context;
    }
}

- (void) dealloc {
    [self setContext:nil];
    [super dealloc];
}

@end


@implementation HHServiceSupport {
    DNSServiceRef sdRef;
}

@synthesize sdDispatchQueue, mainDispatchQueue;


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
        mainDispatchQueue = dispatch_get_main_queue();
    }
    return self;
}

void sdDispatchQueueFinalizer(void* contextWrapper) {
    [((ContextWrapper*)contextWrapper) release];
}

- (void) dealloc {
    if( self.currentCallbackContext ) {
        self.currentCallbackContext.context = nil;
        
        // Setup dispatch queue finalizer to make sure currentCallbackContext is destroyed when queue is destroyed
        [self.currentCallbackContext retain];
        dispatch_set_context(sdDispatchQueue, self.currentCallbackContext);
        dispatch_set_finalizer_f(sdDispatchQueue, sdDispatchQueueFinalizer);
    }
    self.currentCallbackContext = nil;
    
    [self doDestroy];
    
    dispatch_release(sdDispatchQueue);
    dispatch_release(mainDispatchQueue);
    
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
    self.lastError = error;
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
    return self.lastError != kDNSServiceErr_NoError;
}

- (ContextWrapper*) setCurrentCallbackContextWithContext:(id)context {
    self.currentCallbackContext = [[ContextWrapper alloc] initWithContext:context];
    return self.currentCallbackContext;
}

- (void) setMainDispatchQueue:(dispatch_queue_t)dispatchQueue {
    if( dispatchQueue != mainDispatchQueue ) {
        dispatch_release(mainDispatchQueue);
        mainDispatchQueue = dispatchQueue;
        if( dispatchQueue ) dispatch_retain(dispatchQueue);
    }
}


@end



#pragma mark -
#pragma mark Utility categories



@implementation NSDictionary (HHServices)

- (NSData*) dataFromTXTRecordDictionary {
    return [NSNetService dataFromTXTRecordDictionary:self];
}

@end


@implementation NSData (HHServices)

- (NSDictionary*) dictionaryFromTXTRecordData {
    return [NSNetService dictionaryFromTXTRecordData:self];
}

@end
