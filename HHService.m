//
//  HHService.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHService.h"

#include <netinet/in.h>


/** "Private" interface */
@interface HHService ()

// Redefinition of read only properties to readwrite
@property (nonatomic, retain, readwrite) NSString* name;
@property (nonatomic, retain, readwrite) NSString* type;
@property (nonatomic, retain, readwrite) NSString* domain;
@property (nonatomic, readwrite) BOOL resolved;
@property (nonatomic, retain, readwrite) NSString* resolvedHostName;
@property (nonatomic, retain, readwrite) NSArray* resolvedAddresses;
@property (nonatomic, retain, readwrite) NSData* txtData;

@property (nonatomic) uint16_t tmpPort; // Network byte order

- (void) didResolveService:(DNSServiceErrorType)error hostName:(NSString*)hostName txtData:(NSData*)_txtData;

@end


#pragma mark -
#pragma mark Callbacks


static void getAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                                const char* hostName, const struct sockaddr* address, uint32_t ttl, void* context ) {

    HHService* serviceResolver = (HHService*)context;
    if (errorCode == kDNSServiceErr_NoError) {

        // Set port if not set
        struct sockaddr_in* sin = (struct sockaddr_in*)address;
        if( sin->sin_port == 0 ) sin->sin_port = serviceResolver.tmpPort;

        NSData* addressData = [NSData dataWithBytes:address length:sizeof(struct sockaddr)];
        for(NSData* existingAddrData in serviceResolver.resolvedAddresses) {
            if ( [existingAddrData isEqualToData:addressData] ) {
                addressData = nil; // Adress already added
                break;
            }
        }
        if( addressData ) [(NSMutableArray*)serviceResolver.resolvedAddresses addObject:addressData];

    } else serviceResolver.lastError = errorCode;
}

static void resolveCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                            const char* fullname, const char* hosttarget, uint16_t port, uint16_t txtLen,
                            const unsigned char* txtRecord, void* context) {

    HHService* serviceResolver = (HHService*)context;
    BOOL moreComing = flags & kDNSServiceFlagsMoreComing;

    if (errorCode == kDNSServiceErr_NoError) {
        serviceResolver.tmpPort = port; // Keep network byte ordering since we will use this in struct sockaddr_in

        // Get IP-address(es)
        DNSServiceRef getInfoRef;
        DNSServiceGetAddrInfo(&getInfoRef, 0, interfaceIndex, kDNSServiceProtocol_IPv4, hosttarget, getAddrInfoCallback, serviceResolver);
        DNSServiceProcessResult(getInfoRef); // May block... (consider doing this async if it shows to be a problem)
        DNSServiceRefDeallocate(getInfoRef);
    }

    if( !moreComing ) {
        NSString* newName = [[NSString alloc] initWithCString:hosttarget encoding:NSUTF8StringEncoding];
        [serviceResolver didResolveService:errorCode hostName:newName txtData:[NSData dataWithBytes:txtRecord length:txtLen]];
        [newName release];
    }
}


#pragma mark -
#pragma mark HHService


@implementation HHService

@synthesize delegate,
    name, type, domain, includeP2P,
    resolved, resolvedHostName, resolvedAddresses, txtData, tmpPort;


#pragma mark -
#pragma mark Internal methods


- (void) didResolveService:(DNSServiceErrorType)error hostName:(NSString*)hostName txtData:(NSData*)svcTxtData {
    self.lastError = error;
    self.resolvedHostName = hostName;
    self.txtData = svcTxtData;
    if (error == kDNSServiceErr_NoError) {
        self.resolved = YES;
        [self.delegate serviceDidResolve:self];
    } else {
        self.resolved = NO;
        [self.delegate serviceDidNotResolve:self];
    }
}

- (void) dnsServiceError:(DNSServiceErrorType)error {
    [super dnsServiceError:error];
    self.resolved = NO;
    [self.delegate serviceDidNotResolve:self];
}


#pragma mark -
#pragma mark Creation and destruction


- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain {
    return [self initWithName:svcName type:svcType domain:svcDomain includeP2P:NO];
}

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)shouldIncludeP2P {
    if( (self = [super init]) ) {
        includeP2P = shouldIncludeP2P;
        self.name = svcName;
        self.type = svcType;
        self.domain = svcDomain;
    }
    return self;
}

- (void) dealloc {
    self.name = nil;
    self.type = nil;
    self.domain = nil;
    
    self.resolvedHostName = nil;
    self.resolvedAddresses = nil;
    self.txtData = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark HHService public methods


- (void) beginResolve {
    [self doDestroy];
    
    self.resolvedAddresses = [NSMutableArray array];
    
    const char* _name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceFlags flags = 0;
#if TARGET_OS_IPHONE == 1
    flags = (uint32_t)(includeP2P ? kDNSServiceFlagsIncludeP2P : 0);
#endif

    self.lastError = DNSServiceResolve(&self->sdRef, flags, kDNSServiceInterfaceIndexAny,
                                       _name, _type, _domain, resolveCallback, self);
    
    [super openConnection];
}

- (void) endResolve {
    [super closeConnection];
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
	return [anObject isKindOfClass:[self class]] && [self.identityString isEqual:((HHService*)anObject).identityString];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"HHService[0x%08X, %@, %@, %@, %@, %@]", self, self.name, self.type, self.domain, self.resolvedHostName, self.resolvedAddresses];
}


@end
