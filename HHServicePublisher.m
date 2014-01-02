//
//  HHServicePublisher.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServicePublisher.h"

#import "HHServiceSupport+Private.h"

@interface HHServicePublisher ()

// Redefinition of read only properties to readwrite
@property (nonatomic, retain, readwrite) NSString* name;
@property (nonatomic, retain, readwrite) NSString* type;
@property (nonatomic, retain, readwrite) NSString* domain;
@property (nonatomic) NSUInteger port;
@property (nonatomic) BOOL includeP2P;

- (void) seviceDidRegister:(NSString*)newName error:(DNSServiceErrorType)error;

@end


#pragma mark -
#pragma mark Callbacks


static void registerServiceCallBack(DNSServiceRef sdRef, DNSServiceFlags flags, DNSServiceErrorType errorCode,
                              const char* name, const char* regType, const char* domain, void* context) {
    
    ContextWrapper* contextWrapper = (ContextWrapper*)context;
    HHServicePublisher* servicePublisher = contextWrapper.contextRetained;
    
    if( servicePublisher ) {
        if( errorCode == kDNSServiceErr_NoError ) {
            NSString* newName = name ? [[NSString alloc] initWithCString:name encoding:NSUTF8StringEncoding] : nil;
            dispatch_async(servicePublisher.mainDispatchQueue, ^{
                [servicePublisher seviceDidRegister:newName error:errorCode];
                
                [newName release];
            });
        } else {
            [servicePublisher dnsServiceError:errorCode];
        }
    }
    
    [contextWrapper releaseContext];
}


#pragma mark -
#pragma mark HHServicePublisher


@implementation HHServicePublisher

@synthesize name, type, domain, txtData, port, includeP2P;
@synthesize delegate;


#pragma mark -
#pragma mark Internal methods


- (void) seviceDidRegister:(NSString*)newName error:(DNSServiceErrorType)error {
    self.lastError = error;
    if (error == kDNSServiceErr_NoError) {
        if( newName ) self.name = newName;
        [self.delegate serviceDidPublish:self];
    } else {
        [self.delegate serviceDidNotPublish:self];
    }
}

- (void) dnsServiceError:(DNSServiceErrorType)error {
    [super dnsServiceError:error];
    [self.delegate serviceDidNotPublish:self];
}


#pragma mark -
#pragma mark Creation and destruction


- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain txtData:(NSData*)svcTxtData port:(NSUInteger)svcPort {
    return [self initWithName:svcName type:svcType domain:svcDomain txtData:svcTxtData port:svcPort includeP2P:YES];
}

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain txtData:(NSData*)svcTxtData port:(NSUInteger)svcPort includeP2P:(BOOL)svcIncludeP2P {
    if( (self = [super init]) ) {
        self.name = svcName;
        self.type = svcType;
        self.domain = svcDomain;
        self.txtData = svcTxtData;
        self.port = svcPort;
        self.includeP2P = svcIncludeP2P;
    }
    return self;
}

- (void) dealloc {
    self.name = nil;
    self.type = nil;
    self.domain = nil;
    self.txtData = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark ServiceConnection


- (BOOL) beginPublish {
    const char* _name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];
    const void* _txtData = [self.txtData bytes];
    uint16_t _txtLen = (uint16_t)self.txtData.length;

    uint16_t bigEndianPort = NSSwapHostShortToBig((uint16_t)port);

    DNSServiceFlags flags = 0;
#if TARGET_OS_IPHONE == 1
    flags = (uint32_t)(includeP2P ? kDNSServiceFlagsIncludeP2P : 0);
#endif

    DNSServiceRef registerRef;
    DNSServiceErrorType err = DNSServiceRegister(&registerRef, flags, kDNSServiceInterfaceIndexAny, _name, _type, _domain, NULL,
                                        bigEndianPort, _txtLen, _txtData, registerServiceCallBack, [self setCurrentCallbackContextWithSelf]);
    
    if( err == kDNSServiceErr_NoError ) {
        return [super setServiceRef:registerRef];
    } else {
        [self dnsServiceError:err];
        return NO;
    }
}

- (void) endPublish {
    [super resetServiceRef];
}


#pragma mark -
#pragma mark Equals & hashcode etc


- (NSString*) identityString {
    return [NSString stringWithFormat:@"%@|%@|%@", self.name, self.type, self.domain];
}

- (NSUInteger)hash {
	return [self.identityString hash];
}

- (BOOL)isEqual:(id)anObject {
	return [anObject isKindOfClass:[self class]] && [self.identityString isEqual:((HHServicePublisher *)anObject).identityString];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"HHServicePublisher[%@, %@, %@]", self.name, self.type, self.domain];
}

@end
