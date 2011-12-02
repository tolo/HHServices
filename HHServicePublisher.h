//
//  HHServicePublisher.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2011-11-02.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

#import "HHServiceSupport.h"


@class HHServicePublisher;


@protocol HHServicePublisherDelegate <NSObject>

- (void) serviceDidPublish:(HHServicePublisher*)servicePublisher;
- (void) serviceDidNotPublish:(HHServicePublisher*)servicePublisher;

@end


@interface HHServicePublisher : HHServiceSupport

@property (nonatomic, assign) id<HHServicePublisherDelegate> delegate;

@property (nonatomic, retain, readonly) NSString* name;
@property (nonatomic, retain, readonly) NSString* type;
@property (nonatomic, retain, readonly) NSString* domain;

@property (nonatomic, retain) NSData* txtData;


- (id) initWithName:(NSString*)name type:(NSString*)type domain:(NSString*)domain txtData:(NSData*)txtData port:(NSUInteger)port;
- (id) initWithName:(NSString*)name type:(NSString*)type domain:(NSString*)domain txtData:(NSData*)txtData port:(NSUInteger)port includeP2P:(BOOL)includeP2P;

- (void) beginPublish;
- (void) endPublish;

@end
