//
//  HHServiceBrowser.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceDiscoveryOperation.h"
#import "HHService.h"


NS_ASSUME_NONNULL_BEGIN


@class HHServiceBrowser;


/**
 * Delegate protocol for HHServiceBrowser.
 */
@protocol HHServiceBrowserDelegate <NSObject>

- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didFindService:(HHService*)service moreComing:(BOOL)moreComing;
- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didRemoveService:(HHService*)service moreComing:(BOOL)moreComing;

@end


/**
 * Provides support for browsing for services of a particular type.
 */
@interface HHServiceBrowser : HHServiceDiscoveryOperation

@property (nonatomic, weak, nullable) id<HHServiceBrowserDelegate> delegate;

@property (nonatomic, strong, readonly) NSString* type;
@property (nonatomic, strong, readonly) NSString* domain;


- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain;

- (HHService*) resolverForService:(NSString*)name;
- (BOOL) resolveService:(NSString*)name delegate:(id<HHServiceDelegate>)resolveDelegate;

/** Begins browsing for services using any interface index. */
- (BOOL) beginBrowse;

/** Begins browsing for services over Bluetooth only. */
- (BOOL) beginBrowseOverBluetoothOnly;

/** Begins browsing for services using the specified interface index. If interfaceIndex is kDNSServiceInterfaceIndexAny, P2P (i.e. Bluetooth) interfaces are only enabled if parameter includeP2P is set to YES. */
- (BOOL) beginBrowse:(uint32_t)interfaceIndex includeP2P:(BOOL)includeP2P;

/** Ends an active browse operation. */
- (void) endBrowse;

@end


NS_ASSUME_NONNULL_END
