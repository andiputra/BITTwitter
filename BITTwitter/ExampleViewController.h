//
//  ExampleViewController.h
//  BITTwitter
//
//  Created by Andi Putra on 23/02/12.
//  Copyright (c) 2012 Andi Putra. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BITTwitter/BITTwitterConnect.h"

/*
 * REPLACE WITH YOUR OWN!!!
 */
#define BITTWITTER_CONSUMER_KEY     @"XOf8nDh6vZjFAg0Ud8Pw4g"
#define BITTWITTER_CONSUMER_SECRET  @"Jm5qm7Uzyw2hcm5VOJk2AAfVTCjJw34JzSB2oVBc"

@interface ExampleViewController : UIViewController

/* Properties */
@property (strong, nonatomic) BITTwitterConnect *twConnect;
@property (strong, nonatomic) IBOutlet UITextView *twitterResponseTextView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;

/* Public Methods */
- (IBAction)didTapTweetButton:(id)sender;
- (IBAction)didTapTweetImageButton:(id)sender;
- (IBAction)didTapTimelineButton:(id)sender;
- (IBAction)didTapMentionsButton:(id)sender;

@end
