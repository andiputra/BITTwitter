//
//  ExampleViewController.m
//  BITTwitter
//
//  Created by Andi Putra on 23/02/12.
//  Copyright (c) 2012 Andi Putra. All rights reserved.
//

#import "ExampleViewController.h"

@implementation ExampleViewController
@synthesize twConnect = _twConnect;
@synthesize twitterResponseTextView = _twitterResponseTextView;
@synthesize loadingIndicator = _loadingIndicator;

- (void)dealloc {
    [_twConnect release], _twConnect = nil;
    [_twitterResponseTextView release], _twitterResponseTextView = nil;
    [_loadingIndicator release], _loadingIndicator = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_loadingIndicator setHidden:YES];
    [_loadingIndicator setHidesWhenStopped:YES];
    // Initialize an instance of BITTwitterConnect class
    if (!_twConnect) {
        _twConnect = [[BITTwitterConnect alloc] initWithDelegate:self 
                                                     consumerKey:BITTWITTER_CONSUMER_KEY 
                                                  consumerSecret:BITTWITTER_CONSUMER_SECRET];
    }
    // Perform login, right after view is loaded
    [self performSelector:@selector(login)];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.twitterResponseTextView = nil;
    self.loadingIndicator = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark - Helper Methods

- (void)showLoadingIndicator {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [_loadingIndicator setHidden:NO];
    [_loadingIndicator startAnimating];
    for (UIView *subview in self.view.subviews) {
        [subview setUserInteractionEnabled:NO];
    }
}

- (void)hideLoadingIndicator {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [_loadingIndicator stopAnimating];
    for (UIView *subview in self.view.subviews) {
        [subview setUserInteractionEnabled:YES];
    }
}

#pragma mark - Private Methods

- (void)login {
    
    // Authenticate method will present the login screen to the user.
    // If the user login is successful, success block will be called.
    // If it fails, failure block will be called.
    [_twConnect authenticateWithOAuthWithSuccesBlock:^(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName) {
        NSLog(@"Login successful. \n Twitter user name: %@ \n Twitter user id: %d", twitterScreenName, twitterID);
    } failureBlock:^(BITTwitterConnect *twitterConnect, NSError *error) {
        NSLog(@"Login failed. \n Error: %@", error);
    }];
    
}

- (void)tweet {
    
    [self showLoadingIndicator];
    // Tweet with message containing random numbers, since you can't send the same message consecutively.
    // If there's no error returned by the completion handler, our request is successful.
    [_twConnect tweetWithMessage:[NSString stringWithFormat:@"Test tweet number %d", (arc4random()%NSUIntegerMax)] 
               completionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                   if (!error) {
                       NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Success:\n%@", response];
                   } else {
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Error:\n%@", error];
                   }
                   [self hideLoadingIndicator];
               }];
    
}

- (void)tweetImage {
    
    [self showLoadingIndicator];
    // Tweet with message containing random numbers, since you can't send the same message consecutively.
    NSData *messageData = [[NSString stringWithFormat:@"Test tweet number %d", arc4random()%NSUIntegerMax] dataUsingEncoding:NSUTF8StringEncoding];
    // Convert the image into data.
    NSData *imageData = UIImagePNGRepresentation([UIImage imageNamed:@"kong.jpeg"]);
    
    // Initialize BITTwitterRequest instance to build our request.
    BITTwitterRequest *request = [[BITTwitterRequest alloc] initWithRequestURL:nil 
                                                                    parameters:nil 
                                                                 requestMethod:BITTwitterRequestMethodPOST];
    
    // Check: https://dev.twitter.com/docs/api/1/post/statuses/update_with_media for documentation.
    [request addMultiPartData:messageData withName:@"status" type:@"text"];
    [request addMultiPartData:imageData withName:@"media[]" type:@"jpg"];
    
    // If there's no error returned by the completion handler, our request is successful.
    [_twConnect tweetWithRequest:request 
               completionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
                   if (!error) {
                       NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Success:\n%@", response];;
                   } else {
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Error:\n%@", error];
                   }
                   [self hideLoadingIndicator];
               }];
    
}

- (void)getUserTimeline {
    
    [self showLoadingIndicator];
    // This is an example of creating your own custom request using BITTwitterConnect.
    // There is actually a convenient method called 'getUserTimeline:withCompletionHandler:' provided which works the same way as this.
    // But, the convenient method does not allow you to customize the parameters and ignore the user authentication.
    
    // For full list of possible parameters, https://dev.twitter.com/docs/api/1/get/statuses/user_timeline
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:@"andiputra7", @"screen_name", @"20", @"count", nil];
    // You have the choice of setting the request with the method below.
    // Or, create an instance of BITTwitterRequest class then set it as the request for your BITTwitterConnect instance.
    [_twConnect setRequestWithURL:[NSURL URLWithString:@"https://api.twitter.com/1/statuses/user_timeline.json"] 
                            parameters:params 
                         requestMethod:BITTwitterRequestMethodGET];
    
    // This method is used by all convenient methods (like tweetWithMessage:, etc) I have provided.
    [_twConnect performRequestWithCompletionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (!error) {
            NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
            _twitterResponseTextView.text = [NSString stringWithFormat:@"Success:\n%@", response];;
        } else {
            _twitterResponseTextView.text = [NSString stringWithFormat:@"Error:\n%@", error];
        }
        [self hideLoadingIndicator];
    } shouldAuthenticate:NO];
    
}

- (void)getUserMentions {
    
    [self showLoadingIndicator];
    // This method is using the twitter search api.
    // In this case, it searches for '@andiputra7' keyword.
    [_twConnect getUserMentions:@"andiputra7" 
               withCompletionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
                   if (!error) {
                       NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Success:\n%@", response];;
                   } else {
                       _twitterResponseTextView.text = [NSString stringWithFormat:@"Error:\n%@", error];
                   }
                   [self hideLoadingIndicator];
               }];
    
}

#pragma mark - Public Methods

- (IBAction)didTapTweetButton:(id)sender {
    [self tweet];
}

- (IBAction)didTapTweetImageButton:(id)sender {
    [self tweetImage];
}

- (IBAction)didTapTimelineButton:(id)sender {
    [self getUserTimeline];
}

- (IBAction)didTapMentionsButton:(id)sender {
    [self getUserMentions];
}

@end
