//
//  BITTwitterRequest.m
//  BITTwitter
//
//  Created by Andi Putra on 10/11/11.
//  Copyright (c) 2011 Andi Putra. All rights reserved.
//

#import "BITTwitterRequest.h"
#import "BITTwitterConfig.h"

@implementation BITTwitterRequest {
    NSMutableArray      *_multipartDatas;
}

@synthesize requestURL = _requestURL;
@synthesize parameters = _parameters;
@synthesize requestMethod = _requestMethod;

#pragma mark - Initialization and Memory Management

- (void)dealloc {
    [_requestURL release], _requestURL = nil;
    [_parameters release], _parameters = nil;
    [_multipartDatas release], _multipartDatas = nil;
    [super dealloc];
}

+ (BITTwitterRequest *)requestWithRequestURL:(NSURL *)reqURL parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)reqMethod {
    return [[[BITTwitterRequest alloc] initWithRequestURL:reqURL parameters:params requestMethod:reqMethod] autorelease];
}

- (id)initWithRequestURL:(NSURL *)reqURL parameters:(NSDictionary *)params requestMethod:(BITTwitterRequestMethod)reqMethod {
    if ((self = [super init])) {
        _requestURL = [reqURL retain];
        _parameters = [params retain];
        _requestMethod = reqMethod;
        _multipartDatas = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)init {
    return [self initWithRequestURL:nil parameters:nil requestMethod:BITTwitterRequestMethodGET];
}

#pragma mark - Public Methods

- (void)addMultiPartData:(NSData *)data withName:(NSString *)name type:(NSString *)type {
    
    NSDictionary *dataDictionary = [NSDictionary dictionaryWithObjectsAndKeys:data, MULTIPART_DATA_OBJECT, name, MULTIPART_DATA_NAME, type, MULTIPART_DATA_TYPE, nil];
    [_multipartDatas addObject:dataDictionary];
    
}

- (NSArray *)multipartDatas {
    return (NSArray *)_multipartDatas;
}

@end
