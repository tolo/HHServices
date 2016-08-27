//
//  HHServicePublisher.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceDiscoveryOperation.h"


NS_ASSUME_NONNULL_BEGIN


@class HHServicePublisher;


/**
 * Delegate protocol for HHServicePublisher.
 */
@protocol HHServicePublisherDelegate <NSObject>

- (void) serviceDidPublish:(HHServicePublisher*)servicePublisher;
- (void) serviceDidNotPublish:(HHServicePublisher*)servicePublisher;

@end


/**
 * Provides support for publishing of services, and making them available for discovery (browsing).
 */
@interface HHServicePublisher : HHServiceDiscoveryOperation

@property (nonatomic, weak, nullable) id<HHServicePublisherDelegate> delegate;

@property (nonatomic, strong, readonly) NSString* name;
@property (nonatomic, strong, readonly) NSString* type;
@property (nonatomic, strong, readonly) NSString* domain;

@property (nonatomic, strong, nullable) NSData* txtData;


- (id) initWithName:(NSString*)name type:(NSString*)type domain:(NSString*)domain txtData:(nullable NSData*)txtData port:(NSUInteger)port;

/** Begins publishing the service using any interface index. */
- (BOOL) beginPublish;

/** Begins publishing the service over Bluetooth only. */
- (BOOL) beginPublishOverBluetoothOnly;

/** Begins publishing the service using the specified interface index. If interfaceIndex is kDNSServiceInterfaceIndexAny, P2P (i.e. Bluetooth) interfaces are only enabled if parameter includeP2P is set to YES. */
- (BOOL) beginPublish:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P;

/** Ends an active publish operation. */
- (void) endPublish;

@end


NS_ASSUME_NONNULL_END
