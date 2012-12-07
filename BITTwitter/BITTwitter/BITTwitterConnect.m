//
//  BITTwitterConnect.m
//  BITTwitter
//
//  Created by Andi Putra on 10/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//

/* https://dev.twitter.com/docs/auth/oauth/faq. 
 
    How long does an access token last?
 
    We do not currently expire access tokens. 
    Your access token will be invalid if a user explicitly rejects your application from their settings or if a Twitter admin suspends your application. 
    If your application is suspended there will be a note on your application page saying that it has been suspended. 
 
*/

#import "BITTwitterConnect.h"
#import <CommonCrypto/CommonHMAC.h>
#import "NSData+Base64.h"
#import "BITTwitterViewController.h"
#import "BITTwitterConfig.h"

//***************************************************************//
// Constants

NSString * const OAUTH_REQUEST_TOKEN_URL = @"https://api.twitter.com/oauth/request_token";
NSString * const OAUTH_ACCESS_TOKEN_URL = @"https://api.twitter.com/oauth/access_token";
NSString * const OAUTH_AUTHORIZE_URL = @"https://api.twitter.com/oauth/authorize";

NSString * const TWEET_STATUS_JSON_URL = @"https://api.twitter.com/1/statuses/update.json";
NSString * const TWEET_STATUS_WITH_MEDIA_JSON_URL = @"https://upload.twitter.com/1/statuses/update_with_media.json";

NSString * const TIMELINE_JSON_URL = @"https://api.twitter.com/1/statuses/user_timeline.json";
NSString * const SEARCH_JSON_URL = @"http://search.twitter.com/search.json";    // For searching user mentions, etc.

//***************************************************************//
// Typedefs

typedef enum {
    BITTwitterRequestTypeRequestToken = 0,  // For requesting request token.
    BITTwitterRequestTypeAccessToken,       // For requesting access token.
    BITTwitterRequestTypeAuthenticated,     // For tweeting, etc. After access token is obtained.
    BITTwitterRequestTypePublic,            // For communicating with Twitter API without authentication.
} BITTwitterRequestType;

typedef void(^BITTwitterRequestDidFinishBlock)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error);
typedef void(^BITTwitterOAuthAuthenticationSuccessBlock)(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName);
typedef void(^BITTwitterOAuthAuthenticationFailureBlock)(BITTwitterConnect *twitterConnect, NSError *error);

//***************************************************************//
// Extensions

@implementation NSString(Encode)

- (NSString *)encodedString {
    NSString * encodedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                   (CFStringRef)self,
                                                                                   NULL,
                                                                                   (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                   kCFStringEncodingUTF8);
    return [encodedString autorelease];
}

@end

//***************************************************************//

@interface BITTwitterConnect(Private)
- (NSString *)baseString;
- (NSString *)signature;
- (NSString *)authorizationHeader;
- (void)resetNonce;
- (void)resetTimestamp;
- (void)resetRequestQuery;
- (BOOL)isAuthenticationRequest;
- (void)setRequestURL:(NSURL *)reqURL;
- (void)setURLResponse:(NSHTTPURLResponse *)response;
- (void)setResponseError:(NSError *)error;
- (NSString *)HTTPMethodFromTwitterRequestMethod:(BITTwitterRequestMethod)method;
- (NSDictionary *)parametersFromOAuthResponseData:(NSData *)data;
- (void)requestUserAuthorization;
- (void)requestOAuthAccessToken;
- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock requestType:(BITTwitterRequestType)type;
- (BOOL)isiOS5OrAbove;
- (TWRequestMethod)twRequestMethodForBITTwitterRequestMethod:(BITTwitterRequestMethod)method;
- (void)performRequestForiOS5AndAboveWithCompletionBlock:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock accounts:(NSArray *)accounts;
- (void)performLoginForiOS5OrAboveWithSuccesBlock:(void (^)(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName))success failureBlock:(void (^)(BITTwitterConnect *twitterConnect, NSError *error))failure afterLoginRequestCompletionBlock:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock;
@end

@implementation BITTwitterConnect {
    
    NSString                *_nonce;
    NSString                *_timestamp;
    NSString                *_oobPin;
    
    // Request variables
    BITTwitterRequestType   _requestType;
    NSString                *_requestQuery;
    
    // Response variables
    NSMutableData           *_responseData;
    NSHTTPURLResponse       *_urlResponse;
    NSString                *_twitterScreenName;
    NSInteger               _twitteruserID;
    
    BITTwitterRequestDidFinishBlock             _requestDidFinishBlock;
    BITTwitterOAuthAuthenticationSuccessBlock   _oauthAuthenticationSuccessBlock;
    BITTwitterOAuthAuthenticationFailureBlock   _oauthAuthenticationFailureBlock;
    
}

@synthesize delegate = _delegate;
@synthesize consumerKey = _consumerKey;
@synthesize consumerSecret = _consumerSecret;
@synthesize oauthToken = _oauthToken;
@synthesize oauthSecret = _oauthSecret;
@synthesize applicationURL = _applicationURL;
@synthesize request = _request;

#pragma mark - Initialization and Memory Management

- (void)safelyReleaseBlocks {
    if (_requestDidFinishBlock) {
        Block_release(_requestDidFinishBlock), _requestDidFinishBlock = nil;
    }
    if (_oauthAuthenticationSuccessBlock) {
        Block_release(_oauthAuthenticationSuccessBlock), _oauthAuthenticationSuccessBlock = nil;
    }
    if (_oauthAuthenticationFailureBlock) {
        Block_release(_oauthAuthenticationFailureBlock), _oauthAuthenticationFailureBlock = nil;
    }
}

- (void)dealloc {
    [self safelyReleaseBlocks];
    _delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_consumerKey release], _consumerKey = nil;
    [_consumerSecret release], _consumerSecret = nil;
    [_applicationURL release], _applicationURL = nil;
    [_oauthToken release], _oauthToken = nil;
    [_oauthSecret release], _oauthSecret = nil;
    [_oobPin release], _oobPin = nil;
    [_nonce release], _nonce = nil;
    [_timestamp release], _timestamp = nil;
    [_responseData release], _responseData = nil;
    [_urlResponse release], _urlResponse = nil;
    [_twitterScreenName release], _twitterScreenName = nil;
    [_request release], _request = nil;
    [_requestQuery release], _requestQuery = nil;
    [super dealloc];
}

- (id)initWithDelegate:(id)delegate consumerKey:(NSString *)conKey consumerSecret:(NSString *)conSec {
    if ((self = [super init])) {
        _consumerKey = [conKey retain];
        _consumerSecret = [conSec retain];
        _responseData = [[NSMutableData alloc] init];
        _delegate = delegate;
        _applicationURL = @"oob";   // Default oauth_callback value is out of bounds 
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleDidCancelLogin:) 
                                                     name:DID_CANCEL_TW_LOGIN_NOTIFICATION 
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleDidObtainOOBPin:) 
                                                     name:DID_OBTAINED_TW_OOB_PIN_NOTIFICATION 
                                                   object:nil];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_TOKEN]) {
            _oauthToken = [[[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_TOKEN] retain];
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_SECRET]) {
            _oauthSecret = [[[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_SECRET] retain];
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_SCREEN_NAME]) {
            _twitterScreenName = [[[NSUserDefaults standardUserDefaults] objectForKey:SAVED_SCREEN_NAME] retain];
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_USER_ID]) {
            _twitteruserID = [[[NSUserDefaults standardUserDefaults] objectForKey:SAVED_USER_ID] integerValue];
        }
        
    }
    return self;
}

- (id)initWithDelegate:(id)delegate {
    return [self initWithDelegate:delegate consumerKey:nil consumerSecret:nil];
}

- (id)init {
    return [self initWithDelegate:nil];
}

#pragma mark - Getter/Setter

- (NSString *)nonce
{
    if(!_nonce) {
        CFUUIDRef uuidRef = CFUUIDCreate(NULL);
        CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
        CFRelease(uuidRef);
        NSString *uuid = [(NSString *)uuidStringRef autorelease];
        uuid = [NSString stringWithFormat:@"%@-%.0lf", uuid, [[NSDate date] timeIntervalSince1970]];
        NSArray *uuidItems = [uuid componentsSeparatedByString:@"-"];
        _nonce = [[uuidItems componentsJoinedByString:@""] retain];
    }
        
    return _nonce;
}

- (NSString *)timestamp
{
    if (!_timestamp) {
        _timestamp = [[NSString alloc] initWithFormat:@"%d", (int)(((float)([[NSDate date] timeIntervalSince1970])) + .5)];
    }

    return _timestamp;
}

- (void)setURLResponse:(NSHTTPURLResponse *)response {
    if (_urlResponse) {
        [_urlResponse release], _urlResponse = nil;
    }
    _urlResponse = [response retain];
}

- (void)setOobPin:(NSString *)oobPin {
    if (_oobPin) {
        [_oobPin release], _oobPin = nil;
    }
    _oobPin = [oobPin retain];
    [self requestOAuthAccessToken];
}

- (void)setTwitterScreenName:(NSString *)screenName {
    if (_twitterScreenName) {
        [_twitterScreenName release], _twitterScreenName = nil;
    }
    _twitterScreenName = [screenName retain];
}

- (void)setRequestQuery:(NSString *)query {
    if (_requestQuery) {
        [_requestQuery release], _requestQuery = nil;
    }
    _requestQuery = [query retain];
}

- (void)setRequestDidFinishBlock:(BITTwitterRequestDidFinishBlock)aBlock {
    if (aBlock && aBlock != NULL) {
        if (_requestDidFinishBlock) {
            Block_release(_requestDidFinishBlock), _requestDidFinishBlock = nil;
        }
        _requestDidFinishBlock = Block_copy(aBlock);
    }
}

- (void)setOAuthAuthenticationSuccessBlock:(BITTwitterOAuthAuthenticationSuccessBlock)aBlock {
    if (aBlock && aBlock != NULL) {
        if (_oauthAuthenticationSuccessBlock) {
            Block_release(_oauthAuthenticationSuccessBlock), _oauthAuthenticationSuccessBlock = nil;
        }
        _oauthAuthenticationSuccessBlock = Block_copy(aBlock);
    }
}

- (void)setOAuthAuthenticationFailureBlock:(BITTwitterOAuthAuthenticationFailureBlock)aBlock {
    if (aBlock && aBlock != NULL) {
        if (_oauthAuthenticationFailureBlock) {
            Block_release(_oauthAuthenticationFailureBlock), _oauthAuthenticationFailureBlock = nil;
        }
        _oauthAuthenticationFailureBlock = Block_copy(aBlock);
    }
}

#pragma mark - Public Methods

- (BOOL)isAuthenticated {
    if ([self isiOS5OrAbove] && [ACAccount class]) {    // For iOS5 or above
        ACAccountStore *accountStore = [[[ACAccountStore alloc] init] autorelease];
        ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        if ([accountType accessGranted]) {
            return YES;
        }
    } else {    // For iOS below iOS5
        if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_TOKEN] && [[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_SECRET]) {
            return YES;
        }
    }
    return NO;
}

- (void)setRequestWithURL:(NSURL *)url parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)requestMethod {
    self.request = [BITTwitterRequest requestWithRequestURL:url parameters:params requestMethod:requestMethod];
}

- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock shouldAuthenticate:(BOOL)shouldAuthenticate {
    
    if ([self isiOS5OrAbove] && [ACAccount class]) {
        
        if (shouldAuthenticate) {
            
            if ([self isAuthenticated]) {
                
                ACAccountStore *accountStore = [[ACAccountStore alloc] init];
                ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
                NSArray *accounts = [accountStore accountsWithAccountType:accountType];
                [self performRequestForiOS5AndAboveWithCompletionBlock:completionBlock accounts:accounts];
                [accountStore release];
                
            } else {
                
                [self performLoginForiOS5OrAboveWithSuccesBlock:nil failureBlock:nil afterLoginRequestCompletionBlock:completionBlock];
                
            }
            
        } else {

            [self performRequestForiOS5AndAboveWithCompletionBlock:completionBlock accounts:nil];
            
        }
        
    } else {
        
        if ([self isAuthenticated]) {
            
            [self performRequestWithCompletionHandler:completionBlock requestType:BITTwitterRequestTypeAuthenticated];
            
        } else {
            // If we do not have to authenticate, perform public request.
            if (shouldAuthenticate) {
                BITTwitterRequest *requestAfterAuthentication = _request;
                // If it is requesting for request token, access token, or user authentication, just perform the request normally.
                // If it is not, authenticate first before performing request.
                if (![self isAuthenticationRequest]) {
                    [self authenticateWithOAuthWithSuccesBlock:^(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName) {
                        self.request = requestAfterAuthentication;
                        [self performRequestWithCompletionHandler:completionBlock requestType:BITTwitterRequestTypeAuthenticated];
                    }
                                                  failureBlock:^(BITTwitterConnect *twitterConnect, NSError *error) {
                                                      NSError *statusError = [NSError errorWithDomain:@"TwitterConnectErrorDomain:DidCancelLogin"
                                                                                                 code:USER_DID_CANCEL_LOGIN_ERROR_CODE
                                                                                             userInfo:nil];
                                                      completionBlock(nil, nil, statusError);
                                                  }];
                } else {
                    [self performRequestWithCompletionHandler:completionBlock requestType:BITTwitterRequestTypeAuthenticated];
                }
            } else {
                [self performRequestWithCompletionHandler:completionBlock requestType:BITTwitterRequestTypePublic];
            }
        }
    }
}

- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock {
    [self performRequestWithCompletionHandler:completionBlock shouldAuthenticate:YES];
}

- (void)authenticateWithOAuthWithSuccesBlock:(void (^)(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName))success failureBlock:(void (^)(BITTwitterConnect *twitterConnect, NSError *error))failure {
    
    // Access token is available. Don't re-authorize.
    if ([self isAuthenticated]) {
        if (success) {
            success(self, _twitteruserID, _twitterScreenName);
        }
        return;
    }
    
    if ([self isiOS5OrAbove] && [ACAccount class]) {
        
        [self performLoginForiOS5OrAboveWithSuccesBlock:success failureBlock:failure afterLoginRequestCompletionBlock:nil];
        
    } else {
        
        [self setRequestWithURL:[NSURL URLWithString:OAUTH_REQUEST_TOKEN_URL] parameters:nil requestMethod:BITTwitterRequestMethodPOST];
        [self performRequestWithCompletionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
            
            NSDictionary *parameters = [self parametersFromOAuthResponseData:responseData];
            
            // Set 'oauth_token_secret'
            if ([parameters objectForKey:@"oauth_token_secret"]) {
                if (_oauthSecret) {
                    [_oauthSecret release], _oauthSecret = nil;
                }
                _oauthSecret = [[parameters objectForKey:@"oauth_token_secret"] retain];
            }
            // Set 'oauth_token'
            if ([parameters objectForKey:@"oauth_token"]) {
                if (_oauthToken) {
                    [_oauthToken release], _oauthToken = nil;
                }
                _oauthToken = [[parameters objectForKey:@"oauth_token"] retain];
            }
            
            // Then ask user to authorize the app
            if (_requestType == BITTwitterRequestTypeRequestToken) {
                [self requestUserAuthorization];
            }
            
        } requestType:BITTwitterRequestTypeRequestToken];
        
        if (success) {
            [self setOAuthAuthenticationSuccessBlock:success];
        }
        if (failure) {
            [self setOAuthAuthenticationFailureBlock:failure];
        }
    }
    
}

- (void)tweetWithMessage:(NSString *)message completionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock {
    
    /* Example request with more parameters
        [NSDictionary dictionaryWithObjectsAndKeys:message, @"status", @"true", @"trim_user", @"true", @"include_entities", nil] 
     */
    [self setRequestWithURL:[NSURL URLWithString:TWEET_STATUS_JSON_URL] 
                 parameters:[NSDictionary dictionaryWithObjectsAndKeys:message, @"status", nil]   
              requestMethod:BITTwitterRequestMethodPOST];
    [self performRequestWithCompletionHandler:completionBlock];
    
}

- (void)tweetWithRequest:(BITTwitterRequest *)tweetRequest completionHandler:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))completionBlock {
    
    // Parameters is nil for update_with_media
    [self setRequestWithURL:[NSURL URLWithString:TWEET_STATUS_WITH_MEDIA_JSON_URL] 
                 parameters:nil 
              requestMethod:BITTwitterRequestMethodPOST];
    for (NSDictionary *data in tweetRequest.multipartDatas) {
        [self.request addMultiPartData:[data objectForKey:MULTIPART_DATA_OBJECT] 
                              withName:[data objectForKey:MULTIPART_DATA_NAME] 
                                  type:[data objectForKey:MULTIPART_DATA_TYPE]];
    }
    [self performRequestWithCompletionHandler:completionBlock];
    
}

- (void)getUserTimeline:(NSString *)screenName withCompletionHandler:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))completionBlock {
    
    /* Example request with more parameters
        [NSDictionary dictionaryWithObjectsAndKeys:screenName, @"screen_name", @"5", @"count", nil]
     */
    NSURL *requestURL = [NSURL URLWithString:TIMELINE_JSON_URL];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:screenName, @"screen_name", nil];
    
    [self setRequestWithURL:requestURL
                 parameters:params
              requestMethod:BITTwitterRequestMethodGET];
    [self performRequestWithCompletionHandler:completionBlock];
}

- (void)getUserMentions:(NSString *)screenName withCompletionHandler:(void (^)(NSData *, NSHTTPURLResponse *, NSError *))completionBlock {
    
    NSString *mention = [NSString stringWithFormat:@"@%@", screenName];
    NSURL *requestURL = [NSURL URLWithString:SEARCH_JSON_URL];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:mention, @"q", @"10", @"rpp", nil]; // q -> query, rpp -> results per page
    
    [self setRequestWithURL:requestURL
                 parameters:params
              requestMethod:BITTwitterRequestMethodGET];
    [self performRequestWithCompletionHandler:completionBlock];
}

- (void)resetAccessToken {
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_TOKEN]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SAVED_OAUTH_ACCESS_TOKEN];
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:SAVED_OAUTH_ACCESS_SECRET]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SAVED_OAUTH_ACCESS_SECRET];
    }
    
    if (_oauthToken) {
        [_oauthToken release], _oauthToken = nil;
    }
    if (_oauthSecret) {
        [_oauthSecret release], _oauthSecret = nil;
    }
    
}

#pragma mark - Notification Handlers

- (void)handleDidCancelLogin:(NSNotification *)notification {
    if (_oauthAuthenticationFailureBlock) {
        NSError * statusError = [NSError errorWithDomain:@"TwitterConnectErrorDomain:DidCancelLogin"
                                                    code:USER_DID_CANCEL_LOGIN_ERROR_CODE
                                                userInfo:nil];
        _oauthAuthenticationFailureBlock(self, statusError);
    }
}

- (void)handleDidObtainOOBPin:(NSNotification *)notification {
    NSString *oob = [notification object];
    [self setOobPin:oob];
}

#pragma mark - Private Methods

- (void)resetNonce {
    if (_nonce) {
        [_nonce release], _nonce = nil;
    }
}

- (void)resetTimestamp {
    if (_timestamp) {
        [_timestamp release], _timestamp = nil;
    }
}

- (void)resetRequestQuery {
    if (_requestQuery) {
        [_requestQuery release], _requestQuery = nil;
    }
}

- (BOOL)isAuthenticationRequest {
    if ([_request.requestURL.absoluteString isEqualToString:OAUTH_REQUEST_TOKEN_URL] || [_request.requestURL.absoluteString isEqualToString:OAUTH_ACCESS_TOKEN_URL] || [_request.requestURL.absoluteString isEqualToString:OAUTH_AUTHORIZE_URL]) {
        return YES;
    }
    return NO;
}

- (BOOL)isiOS5OrAbove {
    return ([[[UIDevice currentDevice] systemVersion] floatValue] >= 5.);
}

- (TWRequestMethod)twRequestMethodForBITTwitterRequestMethod:(BITTwitterRequestMethod)method
{
    TWRequestMethod requestMethod;
    switch (method) {
        case BITTwitterRequestMethodGET:
            requestMethod = TWRequestMethodGET;
            break;
        case BITTwitterRequestMethodPOST:
            requestMethod = TWRequestMethodPOST;
            break;
        case BITTwitterRequestMethodDELETE:
            requestMethod = TWRequestMethodDELETE;
            break;
        default:
            break;
    }
    return requestMethod;
}

- (void)performRequestForiOS5AndAboveWithCompletionBlock:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock accounts:(NSArray *)accounts
{
    NSURL *requestURL = [self.request requestURL];
    NSDictionary *params = [self.request parameters];
    TWRequestMethod requestMethod = [self twRequestMethodForBITTwitterRequestMethod:[self.request requestMethod]];
    
    // Create an instance of Twitter request
    TWRequest *request = [[TWRequest alloc] initWithURL:requestURL
                                             parameters:params
                                          requestMethod:requestMethod];
    // Add multipart datas, if available
    for (NSDictionary *data in [self.request multipartDatas]) {
        [request addMultiPartData:[data objectForKey:MULTIPART_DATA_OBJECT]
                         withName:[data objectForKey:MULTIPART_DATA_NAME]
                             type:[data objectForKey:MULTIPART_DATA_TYPE]];
    }
    // Add account, if available
    if (accounts && accounts.count > 0) {
        ACAccount *twitterAccount = [accounts lastObject];
        [request setAccount:twitterAccount];
    }
    // Perform request
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (completionBlock && completionBlock != NULL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(responseData, urlResponse, error);
            });
        }
    }];
    [request release];
}

- (void)performLoginForiOS5OrAboveWithSuccesBlock:(void (^)(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName))success failureBlock:(void (^)(BITTwitterConnect *twitterConnect, NSError *error))failure afterLoginRequestCompletionBlock:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock
{
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    if ([accountStore respondsToSelector:@selector(requestAccessToAccountsWithType:options:completion:)]) {
        [accountStore requestAccessToAccountsWithType:accountType
                                              options:nil
                                           completion:^(BOOL granted, NSError *error) {
                                               if (granted) {
                                                   NSArray *accounts = [accountStore accountsWithAccountType:accountType];
                                                   _twitterScreenName = [[accounts lastObject] username];
                                                   [[NSUserDefaults standardUserDefaults] setObject:_twitterScreenName forKey:SAVED_SCREEN_NAME];
                                                   
                                                   if (success && success != NULL) {
                                                       success(self, 0, _twitterScreenName);
                                                   }
                                                   if (completionBlock && completionBlock != NULL) {
                                                       [self performRequestForiOS5AndAboveWithCompletionBlock:completionBlock accounts:accounts];
                                                   }
                                                   
                                               } else {
                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                       if (error.code == 6) {
                                                           UIAlertView *noAccountAlert = [[UIAlertView alloc] initWithTitle:@"No Account"
                                                                                                                    message:@"You're not signed-in to your Twitter account on this phone. Please sign-in to your account from Settings."
                                                                                                                   delegate:nil
                                                                                                          cancelButtonTitle:@"OK"
                                                                                                          otherButtonTitles:nil];
                                                           [noAccountAlert show];
                                                           [noAccountAlert release];
                                                       }
                                                       if (failure && failure != NULL) {
                                                           failure(self, error);
                                                       }
                                                       if (completionBlock && completionBlock != NULL) {
                                                           completionBlock(nil, nil, error);
                                                       }
                                                       
                                                   });
                                               }
                                           }];
    } else {
        [accountStore requestAccessToAccountsWithType:accountType
                                withCompletionHandler:^(BOOL granted, NSError *error) {
                                    if (granted) {
                                        NSArray *accounts = [accountStore accountsWithAccountType:accountType];
                                        _twitterScreenName = [[accounts lastObject] username];
                                        [[NSUserDefaults standardUserDefaults] setObject:_twitterScreenName forKey:SAVED_SCREEN_NAME];
                                        
                                        if (success && success != NULL) {
                                            success(self, 0, _twitterScreenName);
                                        }
                                        if (completionBlock && completionBlock != NULL) {
                                            [self performRequestForiOS5AndAboveWithCompletionBlock:completionBlock accounts:accounts];
                                        }
                                        
                                    } else {
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            if (error.code == 6) {
                                                UIAlertView *noAccountAlert = [[UIAlertView alloc] initWithTitle:@"No Account"
                                                                                                         message:@"You're not signed-in to your Twitter account on this phone. Please sign-in to your account from Settings."
                                                                                                        delegate:nil
                                                                                               cancelButtonTitle:@"OK"
                                                                                               otherButtonTitles:nil];
                                                [noAccountAlert show];
                                                [noAccountAlert release];
                                            }
                                            if (failure && failure != NULL) {
                                                failure(self, error);
                                            }
                                            if (completionBlock && completionBlock != NULL) {
                                                completionBlock(nil, nil, error);
                                            }
                                        });
                                    }
                                }];
    }
    [accountStore release];
}

#pragma mark - Private Request Methods

/** Set the requestQuery variable with parameters from BITTwitterRequest instance. */
- (void)setRequestQueryWithParameters:(NSDictionary *)params {
    
    [self resetRequestQuery];
    NSMutableArray *twitterParams = [NSMutableArray array];
    for (NSString *key in params.allKeys) {
        NSString *twitterParam = [NSString stringWithFormat:@"%@=%@", key, [[params objectForKey:key] encodedString]];
        [twitterParams addObject:twitterParam];
    }
    if ([twitterParams count] > 0) {
        [self setRequestQuery:[twitterParams componentsJoinedByString:@"&"]];
    }
    
}

/** Obtains HTTP method string from the method type. */
- (NSString *)HTTPMethodFromTwitterRequestMethod:(BITTwitterRequestMethod)method {
    
    switch (method) {
        case BITTwitterRequestMethodGET:
            return @"GET";
            break;
        case BITTwitterRequestMethodPOST:
            return @"POST";
            break;
        case BITTwitterRequestMethodDELETE:
            return @"DELETE";
            break;
        default:
            break;
    }
    
}

/* For GET */
/** Revised request url for GET requests */
- (NSURL *)revisedRequestURLfromOriginalURL:(NSURL *)original {
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", original.absoluteString, _requestQuery];
    NSURL *revised = [NSURL URLWithString:urlString];

    return revised;
    
}

- (void)performRequestWithCompletionHandler:(void (^)(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error))completionBlock requestType:(BITTwitterRequestType)type {
    
    // Set request type, so we can generate the correct base string and authorization header.
    _requestType = type;
    // Reset timestamp to the current time and nonce.
    [self resetTimestamp];
    [self resetNonce];
    
    BITTwitterRequest *twitterRequest = self.request;
    
    [self setRequestQueryWithParameters:twitterRequest.parameters];
    
    // If GET Request
    // Update URL with parameters provided, if it's a GET request and there are parameters.
    NSURL *revisedRequestURL = twitterRequest.requestURL;
    if ((twitterRequest.requestMethod == BITTwitterRequestMethodGET) && twitterRequest.parameters) {
        revisedRequestURL = [self revisedRequestURLfromOriginalURL:twitterRequest.requestURL];
    }
    
    // Create the url request based on the 'request' property of self.
    NSMutableURLRequest* twitterURLRequest = [NSMutableURLRequest requestWithURL:revisedRequestURL];
    [twitterURLRequest setHTTPMethod:[self HTTPMethodFromTwitterRequestMethod:twitterRequest.requestMethod]];
    
    // If POST Request
    // Set request body.
    if ((twitterRequest.requestMethod == BITTwitterRequestMethodPOST) && twitterRequest.parameters) {
        [twitterURLRequest setHTTPBody:[_requestQuery dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // Set request header.
    if (_requestType != BITTwitterRequestTypePublic) {
        [twitterURLRequest addValue:[self authorizationHeader] forHTTPHeaderField:@"Authorization"];
    }
    
    // If MULTI-PART DATA
    // There's multipart data, needs to update header.
    if ((twitterRequest.requestMethod == BITTwitterRequestMethodPOST) && ([twitterRequest.multipartDatas count] > 0)) {
        // Just some random text that will never occur in the body. 
        NSString *boundary = @"bxbxopopkkkk----This_is_a_Boundary--------bxbxopopkkkk";
        // Set content-type to accept multipart/form-data
        [twitterURLRequest addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] 
                 forHTTPHeaderField:@"Content-Type"];
        
        // Set HTTP Body
        NSMutableData *postBody = [NSMutableData data];
        // Start boundary
        [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        for (NSDictionary *data in twitterRequest.multipartDatas) {
            
            if ([[data objectForKey:MULTIPART_DATA_NAME] isEqualToString:@"media[]"]) {
                
                // Random number between 0 to NSUIntegerMax
                // To randomize the image name
                NSInteger randomNumber = arc4random() % NSUIntegerMax;
                
//                [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%d.png\"\r\n", [data objectForKey:MULTIPART_DATA_NAME], randomNumber] dataUsingEncoding:NSUTF8StringEncoding]];
                // Limit the data type to jpg, jpeg or png
                NSString *dataType = [data objectForKey:MULTIPART_DATA_TYPE];
                if (![dataType isEqualToString:@"jpg"] || ![dataType isEqualToString:@"jpeg"] || ![dataType isEqualToString:@"png"]) {
                    dataType = @"png";
                }
                
                [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%d.%@\"\r\n", [data objectForKey:MULTIPART_DATA_NAME], randomNumber, dataType] dataUsingEncoding:NSUTF8StringEncoding]];
                [postBody appendData:[@"Content-Type: application/octet-stream\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                
            } else {
                
                [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", [data objectForKey:MULTIPART_DATA_NAME]] dataUsingEncoding:NSUTF8StringEncoding]];
                
            }
            
            [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]]; 
            [postBody appendData:[data objectForKey:MULTIPART_DATA_OBJECT]];
            
            // Treat the last object differently
            if ([data isEqualToDictionary:[twitterRequest.multipartDatas lastObject]]) {
                [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]]; 
            } else {
                [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
        }
        
        // End boundary
        [postBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [twitterURLRequest setHTTPBody:postBody];
        
    }

    // Reset response data.
    [_responseData setLength:0];
    // Start connection.
    [NSURLConnection connectionWithRequest:twitterURLRequest delegate:self];
    
    // Set completion block, if available.
    if (completionBlock) {
        [self setRequestDidFinishBlock:completionBlock];
    }
    
}

#pragma mark - Private OAuth Methods

/** Presents a view controller with a web view to ask for user authorization. */
/** Request URL: https://api.twitter.com/oauth/authorize */
- (void)requestUserAuthorization 
{
    NSString *authorizeURLString = [NSString stringWithFormat:@"%@?oauth_token=%@", OAUTH_AUTHORIZE_URL, self.oauthToken];
    NSURL *authorizeURL = [NSURL URLWithString:authorizeURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:authorizeURL];
    
    BITTwitterViewController *twController =  [[BITTwitterViewController alloc] initURLRequest:request];
    if ([_delegate respondsToSelector:@selector(presentModalViewController:animated:)]) {
        UIViewController *delegateController = (UIViewController *)_delegate;
        [delegateController presentModalViewController:twController animated:YES];
    }
    [twController release];
}

/** Send a request to twitter using the oob pin obtained to get an access token. */
/** Request URL: https://api.twitter.com/oauth/access_token */
- (void)requestOAuthAccessToken 
{
    [self setRequestWithURL:[NSURL URLWithString:OAUTH_ACCESS_TOKEN_URL] parameters:nil requestMethod:BITTwitterRequestMethodPOST];
    [self performRequestWithCompletionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        
        NSDictionary *parameters = [self parametersFromOAuthResponseData:responseData];
        
        // Set 'oauth_token_secret'
        if ([parameters objectForKey:@"oauth_token_secret"]) {
            if (_oauthSecret) {
                [_oauthSecret release], _oauthSecret = nil;
            }
            _oauthSecret = [[parameters objectForKey:@"oauth_token_secret"] retain];
            // Save oauth_token_secret
            [[NSUserDefaults standardUserDefaults] setObject:self.oauthSecret forKey:SAVED_OAUTH_ACCESS_SECRET];
        }
        // Set 'oauth_token'
        if ([parameters objectForKey:@"oauth_token"]) {
            if (_oauthToken) {
                [_oauthToken release], _oauthToken = nil;
            }
            _oauthToken = [[parameters objectForKey:@"oauth_token"] retain];
            // Save oauth_token
            [[NSUserDefaults standardUserDefaults] setObject:self.oauthToken forKey:SAVED_OAUTH_ACCESS_TOKEN];
        }
        // Set 'screen_name'
        if ([parameters objectForKey:@"screen_name"]) {
            [self setTwitterScreenName:[parameters objectForKey:@"screen_name"]];
            // Save screen_name
            [[NSUserDefaults standardUserDefaults] setObject:_twitterScreenName forKey:SAVED_SCREEN_NAME];
        }
        // Set 'user_id'
        if ([parameters objectForKey:@"user_id"]) {
            _twitteruserID = [[parameters objectForKey:@"user_id"] intValue];
            // Save user_id
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:_twitteruserID] forKey:SAVED_USER_ID];
        }
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (error) {
            if (_oauthAuthenticationFailureBlock) {
                _oauthAuthenticationFailureBlock(self, error);
            }
        } else {
            if (_oauthAuthenticationSuccessBlock) {
                _oauthAuthenticationSuccessBlock(self, _twitteruserID, _twitterScreenName);
            }
        }
        
    } requestType:BITTwitterRequestTypeAccessToken];
    
}

/** Process the oauth response data to obtain oauth_token and oauth_token_secret. */
- (NSDictionary *)parametersFromOAuthResponseData:(NSData *)data {
    
    NSString * response = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSArray * parameters = [response componentsSeparatedByString:@"&"];
    NSMutableDictionary * dictionary = [NSMutableDictionary dictionary];

    for (NSString * parameter in parameters) {
        NSArray * keyAndValue = [parameter componentsSeparatedByString:@"="];
        if (keyAndValue == nil || [keyAndValue count] != 2)
            continue;
        NSString * key = [keyAndValue objectAtIndex:0];
        NSString * value = [keyAndValue lastObject];
        [dictionary setObject:value forKey:key];
    }
    
    return (NSDictionary *)dictionary;
    
}

#pragma mark - Request Setup Methods

- (NSString *)baseString
{
    NSString *method = [self HTTPMethodFromTwitterRequestMethod:self.request.requestMethod];
    NSString *url = [[self.request.requestURL absoluteString] encodedString];
    
    NSString *parameters;
    // oauth_consumer_key
    NSString *oauthConsumerKey = [_consumerKey encodedString];
    // oauth_nonce
    NSString *oauthNonce = [[self nonce] encodedString];     
    // oauth_signature_method
    NSString *oauthSignatureMethod = [@"HMAC-SHA1" encodedString];
    // oauth_timestamp
    NSString *oauthTimestamp = [[self timestamp] encodedString];
    // oauth_version
    NSString *oauthVersion = [@"1.0" encodedString];
    // oauth_callback
    NSString *oauthApplicationURL = [_applicationURL encodedString];
    
    // Parameters that should always be included
    NSArray * params = [NSArray arrayWithObjects:
                        [NSString stringWithFormat:@"%@%%3D%@", @"oauth_consumer_key", oauthConsumerKey],
                        [NSString stringWithFormat:@"%@%%3D%@", @"oauth_nonce", oauthNonce],
                        [NSString stringWithFormat:@"%@%%3D%@", @"oauth_signature_method", oauthSignatureMethod],
                        [NSString stringWithFormat:@"%@%%3D%@", @"oauth_timestamp", oauthTimestamp],
                        [NSString stringWithFormat:@"%@%%3D%@", @"oauth_version", oauthVersion],
                        nil];
    
    // Optional parameters additions depending on the request type
    switch (_requestType) {
        case BITTwitterRequestTypeAccessToken: {
            // oauth_verifier
            NSString *oauthVerifier = [NSString stringWithFormat:@"%@%%3D%@", @"oauth_verifier", [_oobPin encodedString]];
            // oauth_token
            NSString *oauthToken = [NSString stringWithFormat:@"%@%%3D%@", @"oauth_token", [_oauthToken encodedString]];
            params = [params arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:oauthVerifier, oauthToken, nil]];
            break;
        }
        case BITTwitterRequestTypeRequestToken: {
            // oauth_callback
            params = [params arrayByAddingObject:[NSString stringWithFormat:@"%@%%3D%@", @"oauth_callback", oauthApplicationURL]];
            break;
        }
        case BITTwitterRequestTypeAuthenticated: {
            // oauth_token
            NSString *oauthToken = [NSString stringWithFormat:@"%@%%3D%@", @"oauth_token", [_oauthToken encodedString]];
            params = [params arrayByAddingObject:oauthToken];
            // request query
            if (_requestQuery) {
                NSMutableArray *temp = [NSMutableArray array];
                NSArray *queries = [_requestQuery componentsSeparatedByString:@"&"];
                for (NSString *query in queries) {
                    query = [NSString stringWithFormat:@"%@", [query encodedString]];
                    [temp addObject:query];
                }
                params = [params arrayByAddingObjectsFromArray:temp];
            }
            break;
        }
        default:
            break;
    }
    
    params = [params sortedArrayUsingSelector:@selector(compare:)];
    parameters = [params componentsJoinedByString:@"%26"];
    
    NSArray * baseComponents = [NSArray arrayWithObjects:method, url, parameters, nil];
    NSString * baseString = [baseComponents componentsJoinedByString:@"&"];
    return baseString;
}

/** Signature is a composite of both oauth_consumer_secret and oauth_token_secret (if it's available).  */
- (NSString *)signature
{
    NSString * secret = [NSString stringWithFormat:@"%@&", _consumerSecret];
    if (_oauthSecret) {
        secret = [NSString stringWithFormat:@"%@&%@", _consumerSecret, _oauthSecret];
    }
    NSData * secretData = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSData * baseData = [[self baseString] dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[20] = {0};
    CCHmac(kCCHmacAlgSHA1, secretData.bytes, secretData.length,
           baseData.bytes, baseData.length, digest);
    NSData * signatureData = [NSData dataWithBytes:digest length:20];
    return [signatureData base64EncodedString];
}

- (NSString *)authorizationHeader
{
    // Keys and values that should always be included
    NSArray * keysAndValues = [NSArray arrayWithObjects:
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_nonce", [[self nonce] encodedString]],
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_signature_method", [@"HMAC-SHA1" encodedString]],
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_timestamp", [[self timestamp] encodedString]],
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_consumer_key", [_consumerKey encodedString]],
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_signature", [[self signature] encodedString]],
                               [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_version", [@"1.0" encodedString]],
                               nil];
    
    // Optional keys and values additions depending on the request type
    switch (_requestType) {
        case BITTwitterRequestTypeAccessToken: {
            // oauth_verifier
            NSString *oauthVerifier = [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_verifier", [_oobPin encodedString]];
            // oauth_token
            NSString *oauthToken = [NSString stringWithFormat:@"%@=\"%@\"", @"oauth_token", [_oauthToken encodedString]];
            keysAndValues = [keysAndValues arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:oauthVerifier, oauthToken, nil]];
            break;
        }
        case BITTwitterRequestTypeRequestToken: {
            // oauth_callback
            keysAndValues = [keysAndValues arrayByAddingObject:[NSString stringWithFormat:@"%@=\"%@\"", @"oauth_callback", [_applicationURL encodedString]]];
            break;
        }
        case BITTwitterRequestTypeAuthenticated: {
            // oauth_token
            keysAndValues = [keysAndValues arrayByAddingObject:[NSString stringWithFormat:@"%@=\"%@\"", @"oauth_token", [_oauthToken encodedString]]];
            break;
        }
        default:
            break;
    }
    
    // Sort paramaters alphabetically
    keysAndValues = [keysAndValues sortedArrayUsingSelector:@selector(compare:)];
    
    NSString *authorizationString = [NSString stringWithFormat:@"OAuth %@", [keysAndValues componentsJoinedByString:@", "]];
    return authorizationString;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (_requestDidFinishBlock) {
        NSData *data = [[_responseData copy] autorelease];
        _requestDidFinishBlock(data, _urlResponse, error);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newData
{
    [_responseData appendData:newData];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response respondsToSelector:@selector(statusCode)]) {
        
        // Set URL response to be sent to the completion block.
        [self setURLResponse:(NSHTTPURLResponse *)response];
        int statusCode = [_urlResponse statusCode];
        
        // Status code >= 400 means it's an error.
        if (statusCode >= 400) {
            [connection cancel];
            NSDictionary * errorInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"Server returned status code %d",@""),
                                                                           statusCode]
                                                                   forKey:NSLocalizedDescriptionKey];
            NSError * statusError = [NSError errorWithDomain:@"HTTP Property Status Code" // NSHTTPPropertyStatusCodeKey
                                                        code:statusCode
                                                    userInfo:errorInfo];
            [self connection:connection didFailWithError:statusError];
        }
        
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_requestDidFinishBlock) {
        NSData *data = [[_responseData copy] autorelease];
        _requestDidFinishBlock(data, _urlResponse, nil);
    }
}


@end
