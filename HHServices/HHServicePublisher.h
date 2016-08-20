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
- (id) initWithName:(NSString*)name type:(NSString*)type domain:(NSString*)domain txtData:(nullable NSData*)txtData port:(NSUInteger)port includeP2P:(BOOL)includeP2P;

- (BOOL) beginPublish;
- (BOOL) beginPublishOverBluetoothOnly;
- (BOOL) beginPublish:(uint32_t)interfaceIndex;
- (void) endPublish;

@end


NS_ASSUME_NONNULL_END
