//
//  ViewController.h
//  BrowserSample
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import <UIKit/UIKit.h>

#import "HHServiceBrowser.h"

@interface ViewController : UIViewController<HHServiceBrowserDelegate, HHServiceDelegate, UITableViewDataSource, UITableViewDelegate>

@end
