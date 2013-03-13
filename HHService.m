//
//  HHService.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHService.h"

#import "HHServiceSupport+Private.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <net/if.h>


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

- (void) didResolveService:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error;
- (void) didResolveServiceAddress:(NSData*)addressData error:(DNSServiceErrorType)error;

@end


#pragma mark -
#pragma mark Callbacks


static void getAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                                const char* hostName, const struct sockaddr* address, uint32_t ttl, void* context ) {

    ResolveResult* resolveResult = (ResolveResult*)context;
    HHService* serviceResolver = resolveResult.serviceResolver;
    NSData* addressData = nil;
    if ( errorCode == kDNSServiceErr_NoError ) {

        // Set port if not set
        struct sockaddr_in* sin = (struct sockaddr_in*)address;
        if( sin->sin_port == 0 ) sin->sin_port = resolveResult.port;

        addressData = [[NSData alloc] initWithBytes:address length:sizeof(struct sockaddr)];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [serviceResolver didResolveServiceAddress:addressData error:errorCode];
        
        [addressData release];
    });
}

static void resolveCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                            const char* fullname, const char* hosttarget, uint16_t port, uint16_t txtLen,
                            const unsigned char* txtRecord, void* context) {

    HHService* serviceResolver = (HHService*)context;
    BOOL moreComing = flags & kDNSServiceFlagsMoreComing;

    ResolveResult* resolveResult = nil;
    NSString* newName = [[NSString alloc] initWithCString:hosttarget encoding:NSUTF8StringEncoding];
    
    if (errorCode == kDNSServiceErr_NoError) {
        char interfaceName[IFNAMSIZ];
        if( if_indextoname(interfaceIndex, interfaceName) != NULL ) {
            [serviceResolver HHLogDebug:@"Resolved host %@, port %d, interface index %d ('%s') - getting address info", newName, port, interfaceIndex, interfaceName];
            resolveResult = [[ResolveResult alloc] init];
            resolveResult.hostName = newName;
            resolveResult.port = port; // Keep network byte ordering since we will use this in struct sockaddr_in
            resolveResult.interfaceIndex = interfaceIndex;
        } else {
            [serviceResolver HHLogDebug:@"Resolve returned invalid interface index (%d)", interfaceIndex];
        }
    }
    
    NSData* txtData = [[NSData alloc] initWithBytes:txtRecord length:txtLen];

    dispatch_async(dispatch_get_main_queue(), ^{
        [serviceResolver didResolveService:resolveResult txtData:txtData moreComing:moreComing error:errorCode];
        
        [resolveResult release];
        [newName release];
        [txtData release];
    });
}


#pragma mark -
#pragma mark HHService


@implementation HHService {
//    DNSServiceRef getAddressInfoRef;
}

@synthesize delegate,
    name, type, domain, includeP2P,
    resolved, resolvedHostName, resolvedAddresses, txtData;


#pragma mark -
#pragma mark Internal methods


- (void) didResolveService:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError ) {
        resolveResult.serviceResolver = self;
        [self.resolveResults addObject:resolveResult];
        if( !moreComing ) {
            [self HHLogDebug:@"Getting address info for resolved addresses"];
            self.resolvedHostName = resolveResult.hostName;
            self.txtData = svcTxtData;
            [self getNextAddressInfo];
        }
    } else {
        [self HHLogDebug:@"Error resolving service: %d", error];
        self.resolved = NO;
        [self.delegate serviceDidNotResolve:self];
    }
}

- (void) didResolveServiceAddress:(NSData*)addressData error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError ) {
        // Add address if not already added
        for(NSData* existingAddrData in self.resolvedAddresses) {
            if ( [existingAddrData isEqualToData:addressData] ) {
                addressData = nil; // Adress already added
                break;
            }
        }
        if( addressData ) [(NSMutableArray*)self.resolvedAddresses addObject:addressData];
        
        [self.resolveResults removeLastObject];
        if( self.resolveResults.count ) {
            [self HHLogDebug:@"Getting address info for next address"];
            [self getNextAddressInfo];
        } else {
            [self HHLogDebug:@"Resolved last address"];
            self.resolved = YES;
            [self.delegate serviceDidResolve:self];
        }
    } else {
        [self HHLogDebug:@"Error getting address info: %d", error];
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

//- (void) doDestroy {
//    if ( getAddressInfoRef != NULL ) {
//        DNSServiceRefDeallocate(getAddressInfoRef);
//        getAddressInfoRef = NULL;
//    }
//    [super doDestroy];
//}


#pragma mark -
#pragma mark Get address info methods (resolve step2)


- (void) getNextAddressInfo {
    ResolveResult* result = [self.resolveResults lastObject];
    if( result ) {
//        if( getAddressInfoRef ) {
//            DNSServiceRefDeallocate(getAddressInfoRef);
//        }
//        DNSServiceRef getAddressInfoRef = self.sharedConnection.connectionRef;
//        getAddressInfoRef = NULL;
        DNSServiceRef getAddressInfoRef = NULL;
        
        const char* hosttarget = [result.hostName cStringUsingEncoding:NSUTF8StringEncoding];
//        DNSServiceErrorType err = DNSServiceGetAddrInfo(&getAddressInfoRef, kDNSServiceFlagsShareConnection, result.interfaceIndex, kDNSServiceProtocol_IPv4, hosttarget, getAddrInfoCallback, result);
        DNSServiceErrorType err = DNSServiceGetAddrInfo(&getAddressInfoRef, 0, result.interfaceIndex, kDNSServiceProtocol_IPv4, hosttarget, getAddrInfoCallback, result);
        
        if( err == kDNSServiceErr_NoError ) {
            [self HHLogDebug:@"Beginning address lookup"];
            [super setServiceRef:getAddressInfoRef];
        } else {
            [self HHLogDebug:@"Error doing address lookup"];
            [self dnsServiceError:self.lastError];
        }
    }
}


#pragma mark -
#pragma mark HHService public methods


- (BOOL) beginResolve {
    self.resolved = NO;
    self.resolvedAddresses = [NSMutableArray array];
    self.resolveResults = [NSMutableArray array];
    
    const char* _name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* _domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceFlags flags = 0;
#if TARGET_OS_IPHONE == 1
    flags |= (uint32_t)(includeP2P ? kDNSServiceFlagsIncludeP2P : 0);
#endif
        
    DNSServiceRef resolveRef = nil;
    DNSServiceErrorType err = DNSServiceResolve(&resolveRef, flags, kDNSServiceInterfaceIndexAny,
                                   _name, _type, _domain, resolveCallback, self);
    
    if( err == kDNSServiceErr_NoError ) {
        [self HHLogDebug:@"Beginning resolve"];
        return [super setServiceRef:resolveRef];
    } else {
        [self HHLogDebug:@"Error starting resolve"];
        [self dnsServiceError:err];
        return NO;
    }
}

- (void) endResolve {
    [super resetServiceRef];
}


#pragma mark -
#pragma mark Equals & hashcode etc


- (NSString*) identityString {
    return [NSString stringWithFormat:@"%@|%@|%@", self.name, self.type, self.domain];
}

- (NSUInteger) hash {
	return [self.identityString hash];
}

- (BOOL) isEqual:(id)anObject {
	return [anObject isKindOfClass:[self class]] && [self.identityString isEqual:((HHService*)anObject).identityString];
}

- (NSString*) description {
    NSMutableArray* addressesAsStrings = [NSMutableArray array];
    for (int i=0; i<self.resolvedAddresses.count; i++) {
        const struct sockaddr_in* sin = (struct sockaddr_in*)[self.resolvedAddresses[i] bytes];
		[addressesAsStrings addObject:[NSString stringWithFormat:@"%@:%d", @(inet_ntoa(sin->sin_addr)), ntohs(sin->sin_port)]];
    }
    return [NSString stringWithFormat:@"HHService[0x%08X, %@, %@, %@, %@, %@, %d]", (unsigned int)self,
            self.name, self.type, self.domain, self.resolvedHostName, addressesAsStrings, txtData.length];
}


@end
