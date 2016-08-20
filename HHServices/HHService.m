//
//  HHService.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHService.h"

#import "HHServiceDiscoveryOperation+Private.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <net/if.h>


@interface ResolveResult : NSObject

@property (nonatomic, weak) HHService* serviceResolver;
@property (nonatomic, strong) NSString* hostName;
@property (nonatomic) uint16_t port; // Network byte order
@property (nonatomic) uint32_t interfaceIndex;

@end

@implementation ResolveResult
@end


/** "Private" interface */

@interface HHService ()

// Redefinition of read only properties to readwrite
@property (nonatomic, strong, readwrite) NSString* name;
@property (nonatomic, strong, readwrite) NSString* type;
@property (nonatomic, strong, readwrite) NSString* domain;
@property (nonatomic, readwrite) BOOL resolved;
@property (nonatomic, strong, nullable, readwrite) NSString* resolvedHostName;
@property (nonatomic, strong, nullable, readwrite) NSArray* resolvedAddresses;
@property (nonatomic, strong, nullable, readwrite) NSData* txtData;

@property (nonatomic, strong) NSMutableArray* resolveResults;
@property (assign) uint16_t lastResolvedPort;

- (void) didResolveService:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error;
- (void) didResolveServiceAddress:(NSData*)addressData error:(DNSServiceErrorType)error;

@end


#pragma mark - Callbacks

static void getAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                                const char* hostName, const struct sockaddr* address, uint32_t ttl, void* context ) {

    HHServiceDiscoveryOperationCallbackContext* callbackContext = (__bridge HHServiceDiscoveryOperationCallbackContext*)context;
    HHService* serviceResolver = (HHService*)callbackContext.operation;
    
    if( serviceResolver ) {
        NSData* addressData = nil;
        if ( errorCode == kDNSServiceErr_NoError ) {

            // Set port if not set
            if( address->sa_family == AF_INET ) {
                struct sockaddr_in* sin = (struct sockaddr_in*)address;
                if( sin->sin_port == 0 ) sin->sin_port = serviceResolver.lastResolvedPort;
                addressData = [[NSData alloc] initWithBytes:address length:sizeof(struct sockaddr_in)];
            } else if( address->sa_family == AF_INET6 ) {
                struct sockaddr_in6* sin = (struct sockaddr_in6*)address;
                if( sin->sin6_port == 0 ) sin->sin6_port = serviceResolver.lastResolvedPort;
                addressData = [[NSData alloc] initWithBytes:address length:sizeof(struct sockaddr_in6)];
            }
        }
        dispatch_async(serviceResolver.effectiveMainDispatchQueue, ^{
            [serviceResolver didResolveServiceAddress:addressData error:errorCode];
        });
    }
}

static void resolveCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                            const char* fullname, const char* hosttarget, uint16_t port, uint16_t txtLen,
                            const unsigned char* txtRecord, void* context) {

    HHServiceDiscoveryOperationCallbackContext* callbackContext = (__bridge HHServiceDiscoveryOperationCallbackContext*)context;
        HHService* serviceResolver = (HHService*)callbackContext.operation;
    
    if( serviceResolver ) {
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

        dispatch_async(serviceResolver.effectiveMainDispatchQueue, ^{
            [serviceResolver didResolveService:resolveResult txtData:txtData moreComing:moreComing error:errorCode];
        });
    }
}


#pragma mark - HHService

@implementation HHService


#pragma mark - Internal methods

- (void) didResolveService:(ResolveResult*)resolveResult txtData:(NSData*)svcTxtData moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError && resolveResult ) {
        resolveResult.serviceResolver = self;
        [self.resolveResults addObject:resolveResult];
        if( !moreComing ) {
            [self HHLogDebug:@"Getting address info for resolved addresses"];
            self.resolvedHostName = resolveResult.hostName;
            self.txtData = svcTxtData;
            [self getNextAddressInfo];
        }
    } else if ( !moreComing ) {
        [self HHLogDebug:@"Error resolving service: %d", error];
        self.resolved = NO;
        [self.delegate serviceDidNotResolve:self];
    }
}

- (void) didResolveServiceAddress:(NSData*)addressData error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError && addressData ) {
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


#pragma mark - Creation and destruction

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain {
    return [self initWithName:svcName type:svcType domain:svcDomain includeP2P:NO];
}

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)shouldIncludeP2P {
    if( (self = [super init]) ) {
        _includeP2P = shouldIncludeP2P;
        _name = svcName;
        _type = svcType;
        _domain = svcDomain;
    }
    return self;
}


#pragma mark - Get address info methods (resolve step2)

- (void) getNextAddressInfo {
    ResolveResult* result = [self.resolveResults lastObject];
    if( result ) {
        DNSServiceRef getAddressInfoRef = NULL;
        self.lastResolvedPort = result.port;
        
        const char* hosttarget = [result.hostName cStringUsingEncoding:NSUTF8StringEncoding];
        DNSServiceErrorType err = DNSServiceGetAddrInfo(&getAddressInfoRef, 0, result.interfaceIndex, kDNSServiceProtocol_IPv4,
                                                        hosttarget, getAddrInfoCallback, (__bridge void *)([self setCurrentCallbackContextWithSelf]));
        
        if( err == kDNSServiceErr_NoError ) {
            [self HHLogDebug:@"Beginning address lookup"];
            [super setServiceRef:getAddressInfoRef];
        } else {
            [self HHLogDebug:@"Error doing address lookup"];
            [self dnsServiceError:self.lastError];
        }
    }
}


#pragma mark - HHService public methods

- (BOOL) beginResolve {
    return [self beginResolve:kDNSServiceInterfaceIndexAny];
}

- (BOOL) beginResolveOverBluetoothOnly {
    return [self beginResolve:kDNSServiceInterfaceIndexP2P];
}

- (BOOL) beginResolve:(uint32_t)interfaceIndex {
    self.resolved = NO;
    self.resolvedAddresses = [NSMutableArray array];
    self.resolveResults = [NSMutableArray array];
    
    const char* name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceRef resolveRef = nil;
    DNSServiceFlags flags = self.includeP2P ? kDNSServiceFlagsIncludeP2P : 0;
    DNSServiceErrorType err = DNSServiceResolve(&resolveRef, flags, interfaceIndex,
                                   name, type, domain, resolveCallback, (__bridge void *)([self setCurrentCallbackContextWithSelf]));
    
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

- (NSArray*) resolvedInetAddresses:(id(^)(const struct sockaddr* inetAddress))transformationBlock {
    NSMutableArray* addresses = [NSMutableArray array];
    for (int i=0; i<self.resolvedAddresses.count; i++) {
        const struct sockaddr* address = (struct sockaddr*)[self.resolvedAddresses[i] bytes];
        if( address && (address->sa_family == AF_INET || address->sa_family == AF_INET6) ) {
            [addresses addObject:transformationBlock(address)];
        }
    }
    return addresses;
}

- (NSArray*) resolvedInetAddresses {
    return [self resolvedInetAddresses:^id(const struct sockaddr* inetAddress) {
        if ( inetAddress->sa_family == AF_INET6 ) {
            const struct sockaddr_in6* inet6Address = (struct sockaddr_in6*)inetAddress;
            char straddr[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &inet6Address->sin6_addr, straddr, sizeof(straddr));
            return [NSString stringWithFormat:@"[%s]:%d", straddr, ntohs(inet6Address->sin6_port)];
        } else {
            const struct sockaddr_in* inet4Address = (struct sockaddr_in*)inetAddress;
            return [NSString stringWithFormat:@"%@:%d", @(inet_ntoa(inet4Address->sin_addr)), ntohs(inet4Address->sin_port)];
        }
    }];
}

- (NSArray*) resolvedIPAddresses {
    return [self resolvedInetAddresses:^id(const struct sockaddr* inetAddress) {
        if ( inetAddress->sa_family == AF_INET6 ) {
            const struct sockaddr_in6* inet6Address = (struct sockaddr_in6*)inetAddress;
            char straddr[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &inet6Address->sin6_addr, straddr, sizeof(straddr));
            return @(straddr);
        } else {
            const struct sockaddr_in* inet4Address = (struct sockaddr_in*)inetAddress;
            return @(inet_ntoa(inet4Address->sin_addr));
        }
    }];
}

- (NSArray*) resolvedPortNumbers {
    return [self resolvedInetAddresses:^id(const struct sockaddr* inetAddress) {
        if ( inetAddress->sa_family == AF_INET6 ) {
            const struct sockaddr_in6* inet6Address = (struct sockaddr_in6*)inetAddress;
            return @(ntohs(inet6Address->sin6_port));
        } else {
            const struct sockaddr_in* inet4Address = (struct sockaddr_in*)inetAddress;
            return @(ntohs(inet4Address->sin_port));
        }
    }];
}


#pragma mark - Equals & hashcode etc

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
    return [NSString stringWithFormat:@"HHService[0x%08X, %@, %@, %@, %@, %@, %d]", (unsigned int)self,
            self.name, self.type, self.domain, self.resolvedHostName, self.resolvedInetAddresses, (int)self.txtData.length];
}

@end
