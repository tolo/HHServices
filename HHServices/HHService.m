//
//  HHService.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHService.h"

#import "HHServiceDiscoveryOperation+Private.h"
#import <dns_sd.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <net/if.h>


#pragma mark - ResolveResult

@interface ResolveResult : NSObject

@property (nonatomic, strong) NSString* hostName;
@property (nonatomic) uint16_t port; // Network byte order
@property (nonatomic, strong) NSData* txtData;
@property (nonatomic) uint32_t interfaceIndex;
@property (nonatomic, strong) NSString* interfaceName;

@end

@implementation ResolveResult
@end


#pragma mark - HHAddressInfo

@interface HHAddressInfo ()

@property (nonatomic, strong) NSData* addressData;

@end

@implementation HHAddressInfo

- (instancetype) initWithHostName:(NSString*)hostName portNumber:(uint16_t)portNumber txtData:(NSData*)txtData interfaceIndex:(NSInteger)interfaceIndex interfaceName:(NSString*)interfaceName {
    if( (self = [super init]) ) {
        _hostName = hostName;
        _portNumber = portNumber;
        _txtData = txtData;
        _interfaceIndex = interfaceIndex;
        _interfaceName = interfaceName;
    }
    return self;
}

- (instancetype) initWithHostName:(NSString*)hostName addressData:(NSData*)addressData txtData:(NSData*)txtData interfaceIndex:(NSInteger)interfaceIndex interfaceName:(NSString*)interfaceName {
    if( (self = [super init]) ) {
        _hostName = hostName;
        _addressData = addressData;
        _txtData = txtData;
        _interfaceIndex = interfaceIndex;
        _interfaceName = interfaceName;
        
        struct sockaddr* address = (struct sockaddr*)[addressData bytes];
        if ( address->sa_family == AF_INET6 ) {
            const struct sockaddr_in6* inet6Address = (struct sockaddr_in6*)address;
            _portNumber = ntohs(inet6Address->sin6_port);
        } else {
            const struct sockaddr_in* inet4Address = (struct sockaddr_in*)address;
            _portNumber = ntohs(inet4Address->sin_port);
        }
    }
    return self;
}

- (struct sockaddr*) address {
    return (struct sockaddr*)[self.addressData bytes];
}

- (NSString*) addressAndPortString {
    if( self.addressData == nil ) {
        return nil;
    }
    struct sockaddr* address = self.address;
    
    if ( address->sa_family == AF_INET6 ) {
        const struct sockaddr_in6* inet6Address = (struct sockaddr_in6*)address;
        char straddr[INET6_ADDRSTRLEN];
        inet_ntop(AF_INET6, &inet6Address->sin6_addr, straddr, sizeof(straddr));
        return [NSString stringWithFormat:@"[%s]:%d", straddr, self.portNumber];
    } else {
        const struct sockaddr_in* inet4Address = (struct sockaddr_in*)address;
        return [NSString stringWithFormat:@"%@:%d", @(inet_ntoa(inet4Address->sin_addr)), self.portNumber];
    }
}

- (BOOL) isEqual:(id)object {
    if( object == self ) return YES;
    else if ( [object isKindOfClass:HHAddressInfo.class] ) {
        HHAddressInfo* other = (HHAddressInfo*)object;
        return [self.addressAndPortString isEqual:other.addressAndPortString] && self.interfaceIndex == other.interfaceIndex;
    } else return NO;
}

@end


#pragma mark - HHService "private" interface

@interface HHService ()

// Redefinition of read only properties to readwrite
@property (nonatomic, strong, readwrite) NSString* name;
@property (nonatomic, strong, readwrite) NSString* type;
@property (nonatomic, strong, readwrite) NSString* domain;
@property (nonatomic, readwrite) BOOL resolved;
@property (nonatomic, strong, nullable, readwrite) NSString* resolvedHostName;
@property (nonatomic, strong, nullable, readwrite) NSArray* resolvedAddressInfo;
@property (nonatomic, strong, nullable, readwrite) NSData* txtData;

@property (nonatomic, strong, readonly) ResolveResult* currentResolveResult;
@property (nonatomic, strong) NSMutableArray* resolveResults;
@property (nonatomic, assign) uint16_t lastResolvedPort;

@property (nonatomic) uint32_t addressLookupProtocols;
@property (nonatomic) BOOL resolveHostNameOnly;

- (void) didResolveService:(ResolveResult*)resolveResult moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error;
- (void) didResolveServiceAddress:(HHAddressInfo*)addressInfo moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error;

@end


#pragma mark - Callbacks

static void getAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode,
                                const char* hostName, const struct sockaddr* address, uint32_t ttl, void* context ) {

    HHServiceDiscoveryOperationCallbackContext* callbackContext = (__bridge HHServiceDiscoveryOperationCallbackContext*)context;
    HHService* serviceResolver = (HHService*)callbackContext.operation;
    
    if( serviceResolver ) {
        HHAddressInfo* addressInfo = nil;
        BOOL moreComing = flags & kDNSServiceFlagsMoreComing;
        
        if ( errorCode == kDNSServiceErr_NoError ) {
            NSString* hostNameString = nil;
            if( hostName != nil ) {
                hostNameString = [[NSString alloc] initWithCString:hostName encoding:NSUTF8StringEncoding];
            }
            if( !hostNameString || hostNameString.length == 0 ) {
                hostNameString = serviceResolver.currentResolveResult.hostName;
            }
            
            NSData* addressData = nil;
            if( address->sa_family == AF_INET ) {
                struct sockaddr_in* sin = (struct sockaddr_in*)address;
                if( sin->sin_port == 0 ) sin->sin_port = serviceResolver.lastResolvedPort; // Set port if not set
                addressData = [[NSData alloc] initWithBytes:address length:sizeof(struct sockaddr_in)];
            } else if( address->sa_family == AF_INET6 ) {
                struct sockaddr_in6* sin = (struct sockaddr_in6*)address;
                if( sin->sin6_port == 0 ) sin->sin6_port = serviceResolver.lastResolvedPort; // Set port if not set
                addressData = [[NSData alloc] initWithBytes:address length:sizeof(struct sockaddr_in6)];
            }
            addressInfo = [[HHAddressInfo alloc] initWithHostName:hostNameString addressData:addressData txtData:serviceResolver.currentResolveResult.txtData
                                                   interfaceIndex:interfaceIndex interfaceName:serviceResolver.currentResolveResult.interfaceName];
        }
        dispatch_async(serviceResolver.effectiveMainDispatchQueue, ^{
            [serviceResolver didResolveServiceAddress:addressInfo moreComing:moreComing error:errorCode];
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
                resolveResult.txtData = [[NSData alloc] initWithBytes:txtRecord length:txtLen];
                resolveResult.interfaceIndex = interfaceIndex;
                resolveResult.interfaceName = [[NSString alloc] initWithCString:interfaceName encoding:NSUTF8StringEncoding];
            } else {
                // Ignore invalid interfaces
                [serviceResolver HHLogDebug:@"Resolve returned invalid interface index (%d)", interfaceIndex];
            }
        }

        dispatch_async(serviceResolver.effectiveMainDispatchQueue, ^{
            [serviceResolver didResolveService:resolveResult moreComing:moreComing error:errorCode];
        });
    }
}


#pragma mark - HHService

@implementation HHService


#pragma mark - Internal methods

- (void) didResolveService:(ResolveResult*)resolveResult moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError && resolveResult ) {
        self.lastResolvedPort = resolveResult.port;
        self.resolvedHostName = resolveResult.hostName;
        self.txtData = resolveResult.txtData;
        
        if( self.resolveHostNameOnly ) {
            HHAddressInfo* addressInfo = [[HHAddressInfo alloc] initWithHostName:resolveResult.hostName portNumber:self.resolvedPortNumber txtData:resolveResult.txtData
                                               interfaceIndex:resolveResult.interfaceIndex interfaceName:resolveResult.interfaceName];
            [(NSMutableArray*)self.resolvedAddressInfo addObject:addressInfo];
            
            [self.delegate serviceDidResolve:self moreComing:moreComing];
        } else {
            [self.resolveResults addObject:resolveResult];
            
            if( !moreComing ) {
                [self HHLogDebug:@"Getting address info for resolved addresses"];
                [self getNextAddressInfo];
            }
        }
    } else if ( !moreComing ) {
        [self HHLogDebug:@"Error resolving service: %d", error];
        self.resolved = NO;
        [self.delegate serviceDidNotResolve:self];
    }
}

- (void) didResolveServiceAddress:(HHAddressInfo*)addressInfo moreComing:(BOOL)moreComing error:(DNSServiceErrorType)error {
    self.lastError = error;
    
    if ( error == kDNSServiceErr_NoError && addressInfo ) {
        // Add address if not already added
        for(HHAddressInfo* existingAddrInfo in self.resolvedAddressInfo) {
            if ( [existingAddrInfo isEqual:addressInfo] ) {
                addressInfo = nil; // Adress already added
                break;
            }
        }
        if( addressInfo ) [(NSMutableArray*)self.resolvedAddressInfo addObject:addressInfo];
        
        if ( !moreComing ) {
            [self.resolveResults removeLastObject];
            if( self.resolveResults.count ) {
                [self.delegate serviceDidResolve:self moreComing:YES];
                [self HHLogDebug:@"Getting address info for next address"];
                [self getNextAddressInfo];
            } else {
                [self HHLogDebug:@"Resolved last address"];
                self.resolved = YES;
                [self.delegate serviceDidResolve:self moreComing:NO];
            }
        }
    } else if ( !moreComing ) {
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
    return [self initWithName:svcName type:svcType domain:svcDomain browsedInterfaceIndex:kDNSServiceInterfaceIndexAny];
}

- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain browsedInterfaceIndex:(uint32_t)browsedInterfaceIndex {
    if( (self = [super init]) ) {
        _name = svcName;
        _type = svcType;
        _domain = svcDomain;
        _addressLookupProtocols = 0;
        _browsedInterfaceIndex = browsedInterfaceIndex;
    }
    return self;
}


#pragma mark - Properties

- (ResolveResult*) currentResolveResult {
    return [self.resolveResults lastObject];
}

- (uint16_t) resolvedPortNumber {
    return ntohs(self.lastResolvedPort);
}


#pragma mark - Get address info methods (resolve step2)

- (void) getNextAddressInfo {
    ResolveResult* result = self.currentResolveResult;
    if( result ) {
        DNSServiceRef getAddressInfoRef = NULL;
        
        const char* hosttarget = [result.hostName cStringUsingEncoding:NSUTF8StringEncoding];
        DNSServiceErrorType err = DNSServiceGetAddrInfo(&getAddressInfoRef, 0, result.interfaceIndex, self.addressLookupProtocols,
                                                        hosttarget, getAddrInfoCallback, (__bridge void *)([self setCurrentCallbackContextWithSelf]));
        
        if( err == kDNSServiceErr_NoError ) {
            [self HHLogDebug:@"Beginning address lookup on interface index %d (%@)", result.interfaceIndex, result.interfaceName];
            [super setServiceRef:getAddressInfoRef];
        } else {
            [self HHLogDebug:@"Error doing address lookup"];
            [self dnsServiceError:self.lastError];
        }
    }
}


#pragma mark - HHService public methods

- (BOOL) beginResolve {
    return [self beginResolve:kDNSServiceInterfaceIndexAny includeP2P:YES];
}

- (BOOL) beginResolveOnBrowsedInterface {
    return [self beginResolve:self.browsedInterfaceIndex includeP2P:YES];
}

- (BOOL) beginResolveOverBluetoothOnly {
    return [self beginResolve:kDNSServiceInterfaceIndexP2P includeP2P:YES];
}

- (BOOL) beginResolve:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P {
    return [self beginResolve:interfaceIndex includeP2P:includeP2P addressLookupProtocols:0];
}

- (BOOL) beginResolve:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P addressLookupProtocols:(uint32_t)addressLookupProtocols {
    return [self beginResolve:interfaceIndex hostNameOnly:NO includeP2P:includeP2P addressLookupProtocols:addressLookupProtocols];
}

- (BOOL) beginResolveOfHostName {
    return [self beginResolveOfHostName:kDNSServiceInterfaceIndexAny includeP2P:YES];
}

- (BOOL) beginResolveOfHostNameOnBrowsedInterface {
    return [self beginResolveOfHostName:self.browsedInterfaceIndex includeP2P:YES];
}

- (BOOL) beginResolveOfHostNameOverBluetoothOnly {
    return [self beginResolveOfHostName:kDNSServiceInterfaceIndexP2P includeP2P:YES];
}

- (BOOL) beginResolveOfHostName:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P {
    return [self beginResolve:interfaceIndex hostNameOnly:YES includeP2P:includeP2P addressLookupProtocols:0];
}

- (BOOL) beginResolve:(uint32_t)interfaceIndex hostNameOnly:(BOOL)hostNameOnly includeP2P:(BOOL)includeP2P addressLookupProtocols:(uint32_t)addressLookupProtocols {
    if( self.serviceRef != nil ) {
        [self HHLogDebug:@"Resolve operation already executing"];
        return NO;
    }
    
    self.resolveHostNameOnly = hostNameOnly;
    self.addressLookupProtocols = addressLookupProtocols;
    
    self.resolved = NO;
    self.resolvedAddressInfo = self.resolvedAddressInfo ?: [NSMutableArray array];
    self.resolveResults = [NSMutableArray array];
    
    const char* name = [self.name cStringUsingEncoding:NSUTF8StringEncoding];
    const char* type = [self.type cStringUsingEncoding:NSUTF8StringEncoding];
    const char* domain = [self.domain cStringUsingEncoding:NSUTF8StringEncoding];

    DNSServiceRef resolveRef = nil;
    DNSServiceFlags flags = includeP2P ? kDNSServiceFlagsIncludeP2P : 0;
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

- (NSArray<NSString*>*) resolvedAddressStrings {
    NSMutableArray* addresses = [NSMutableArray array];
    for (HHAddressInfo* info in self.resolvedAddressInfo ) {
        NSString* addressString = info.addressAndPortString;
        if( addressString != nil ) {
            [addresses addObject:addressString];
        } else if( info.hostName != nil ) {
            [addresses addObject:[NSString stringWithFormat:@"%@:%d", info.hostName, info.portNumber]];
        }
    }
    return addresses;
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
            self.name, self.type, self.domain, self.resolvedHostName, self.resolvedAddressStrings, (int)self.txtData.length];
}

@end
