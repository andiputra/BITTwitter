//
//  BITTwitterConnect.h
//  BITTwitter
//
//  Created by Andi Putra on 10/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BITTwitterRequest.h"

#if defined(__IPHONE_5_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_5_0
#import <Twitter/Twitter.h>
#import <Accounts/Accounts.h>
#endif

// BITTwitter Error Codes
// Called when the user press the 'Cancel' button when presented with the login screen.
#define USER_DID_CANCEL_LOGIN_ERROR_CODE        999

@class BITTwitterConnect;

/*! BITTwitterConnect is responsible for all interactions with the Twitter REST API. 
    @warning *NOTE:* Minor leak (< 1kb) when user login. To be fixed.
*/
@interface BITTwitterConnect : NSObject <NSURLConnectionDelegate>

/** @name Properties */

/** Required. Set your view controller as the delegate. This property is only used to present the login screen.
*/
@property (unsafe_unretained, nonatomic) id delegate;

/** Required. Check your Twitter application page to obtain the value for this property. 
*/
@property (strong, nonatomic) NSString *consumerKey;

/** Required. Check you Twitter application page to obtain the value for this property. 
*/
@property (strong, nonatomic) NSString *consumerSecret;

/** Default is oob - out of bounds which works really well. But, if you want to have your own custom callback url, you'll need to change this. As of this writing (23/11/2011), changing this value won't have any effect.
*/
@property (strong, nonatomic) NSString *applicationURL;

/** The request instance of data you are sending to Twitter.
*/
@property (strong, nonatomic) BITTwitterRequest *request;

/** Read-only. The value of this is the same as access token, if it is obtained. 
*/
@property (strong, nonatomic, readonly) NSString *oauthToken;   

/** Read-only. The Twitter 'oauth_token_secret'. 
*/
@property (strong, nonatomic, readonly) NSString *oauthSecret;   

/** @name Public Methods */

/** If you use this method to initialize, you'll need to set consumer key and secret afterwards. 
 
    @param delegate 
    The twitter connect instance delegate.
 
*/
- (id)initWithDelegate:(id)delegate;

/** This is the recommended initialization method. 
 
    @param delegate 
    The twitter connect instance delegate.
 
    @param conKey 
    Your Twitter application consumer key. Check you Twitter application page to obtain the value for this property. 
    
    @param conSec 
    Your Twitter application consumer secret. Check you Twitter application page to obtain the value for this property. 
 
*/
- (id)initWithDelegate:(id)delegate consumerKey:(NSString *)conKey consumerSecret:(NSString *)conSec;

/** Set the request parameters you would like to send to Twitter. This method modifies the request property of this class. 
 
    @param url 
    Twitter request url. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible urls.
 
    @param params 
    Twitter request parameters. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible parameters.
    
    @param requestMethod 
    Twitter request HTTP Method, either GET or POST. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) to get the correct method.
 
*/
- (void)setRequestWithURL:(NSURL *)url parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)requestMethod;

/** Perform the request you've set up using 'setRequestWithURL:parameters:requestMethod:' method. Should authenticate is YES.
    
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
 
*/
- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;

/** Perform the request you've set up using 'setRequestWithURL:parameters:requestMethod:' method. 
 
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
 
    @param shouldAuthenticate 
    Whether or not we should perform an authenticated request. If this value is YES, user will be asked to sign in, if they have not authenticate the application. Some requests can only be performed when user have authenticated, so be sure to check Twitter API first ( https://dev.twitter.com/docs/api ).
 
*/
- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock shouldAuthenticate:(BOOL)shouldAuthenticate;

/** Remove the saved access token and prompt user to re-authorize. 
*/
- (void)resetAccessToken;

/** Check if the application is already authenticated with Twitter. 
*/
- (BOOL)isAuthenticated;

//*********************************************************************************************************//
/** @name Convenient Methods */
/* These methods can actually be implemented using a combination of 'setRequestWithURL:parameters:requestMethod:' and 'performRequestWithCompletionHandler:' methods. 
*/

/** Authorize application with OAuth to get the benefits of a registered Twitter application.
    
    @param success 
    The callback block that will be called if the request is completed successfully.
 
    @param failure 
    The callback block that will be called if the request failed to complete successfully.
 
*/
- (void)authenticateWithOAuthWithSuccesBlock:(void (^)(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName))success 
                                failureBlock:(void (^)(BITTwitterConnect *twitterConnect, NSError *error))failure;

/// Please authenticate your application first before using any of these methods. ///

/** Tweet with just a message. Use 'tweetWithRequest:completionHandler:' if you want to add media. 
    
    @param message 
    The tweet message.
    
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
    
*/
- (void)tweetWithMessage:(NSString *)message completionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;

/** Tweet with a message and a media. Use this to tweet your image. 
 
    @param tweetRequest 
    The request to be sent to Twitter.
 
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
 
*/
- (void)tweetWithRequest:(BITTwitterRequest *)tweetRequest completionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;

/** Returns 20 most recent statuses posted by the user, whose screen name you put in as argument. 
 
    @param screenName 
    Twitter user name to be used.
    
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
    
*/
- (void)getUserTimeline:(NSString *)screenName withCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;

/** Returns most recent mentions posted by the user, whose screen name you put in as argument. 
 
    @param screenName 
    Twitter user name to be used.
 
    @param completionBlock 
    The block that will be called once the request is completed, either successfully or not.
    
*/
- (void)getUserMentions:(NSString *)screenName withCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;

//*********************************************************************************************************//

@end
