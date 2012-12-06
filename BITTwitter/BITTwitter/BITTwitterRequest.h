//
//  BITTwitterRequest.h
//  BITTwitter
//
//  Created by Andi Putra on 10/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    BITTwitterRequestMethodGET = 0,
    BITTwitterRequestMethodPOST,
    BITTwitterRequestMethodDELETE,
} BITTwitterRequestMethod;

/** BITTwitterRequest generates request instance to be utilized by the BITTwitterConnect. 
*/
@interface BITTwitterRequest : NSObject

///////// PROPERTIES ///////////

/** Twitter request url. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible urls.
*/
@property (strong, nonatomic) NSURL *requestURL;

/** Twitter request parameters. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible parameters.
*/
@property (strong, nonatomic) NSDictionary *parameters;

/** Twitter HTTP Method, either GET or POST. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) to get the correct method.
*/
@property (unsafe_unretained, nonatomic) BITTwitterRequestMethod requestMethod;

///////// METHODS ///////////

/** Initialize with URL, parameters, and request method. 
    
    @param reqURL 
    Twitter request url. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible urls.
 
    @param params 
    Twitter request parameters. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible parameters.
 
    @param reqMethod 
    Twitter request HTTP Method, either GET or POST. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) to get the correct method.
 
*/
- (id)initWithRequestURL:(NSURL *)reqURL parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)reqMethod;

/** Returns an autorelease instance of BITTwitterRequest. 
 
    @param reqURL 
    Twitter request url. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible urls.
 
    @param params 
    Twitter request parameters. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) for full list of possible parameters.
 
    @param reqMethod 
    Twitter request HTTP Method, either GET or POST. Check the Twitter API documentation ( https://dev.twitter.com/docs/api ) to get the correct method.
 
*/
+ (BITTwitterRequest *)requestWithRequestURL:(NSURL *)reqURL parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)reqMethod;


/** Specify a named MIME multi-part value. Encoded using NSUTF8Encoding. 
 
    @param data 
    The data object you would like to insert.
    
    @param name 
    The key for the data. Check Twitter API documentation for 'updateWithMedia' ( https://dev.twitter.com/docs/api/1/post/statuses/update_with_media ) for possible values. Example values are 'status' and 'media[]'.
 
    @param type 
    The data type. If it is an image, it could be jpg or png.

*/
- (void)addMultiPartData:(NSData *)data withName:(NSString *)name type:(NSString *)type; 

/** A list of multipart datas dictionary you've inserted using 'addMultiPartData:withName:type:' method.
*/
- (NSArray *)multipartDatas;

@end
