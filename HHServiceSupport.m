//
//  HHServiceSupport.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"


static void sdRefSocketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address,
                                const void* data, void* info) {
    HHServiceSupport *serviceConnection = (HHServiceSupport *)info;
    
    DNSServiceErrorType err = DNSServiceProcessResult(serviceConnection.sdRef); // Will result in registered callback beeing invoked
    if (err != kDNSServiceErr_NoError) {
        [serviceConnection dnsServiceError:err];
    }
}


#pragma mark -
#pragma mark "Private" interface


@interface HHServiceSupport ()

@property (nonatomic, readwrite) DNSServiceRef sdRef;
@property (nonatomic, readwrite) CFSocketRef sdRefSocket;
@property (nonatomic, readwrite) CFRunLoopSourceRef runLoopSource;

@end


@implementation HHServiceSupport

@synthesize sdRef, sdRefSocket, runLoopSource, 
    lastError;


#pragma mark -
#pragma mark Creation and destruction


- (void) dealloc {
    [self doDestroy];
    
    [super dealloc];
}


#pragma mark -
#pragma mark "protected" methods


- (void) doDestroy {
    if( runLoopSource != NULL ) {
        CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
        runLoopSource = NULL;
    }
    if( runLoop != NULL ) {
        CFRelease(runLoop);
        runLoop = NULL;
    }
    if( sdRefSocket != NULL ) {
        CFSocketInvalidate(sdRefSocket);
        CFRelease(sdRefSocket);
        sdRefSocket = NULL;
    }
    if ( sdRef != NULL ) {
        DNSServiceRefDeallocate(sdRef);
        sdRef = NULL;
    }
}

- (void) dnsServiceError:(DNSServiceErrorType)error {
    lastError = error;
}


#pragma mark -
#pragma mark HHServiceSupport


- (void) openConnection {
    if( !sdRef ) lastError = kDNSServiceErr_Unknown;
    else if (lastError == kDNSServiceErr_NoError) {
        int fd = DNSServiceRefSockFD(sdRef);
        if( fd >= 0 ) {
            CFSocketContext context = {0, self, NULL, NULL, NULL};
            
            sdRefSocket = CFSocketCreateWithNative(NULL, fd, kCFSocketReadCallBack, sdRefSocketCallback, &context);
            if( sdRefSocket != NULL ) {
                CFSocketSetSocketFlags(sdRefSocket, CFSocketGetSocketFlags(sdRefSocket) & ~kCFSocketCloseOnInvalidate);
                
                runLoopSource = CFSocketCreateRunLoopSource(NULL, sdRefSocket, 0);
                if( runLoopSource != NULL ) {
                    runLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
                    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
                    CFRelease(runLoopSource);
                } else lastError = kDNSServiceErr_Unknown;
            } else lastError = kDNSServiceErr_Unknown;
        } else lastError = kDNSServiceErr_Unknown;
    }
}

- (void) closeConnection {
    [self doDestroy];
}

- (BOOL) hasFailed {
    return lastError != kDNSServiceErr_NoError;
}


@end
