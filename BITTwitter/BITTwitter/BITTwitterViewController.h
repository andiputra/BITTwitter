//
//  BITTwitterViewController.h
//  BITTwitter
//
//  Created by Andi Putra on 11/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//

#import <Foundation/Foundation.h>

/** BITTwitterViewController is a view controller with a web view for user to login and authenticate the application. 
*/
@interface BITTwitterViewController : UIViewController <UIWebViewDelegate>

/** Initialize with a url request. It is recommended to use this initialization method, rather than the default init.

    @param request 
    The url request that will be loaded by the web view.
 
*/
- (id)initURLRequest:(NSURLRequest *)request;

@end
