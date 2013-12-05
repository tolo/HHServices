//
//  ViewController.m
//  BrowserSample
//
//  Created by Tobias Löfstrand on 2013-09-21.
//  Copyright (c) 2013 Leafnode AB. All rights reserved.
//

#import "ViewController.h"

#import <QuartzCore/QuartzCore.h>

@interface ViewController ()

@end

@implementation ViewController {
    HHServiceBrowser* browser;
    NSMutableArray* browseResult;
    HHService* resolvingService;
    
    UITableView* tableView;
}


#pragma mark - Lifecycle

- (id)init {
    if (self = [super init]) {
        // Browse for services - make sure you set the type parameter to your service type
        browser = [[HHServiceBrowser alloc] initWithType:@"_myexampleservice._tcp." domain:@"local."];
        browser.delegate = self;
        
        browseResult = [[NSMutableArray alloc] init];
    }
    return self;
}


- (void) loadView {
    UIView* rootView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    rootView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    tableView = [[UITableView alloc] initWithFrame:CGRectMake(20, 40, 280, 200) style:UITableViewStylePlain];
    tableView.layer.cornerRadius = 4;
    tableView.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:1].CGColor;
    tableView.layer.borderWidth = 1;
    tableView.delegate = self;
    tableView.dataSource = self;
    [rootView addSubview:tableView];

    UIButton* button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    button.frame = CGRectMake(40,  250, 240, 44);
    [button setTitle:@"Resolve selected" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(resolve) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:button];
    
    self.view = rootView;
    
    [browser beginBrowse];
}


#pragma mark - Actions

- (void) resolve {
    NSIndexPath* selectedRow = tableView.indexPathForSelectedRow;
    if( !resolvingService && (selectedRow.row + 1) <= browseResult.count ) {
        resolvingService = browseResult[selectedRow.row];
        resolvingService.delegate = self;
        [resolvingService beginResolve];
    } else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:nil message:@"Select a service" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
}


#pragma mark - HHServiceBrowserDelegate & HHServiceDelegate

- (void) serviceDidResolve:(HHService*)service {
    service.delegate = nil;
    [service endResolve];
    resolvingService = nil;
    
    NSString* message = [NSString stringWithFormat:@"Service did resolve: %@", service];
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Resolve result" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

- (void) serviceDidNotResolve:(HHService*)service {
    service.delegate = nil;
    [service endResolve];
    resolvingService = nil;
    
    NSString* message = [NSString stringWithFormat:@"Service did NOT resolve: %@", service];
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Resolve result" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didFindService:(HHService*)service moreComing:(BOOL)moreComing {
    if( ![browseResult containsObject:service] ) {
        [browseResult addObject:service];
        [tableView reloadData];
    }
}

- (void) serviceBrowser:(HHServiceBrowser*)serviceBrowser didRemoveService:(HHService*)service moreComing:(BOOL)moreComing {
    [browseResult removeObject:service];
    [tableView reloadData];
}


#pragma mark - UITableView

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return browseResult.count;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    HHService* service = browseResult[indexPath.row];
    cell.textLabel.text = service.name;
    return cell;
}

@end
