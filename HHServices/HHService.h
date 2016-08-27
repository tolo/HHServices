//
//  HHService.h
//  Part of Hejsan-Hoppsan-Services - http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceDiscoveryOperation.h"


NS_ASSUME_NONNULL_BEGIN


@class HHService;


/**
 * Delegate protocol for HHService.
 */
@protocol HHServiceDelegate <NSObject>

- (void) serviceDidResolve:(HHService*)service moreComing:(BOOL)moreComing;
- (void) serviceDidNotResolve:(HHService*)service;

@end


@interface HHAddressInfo : NSObject

@property (nonatomic, strong, nullable, readonly) NSString* hostName;
/** Either sockaddr_in or sockaddr_in6. */
@property (nonatomic, readonly) struct sockaddr* address;
@property (nonatomic, readonly) uint16_t portNumber;
/** String representation of the address and port, on the format IP:PORT (e.g. 10.0.0.1:12345 or [2001:db8:85a3:8d3:1319:8a2e:370:7348]:443) */
@property (nonatomic, strong, readonly) NSString* addressAndPortString;
@property (nonatomic, readonly) NSInteger interfaceIndex;
@property (nonatomic, strong, readonly) NSString* interfaceName;
@property (nonatomic, strong, nullable, readonly) NSData* txtData;

@end


/**
 * Represents the details about a published service, and facilitates resolving of address information for such a service.
 */
@interface HHService : HHServiceDiscoveryOperation

@property (nonatomic, weak) id<HHServiceDelegate> delegate;

#pragma mark - Identity properties
@property (nonatomic, strong, readonly) NSString* name;
@property (nonatomic, strong, readonly) NSString* type;
@property (nonatomic, strong, readonly) NSString* domain;


/** If this service was returned by a browser, the interface index will be set to the value returned while browsing. Otherwise, this field will be set to kDNSServiceInterfaceIndexAny by default. */
@property (nonatomic, readonly) uint32_t browsedInterfaceIndex;

@property (nonatomic, readonly) BOOL resolved;
/** The (last) resolved host name. For complete resolved address/service information, see property ´resolvedAddresses´. */
@property (nonatomic, strong, nullable, readonly) NSString* resolvedHostName;
/** The (last) resolved port number. For complete resolved address/service information, see property ´resolvedAddresses´. */
@property (nonatomic, readonly) uint16_t resolvedPortNumber;

/** Resolved host/address information, represented as `HHAddressInfo` objects. */
@property (nonatomic, strong, nullable, readonly) NSArray<HHAddressInfo*>* resolvedAddressInfo;
/** Resolved addresses represented as strings on the format IP:PORT (e.g. 10.0.0.1:12345 or [2001:db8:85a3:8d3:1319:8a2e:370:7348]:443). */
@property (nonatomic, strong, nullable, readonly) NSArray<NSString*>* resolvedAddressStrings;

/** The (last) resolved TXT record data. For complete resolved address/service information, see property ´resolvedAddresses´. */
@property (nonatomic, strong, nullable, readonly) NSData* txtData;


- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain;
- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain browsedInterfaceIndex:(uint32_t)browsedInterfaceIndex;


/** Begins resolving host name and addresses over any interface (kDNSServiceInterfaceIndexAny). */
- (BOOL) beginResolve;

/** Begins resolving host name and addresses using the interface index as specified by the `interfaceIndex` property. If this HHService instance was created by a HHSericeBrowser, that property will be set to the interfaces index obtained while browsing. */
- (BOOL) beginResolveOnBrowsedInterface;

/** Begins resolving host name and addresses over Bluetooth only (kDNSServiceInterfaceIndexP2P). */
- (BOOL) beginResolveOverBluetoothOnly;

/** Begins resolving host name and addresses using the specified interface index. If interfaceIndex is kDNSServiceInterfaceIndexAny, P2P (i.e. Bluetooth) interfaces are only enabled if parameter includeP2P is set to YES. */
- (BOOL) beginResolve:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P;

/** 
 * Begins resolving host name and addresses using the specified interface index. If interfaceIndex is kDNSServiceInterfaceIndexAny, P2P (i.e. Bluetooth) interfaces are only enabled if parameter includeP2P is set to YES.
 *
 * Set parameter addressLookupProtocols to kDNSServiceProtocol_IPv4 for IPv4 addresses, kDNSServiceProtocol_IPv6 for IPv6 addresses, both for both kinds of addresses, or 0 for default behaviour.
 * See DNSServiceGetAddrInfo documentation for more details (protocol parameter).
 */
- (BOOL) beginResolve:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P addressLookupProtocols:(uint32_t)addressLookupProtocols;

/** Begins resolving of only the host name (and port number), over any interface (kDNSServiceInterfaceIndexAny). */
- (BOOL) beginResolveOfHostName;

/** Begins resolving of only the host name (and port number), using the interface index as specified by the `interfaceIndex` property. If this HHService instance was created by a HHSericeBrowser, that property will be set to the interfaces index obtained while browsing. */
- (BOOL) beginResolveOfHostNameOnBrowsedInterface;

/** Begins resolving of only the host name (and port number), over Bluetooth only (kDNSServiceInterfaceIndexP2P). */
- (BOOL) beginResolveOfHostNameOverBluetoothOnly;

/** Begins resolving of only the host name (and port number), using the specified interface index. If interfaceIndex is kDNSServiceInterfaceIndexAny, P2P (i.e. Bluetooth) interfaces are only enabled if parameter includeP2P is set to YES. */
- (BOOL) beginResolveOfHostName:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P;

/** Ends an active resolve operation. */
- (void) endResolve;

@end


NS_ASSUME_NONNULL_END
