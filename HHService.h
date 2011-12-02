//
//  HHService.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"


@class HHService;


@protocol HHServiceDelegate <NSObject>

- (void) serviceDidResolve:(HHService*)service;
- (void) serviceDidNotResolve:(HHService*)service;

@end


@interface HHService : HHServiceSupport

@property (nonatomic, assign) id<HHServiceDelegate> delegate;

@property (nonatomic, retain, readonly) NSString* name;
@property (nonatomic, retain, readonly) NSString* type;
@property (nonatomic, retain, readonly) NSString* domain;
@property (nonatomic, readonly) BOOL includeP2P;

@property (nonatomic, readonly) BOOL resolved;
@property (nonatomic, retain, readonly) NSString* resolvedHostName;
@property (nonatomic, retain, readonly) NSArray* resolvedAddresses;
@property (nonatomic, retain, readonly) NSData* txtData;


- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain;
- (id) initWithName:(NSString*)svcName type:(NSString*)svcType domain:(NSString*)svcDomain includeP2P:(BOOL)includeP2P;

- (void) beginResolve;
- (void) endResolve;

@end
