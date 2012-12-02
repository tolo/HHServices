//
//  HHServiceBrowser.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"
#import "HHService.h"

@class HHServiceBrowser;


@protocol HHServiceBrowserDelegate <NSObject>

- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didFindService:(HHService*)service moreComing:(BOOL)moreComing;
- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didRemoveService:(HHService*)service moreComing:(BOOL)moreComing;

@end


@interface HHServiceBrowser : HHServiceSupport

@property (nonatomic, assign) id<HHServiceBrowserDelegate> delegate;

@property (nonatomic, retain, readonly) NSString* type;
@property (nonatomic, retain, readonly) NSString* domain;
@property (nonatomic) BOOL includeP2P;


- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain;
- (id) initWithType:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)includeP2P;

- (HHService*) resolverForService:(NSString*)name;
- (BOOL) resolveService:(NSString*)name delegate:(id<HHServiceDelegate>)resolveDelegate;

- (BOOL) beginBrowse;
- (void) endBrowse;

@end
