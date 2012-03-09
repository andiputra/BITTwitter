//
//  BITTwitterViewController.m
//  BITTwitter
//
//  Created by Andi Putra on 11/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//
// Parts of the code found in this file are copied directly from SA_OAuthTwitterController class in Twitter-OAuth-iPhone github project
// The original project, created by Ben Gottlieb, can be found here: https://github.com/bengottlieb/Twitter-OAuth-iPhone

#import "BITTwitterViewController.h"
#import "BITTwitterConfig.h"

@implementation NSString(TwitterOAuth)
- (BOOL)twitterOAuthIsNumeric {
	const char *raw = (const char *) [self UTF8String];
	
	for (int i = 0; i < strlen(raw); i++) {
		if (raw[i] < '0' || raw[i] > '9') return NO;
	}
    
	return YES;
}
@end

@interface BITTwitterViewController(Private)
- (NSString *)locateAuthPinInWebView:(UIWebView *)webView;
- (void)showWebViewWithCompletionCallback:(void(^)(BOOL finished))completionBlock;
- (void)showPinPromptBar;
- (void)hideLoadingIndicator;
- (void)showLoadingIndicator;
@end

@implementation BITTwitterViewController {
    
    UIWebView           *_webview;
    UINavigationBar     *_navbar;
    UIView              *_blockerView;
    UIImageView         *_backgroundView;
    // Shown when automatic pin retrieval failed.
    UIToolbar           *_pinPromptBar;     
    
    NSURLRequest        *_authorizeURLRequest;
    BOOL                _firstLoad;
    BOOL                _loading;
}

#pragma mark - Initialization and Memory Management

- (void)dealloc {
    [_webview release], _webview = nil;
    [_navbar release], _navbar = nil;
    [_blockerView release], _blockerView = nil;
    [_backgroundView release], _backgroundView = nil;
    [_pinPromptBar release], _pinPromptBar = nil;
    [_authorizeURLRequest release], _authorizeURLRequest = nil;
    [super dealloc];
}

- (id)initURLRequest:(NSURLRequest *)request {
    if ((self = [super init])) {
        _authorizeURLRequest = [request retain];
        _firstLoad = YES;
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)loadView {
    
    [super loadView];
    
    self.view.backgroundColor = [UIColor colorWithHue:194./360. saturation:62./100. brightness:97./100. alpha:1.];
    
    _navbar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0., 0., self.view.frame.size.width, 44.)];
    _navbar.barStyle = UIBarStyleBlack;
    
    UINavigationItem *navigationItem = [[[UINavigationItem alloc] initWithTitle:@"Twitter Info"] autorelease];
    [navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                       target:self 
                                                                                       action:@selector(cancel:)] autorelease]];
    _navbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_navbar pushNavigationItem:navigationItem animated:NO];
    
    _backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"twitter_load.png"]];
    _backgroundView.frame = CGRectMake(0., self.view.frame.size.height - _backgroundView.frame.size.height, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
    [self.view addSubview:_backgroundView];
    
    _webview = [[UIWebView alloc] initWithFrame:CGRectMake(0., _navbar.frame.size.height, self.view.frame.size.width, (self.view.frame.size.height - _navbar.frame.size.height))];
    _webview.delegate = self;
    _webview.alpha = 0.;
    _webview.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [_webview loadRequest:_authorizeURLRequest];
    
    [self.view addSubview:_webview];
    [self.view addSubview:_navbar];
    
    _blockerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 150., 60.)];
	_blockerView.backgroundColor = [UIColor colorWithWhite:0. alpha:.7];
	_blockerView.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    _blockerView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	_blockerView.alpha = 0.;
	_blockerView.clipsToBounds = YES;
	
	UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 5., _blockerView.bounds.size.width, 15.)] autorelease];
	label.text = @"Please Wait…";
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor whiteColor];
	label.textAlignment = UITextAlignmentCenter;
	label.font = [UIFont boldSystemFontOfSize:15];
	[_blockerView addSubview: label];
	
	UIActivityIndicatorView	*spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
	spinner.center = CGPointMake(_blockerView.bounds.size.width / 2, _blockerView.bounds.size.height / 2 + 10.);
	[_blockerView addSubview: spinner];
	[self.view addSubview: _blockerView];
	[spinner startAnimating];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(pasteboardChanged:) 
                                                 name:UIPasteboardChangedNotification 
                                               object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

#pragma mark - Actions

- (void)dismissTwitterViewControllerAfterDelay:(float)seconds {
    double delayInSeconds = seconds;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self dismissModalViewControllerAnimated:YES];
    });
}

- (void)denied {
    [self dismissTwitterViewControllerAfterDelay:1.];
}

- (void)obtainedPin:(NSString *)pin {
    [[NSNotificationCenter defaultCenter] postNotificationName:DID_OBTAINED_TW_OOB_PIN_NOTIFICATION object:pin];
//    _twitterConnect.oobPin = pin;
    [self dismissTwitterViewControllerAfterDelay:1.];
}

- (void)cancel:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:DID_CANCEL_TW_LOGIN_NOTIFICATION object:nil];
    [self dismissTwitterViewControllerAfterDelay:0.];
//    [_twitterConnect didCancelLogin];
}

//=============================================================================================================================
#pragma mark Notifications

- (void) pasteboardChanged: (NSNotification *) note {
	UIPasteboard					*pb = [UIPasteboard generalPasteboard];
	
	if ([note.userInfo objectForKey: UIPasteboardChangedTypesAddedKey] == nil) return;		//no meaningful change
	
	NSString						*copied = pb.string;
	
	if (copied.length != 7 || !copied.twitterOAuthIsNumeric) return;
	
	[self obtainedPin: copied];
}


//=============================================================================================================================
#pragma mark - UIWebviewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {

    _loading = NO;
    if (_firstLoad) {
        
        [self showWebViewWithCompletionCallback:^(BOOL finished){
            [webView performSelector: @selector(stringByEvaluatingJavaScriptFromString:) withObject: @"window.scrollBy(0,200)" afterDelay: 0];
            _firstLoad = NO;
        }];
        
    } else {
        
        // Try to automatically retrieve the pin using Javascript injection
        NSString *authPin = [self locateAuthPinInWebView:webView];
        if (authPin.length) {
            [self obtainedPin:authPin];
            return;
        }
        
        // If it fails, ask the user to do it manually
        NSString *formCount = [webView stringByEvaluatingJavaScriptFromString: @"document.forms.length"];
        if ([formCount isEqualToString: @"0"]) {
            [self showPinPromptBar];
        }
    }
    
    [self hideLoadingIndicator];
	
	if ([_webview isLoading]) {
		_webview.alpha = 0.0;
	} else {
		_webview.alpha = 1.0;
	}
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
	_loading = YES;
    [self showLoadingIndicator];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
	NSData *data = [request HTTPBody];
	char *raw = data ? (char *) [data bytes] : "";
	
	if (raw && strstr(raw, "cancel=")) {
		[self denied];
		return NO;
	}
    
	return YES;
    
}

#pragma mark - Private Methods

- (void)showWebViewWithCompletionCallback:(void(^)(BOOL finished))completionBlock {
    [UIView animateWithDuration:.5 
                     animations:^{[_webview setAlpha:1.];} 
                     completion:completionBlock];
}

- (void)hideLoadingIndicator {
    [UIView animateWithDuration:.3 
                     animations:^{[_blockerView setAlpha:0.];} 
                     completion:NULL];
}

- (void)showLoadingIndicator {
    [UIView animateWithDuration:.3 
                     animations:^{[_blockerView setAlpha:1.];} 
                     completion:NULL];
}

- (UIToolbar *)pinPromptBar {
    
	if (!_pinPromptBar){
        
		CGRect bounds = self.view.bounds;
		
		_pinPromptBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, _navbar.frame.size.height, bounds.size.width, _navbar.frame.size.height)];
		_pinPromptBar.barStyle = UIBarStyleBlackTranslucent;
        
		_pinPromptBar.items = [NSArray arrayWithObjects: 
                                   [[[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace target: nil action: nil] autorelease],
                                   [[[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"Select and Copy the PIN", @"Select and Copy the PIN") style: UIBarButtonItemStylePlain target: nil action: nil] autorelease], 
                                   [[[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace target: nil action: nil] autorelease], 
                                   nil];
	}
	
	return _pinPromptBar;
}


- (void)showPinPromptBar {
    
	if ([self pinPromptBar].superview) {
        return;		//already shown
    }
        
	[self pinPromptBar].center = CGPointMake(_pinPromptBar.bounds.size.width / 2, _pinPromptBar.bounds.size.height / 2);
	[self.view insertSubview:[self pinPromptBar] belowSubview:_navbar];
    
    [UIView animateWithDuration:.5 
                     animations:^{
                         [_pinPromptBar setCenter:CGPointMake(_pinPromptBar.bounds.size.width / 2, _navbar.bounds.size.height + _pinPromptBar.bounds.size.height / 2)];
                     }];

}

/*********************************************************************************************************
 
 I am fully aware that this code is chock full 'o flunk. That said:
 
 - first we check, using standard DOM-diving, for the pin, looking at both the old and new tags for it.
 - if not found, we try a regex for it. This did not work for me (though it did work in test web pages).
 - if STILL not found, we iterate the entire HTML and look for an all-numeric 'word', 7 characters in length
 
 Ugly. I apologize for its inelegance. Bleah.
 
 *********************************************************************************************************/

- (NSString *)locateAuthPinInWebView:(UIWebView *)webView {
	// Look for either 'oauth-pin' or 'oauth_pin' in the raw HTML
	NSString *js = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); if (d) d = d.innerHTML; d;";
	NSString *pin = [[webView stringByEvaluatingJavaScriptFromString: js] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if (pin.length == 7) {
		return pin;
	} else {
		// New version of Twitter PIN page
		js = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); " \
		"if (d) { var d2 = d.getElementsByTagName('code'); if (d2.length > 0) d2[0].innerHTML; }";
		pin = [[webView stringByEvaluatingJavaScriptFromString: js] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if (pin.length == 7) {
			return pin;
		}
	}
	
	return nil;
}



@end









