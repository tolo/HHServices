//
//  ViewController.h
//  BrowserSample
//
//  Created by Tobias Löfstrand on 2013-09-21.
//  Copyright (c) 2013 Leafnode AB. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HHServiceBrowser.h"

@interface ViewController : UIViewController<HHServiceBrowserDelegate, HHServiceDelegate, UITableViewDataSource, UITableViewDelegate>

@end
