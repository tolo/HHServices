//
//  ViewController.m
//  PublisherSample
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "ViewController.h"


@implementation ViewController {
    HHServicePublisher* publisher;
}


#pragma mark - Lifecycle

- (id) init {
    if( self = [super init] ) {
        NSUInteger serverPort = 12345;
        
        // Setup the service publisher - remember to update the type parameter with your actual service type
        publisher = [[HHServicePublisher alloc] initWithName:@"PublisherSample"
                                                        type:@"_myexampleservice._tcp." domain:@"local." txtData:nil port:serverPort];
        publisher.delegate = self;
    }
    return self;
}

- (void) loadView {
    UIView* rootView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    rootView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    UIButton* button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(40, 50, 240, 44);
    [button setTitle:@"Publish" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(beginPublish) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:button];
    
    button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(40, 100, 240, 44);
    [button setTitle:@"Unpublish" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(endPublish) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:button];
    
    self.view = rootView;
}


#pragma mark - Actions

- (void) beginPublish {
    [publisher beginPublish];
}

- (void) endPublish {
    [publisher endPublish];
}


#pragma mark - HHServicePublisherDelegate
    
- (void) serviceDidPublish:(HHServicePublisher*)servicePublisher {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Publish result" message:@"Publish successful!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

- (void) serviceDidNotPublish:(HHServicePublisher*)servicePublisher {
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Publish result" message:@"Publish failed!!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

@end
