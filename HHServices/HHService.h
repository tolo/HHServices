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

- (void) serviceDidResolve:(HHService*)service;
- (void) serviceDidNotResolve:(HHService*)service;

@end


/**
 * Represents the details about a published service, and facilitates resolving of address information for such a service.
 */
@interface HHService : HHServiceDiscoveryOperation

@property (nonatomic, weak) id<HHServiceDelegate> delegate;

@property (nonatomic, strong, readonly) NSString* name;
@property (nonatomic, strong, readonly) NSString* type;
@property (nonatomic, strong, readonly) NSString* domain;
@property (nonatomic, readonly) BOOL includeP2P;

@property (nonatomic, readonly) BOOL resolved;
@property (nonatomic, strong, nullable, readonly) NSString* resolvedHostName;

/** Resolved addresses represented as struct sockaddr_in/sockaddr_in6 wrapped in NSData */
@property (nonatomic, strong, nullable, readonly) NSArray* resolvedAddresses;
/** Resolved internet addresses, represented as NSStrings on the format IP:PORT (e.g. 10.0.0.1:12345 or [2001:db8:85a3:8d3:1319:8a2e:370:7348]:443) */
@property (nonatomic, weak, nullable, readonly) NSArray* resolvedInetAddresses;
/** Resolved IP addresses, represented as NSStrings */
@property (nonatomic, weak, nullable, readonly) NSArray* resolvedIPAddresses;
/** Resolved port numbers, represented as NSNumbers */
@property (nonatomic, weak, nullable, readonly) NSArray* resolvedPortNumbers;

@property (nonatomic, strong, nullable, readonly) NSData* txtData;


- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain;
- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)includeP2P;

- (BOOL) beginResolve;
- (BOOL) beginResolveOverBluetoothOnly;
- (BOOL) beginResolve:(uint32_t)interfaceIndex;
- (void) endResolve;

@end


NS_ASSUME_NONNULL_END
