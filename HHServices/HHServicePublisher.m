//
//  HHServicePublisher.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServicePublisher.h"

#import "HHServiceDiscoveryOperation+Private.h"
#import <dns_sd.h>


@interface HHServicePublisher ()

// Redefinition of read only properties to readwrite
@property (nonatomic, strong, readwrite) NSString* name;
@property (nonatomic, strong, readwrite) NSString* type;
@property (nonatomic, strong, readwrite) NSString* domain;
@property (nonatomic) NSUInteger port;

- (void) serviceDidRegister:(NSString*)newName error:(DNSServiceErrorType)error;

@end


#pragma mark - Callbacks

static void registerServiceCallBack(DNSServiceRef sdRef, DNSServiceFlags flags, DNSServiceErrorType errorCode,
                              const char* name, const char* regType, const char* domain, void* context) {
    
    HHServiceDiscoveryOperationCallbackContext* callbackContext = (__bridge HHServiceDiscoveryOperationCallbackContext*)context;
    HHServicePublisher* servicePublisher = (HHServicePublisher*)callbackContext.operation;
    
    if( servicePublisher ) {
        if( errorCode == kDNSServiceErr_NoError ) {
            NSString* newName = name ? [[NSString alloc] initWithCString:name encoding:NSUTF8StringEncoding] : nil;
            dispatch_async(servicePublisher.effectiveMainDispatchQueue, ^{
                [servicePublisher serviceDidRegister:newName error:errorCode];
            });
        } else {
            [servicePublisher dnsServiceError:errorCode];
        }
    }
}


#pragma mark - HHServicePublisher

@implementation HHServicePublisher


#pragma mark - Internal methods

- (void) serviceDidRegister:(NSString*)newName error:(DNSServiceErrorType)error {
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


#pragma mark - Creation and destruction

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain txtData:(NSData*)svcTxtData port:(NSUInteger)svcPort {
    if( (self = [super init]) ) {
        _name = svcName;
        _type = svcType;
        _domain = svcDomain;
        _txtData = svcTxtData;
        _port = svcPort;
    }
    return self;
}


#pragma mark - Publishing

- (BOOL) beginPublish {
    return [self beginPublish:kDNSServiceInterfaceIndexAny includeP2P:YES];
}

- (BOOL) beginPublishOverBluetoothOnly {
    return [self beginPublish:kDNSServiceInterfaceIndexP2P includeP2P:YES];
}

- (BOOL) beginPublish:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P {
    if( self.serviceRef != nil ) {
        [self HHLogDebug:@"Publish operation already executing"];
        return NO;
    }
    
    const char* name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];
    const void* txtData = [self.txtData bytes];
    uint16_t txtLen = (uint16_t)self.txtData.length;

    uint16_t bigEndianPort = NSSwapHostShortToBig((uint16_t)self.port);

    DNSServiceRef registerRef;
    DNSServiceFlags flags = includeP2P ? kDNSServiceFlagsIncludeP2P : 0;
    DNSServiceErrorType err = DNSServiceRegister(&registerRef, flags, interfaceIndex, name, type, domain, NULL,
                                        bigEndianPort, txtLen, txtData, registerServiceCallBack, (__bridge void *)([self setCurrentCallbackContextWithSelf]));
    
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


#pragma mark - Equals & hashcode etc

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
