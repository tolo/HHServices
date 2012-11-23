//
//  HHServiceSupport+Private.h
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Created by Tobias on 2012-11-19.
//  Copyright (c) 2011 Leafnode AB. All rights reserved.
//

@interface HHServiceSupport ()

@property (nonatomic, readonly) dispatch_queue_t sdDispatchQueue;

- (void) HHLogDebug:(NSString*)format, ...;

@end
