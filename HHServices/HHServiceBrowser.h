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
@property (nonatomic) BOOL includeP2P;


- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain;
- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)includeP2P;

- (HHService*) resolverForService:(NSString*)name;
- (BOOL) resolveService:(NSString*)name delegate:(id<HHServiceDelegate>)resolveDelegate;

- (BOOL) beginBrowse;
- (BOOL) beginBrowseOverBluetoothOnly;
- (BOOL) beginBrowse:(uint32_t)interfaceIndex;
- (void) endBrowse;

@end


NS_ASSUME_NONNULL_END
