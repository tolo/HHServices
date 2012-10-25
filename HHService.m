//
//  HHService.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHService.h"

#import <netinet/in.h>
#import <arpa/inet.h>


@interface ResolveResult : NSObject

@property (nonatomic, assign) HHService* serviceResolver;
@property (nonatomic, retain) NSString* hostName;
@property (nonatomic) uint16_t port; // Network byte order
@property (nonatomic) uint32_t interfaceIndex;

@end

@implementation ResolveResult

@synthesize hostName, port, interfaceIndex;

- (void)dealloc {
    self.hostName = nil;
    [super dealloc];
}

@end


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

@property (nonatomic, retain) NSMutableArray* resolveResults;

- (void) didResolveServiceInfo:(DNSServiceErrorType)error resolveResult:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing;
- (void) didResolveServiceAddresses:(DNSServiceErrorType)error;

@end


#pragma mark -
#pragma mark Callbacks


static void getAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                                const char* hostName, const struct sockaddr* address, uint32_t ttl, void* context ) {

    ResolveResult* resolveResult = (ResolveResult*)context;
    HHService* serviceResolver = resolveResult.serviceResolver;
    if (errorCode == kDNSServiceErr_NoError) {

        // Set port if not set
        struct sockaddr_in* sin = (struct sockaddr_in*)address;
        if( sin->sin_port == 0 ) sin->sin_port = resolveResult.port;

        NSData* addressData = [NSData dataWithBytes:address length:sizeof(struct sockaddr)];
        for(NSData* existingAddrData in serviceResolver.resolvedAddresses) {
            if ( [existingAddrData isEqualToData:addressData] ) {
                addressData = nil; // Adress already added
                break;
            }
        }
        if( addressData ) [(NSMutableArray*)serviceResolver.resolvedAddresses addObject:addressData];
    }
    [serviceResolver didResolveServiceAddresses:errorCode];
}

static void resolveCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                            const char* fullname, const char* hosttarget, uint16_t port, uint16_t txtLen,
                            const unsigned char* txtRecord, void* context) {

    HHService* serviceResolver = (HHService*)context;
    BOOL moreComing = flags & kDNSServiceFlagsMoreComing;

    ResolveResult* resolveResult = nil;
    NSString* newName = [[NSString alloc] initWithCString:hosttarget encoding:NSUTF8StringEncoding];
    
    if (errorCode == kDNSServiceErr_NoError) {
        resolveResult = [[ResolveResult alloc] init];
        resolveResult.hostName = newName;
        resolveResult.port = port; // Keep network byte ordering since we will use this in struct sockaddr_in
        resolveResult.interfaceIndex = interfaceIndex;
    }

    [serviceResolver didResolveServiceInfo:errorCode resolveResult:resolveResult txtData:[NSData dataWithBytes:txtRecord length:txtLen] moreComing:moreComing];
    
    [resolveResult release];
    [newName release];
}


#pragma mark -
#pragma mark HHService


@implementation HHService {
    DNSServiceRef resolveRef;
    DNSServiceRef getAddressInfoRef;
}

@synthesize delegate,
    name, type, domain, includeP2P,
    resolved, resolvedHostName, resolvedAddresses, txtData;


#pragma mark -
#pragma mark Internal methods


- (void) didResolveServiceInfo:(DNSServiceErrorType)error resolveResult:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing {
    self.lastError = error;
    
    if (error == kDNSServiceErr_NoError) {
        resolveResult.serviceResolver = self;
        [self.resolveResults addObject:resolveResult];
        if( !moreComing ) {
            self.resolvedHostName = resolveResult.hostName;
            self.txtData = svcTxtData;
            [self getNextAddressInfo];
        }
    } else {
        self.resolved = NO;
        [self.delegate serviceDidNotResolve:self];
    }
}

- (void) didResolveServiceAddresses:(DNSServiceErrorType)error {
    if (error == kDNSServiceErr_NoError) {
        [self.resolveResults removeLastObject];
        if( self.resolveResults.count ) {
            [self getNextAddressInfo];
        } else {
            self.resolved = YES;
            [self.delegate serviceDidResolve:self];
        }
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
    
    self.resolveResults = nil;
    
    [super dealloc];
}

- (void) doDestroy {
    if ( resolveRef != NULL ) {
        DNSServiceRefDeallocate(resolveRef);
        resolveRef = NULL;
    }
    if ( getAddressInfoRef != NULL ) {
        DNSServiceRefDeallocate(getAddressInfoRef);
        getAddressInfoRef = NULL;
    }
    [super doDestroy];
}


#pragma mark -
#pragma mark Get address info methods (resolve step2)


- (void) getNextAddressInfo {
    ResolveResult* result = [self.resolveResults lastObject];
    if( result ) {
        if ( getAddressInfoRef != NULL ) {
            DNSServiceRefDeallocate(getAddressInfoRef);
        }
        getAddressInfoRef = self->sdRef;
        
        const char* hosttarget = [result.hostName cStringUsingEncoding:NSUTF8StringEncoding];
        self.lastError = DNSServiceGetAddrInfo(&getAddressInfoRef, kDNSServiceFlagsShareConnection, result.interfaceIndex, kDNSServiceProtocol_IPv4, hosttarget, getAddrInfoCallback, result);
        if( self.lastError != kDNSServiceErr_NoError ) {
            [self dnsServiceError:self.lastError];
        }
    }
}


#pragma mark -
#pragma mark HHService public methods


- (void) beginResolve {
    [self closeConnection];
    
    self.resolvedAddresses = [NSMutableArray array];
    self.resolveResults = [NSMutableArray array];
    
    const char* _name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    self.lastError = DNSServiceCreateConnection(&self->sdRef);
    if( self.lastError == kDNSServiceErr_NoError ) {
        [super openConnection];
        
        DNSServiceFlags flags = kDNSServiceFlagsShareConnection;
#if TARGET_OS_IPHONE == 1
        flags |= (uint32_t)(includeP2P ? kDNSServiceFlagsIncludeP2P : 0);
#endif
        
        resolveRef = self->sdRef;
        self.lastError = DNSServiceResolve(&resolveRef, flags, kDNSServiceInterfaceIndexAny,
                                       _name, _type, _domain, resolveCallback, self);
        if( self.lastError != kDNSServiceErr_NoError ) {
            [self dnsServiceError:self.lastError];
        }
    } else {
        [self dnsServiceError:self.lastError];
    }
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
    NSMutableArray* addressesAsStrings = [NSMutableArray array];
    for (int i=0; i<self.resolvedAddresses.count; i++) {
        const struct sockaddr_in* sin = (struct sockaddr_in*)[self.resolvedAddresses[i] bytes];
		[addressesAsStrings addObject:[NSString stringWithFormat:@"%@:%d", @(inet_ntoa(sin->sin_addr)), ntohs(sin->sin_port)]];
    }
    return [NSString stringWithFormat:@"HHService[0x%08X, %@, %@, %@, %@, %@]", (unsigned int)self, self.name, self.type, self.domain, self.resolvedHostName, addressesAsStrings];
}


@end
