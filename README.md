BITTwitter is a lightweight, delightful, and simple to use Twitter client for iOS. It is an updated and improved version of my previous BSTwitter project.

## Getting Started

1. Open the project in XCode.
2. You can browse the ExampleViewController for example codes on how to use the library.
3. Or, just drag and drop BITTwitter folder into your project. Then, import "BITTwitterConnect.h" into the class that needs it. And start using it.

## Code Preview

### User Login/Authentication

``` objective-c

// Initialize an instance of BITTwitterConnect class
if (!_twConnect) {
    _twConnect = [[BITTwitterConnect alloc] initWithDelegate:self 
                                                 consumerKey:BITTWITTER_CONSUMER_KEY 
                                              consumerSecret:BITTWITTER_CONSUMER_SECRET];
}

// Authenticate method will present the login screen to the user.
// If the user login is successful, success block will be called.
// If it fails, failure block will be called.
[_twConnect authenticateWithOAuthWithSuccesBlock:^(BITTwitterConnect *twitterConnect, NSInteger twitterID, NSString *twitterScreenName) {
    NSLog(@"Login successful. \n Twitter user name: %@ \n Twitter user id: %d", twitterScreenName, twitterID);
} failureBlock:^(BITTwitterConnect *twitterConnect, NSError *error) {
    NSLog(@"Login failed. \n Error: %@", error);
}];

```

### Tweet

``` objective-c

// Tweet with message containing random numbers, since you can't send the same message consecutively.
// If there's no error returned by the completion handler, our request is successful.
[_twConnect tweetWithMessage:[NSString stringWithFormat:@"Test tweet number %d", (arc4random()%NSUIntegerMax)] 
           completionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
               if (!error) {
                   NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
                   NSLog(@"Succeed: %@", response);
               } else {
                   NSLog(@"Failed: %@", error);
               }
           }];

```
### Tweet With Media

``` objective-c

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
                   NSLog(@"Succeed: %@", response);
               } else {
                   NSLog(@"Failed: %@", error);
               }
           }];

```

### Get User Timeline 

This is an example of creating your own Twitter request and performing non-authenticated request.

``` objective-c

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
        NSLog(@"Succeed: %@", response);
    } else {
        NSLog(@"Failed: %@", error);
    }
} shouldAuthenticate:NO];

```

### Get User Mentions

``` objective-c

// This method is using the twitter search api.
// In this case, it searches for '@andiputra7' keyword.
[_twConnect getUserMentions:@"andiputra7" 
           withCompletionHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
               if (!error) {
                   NSString * response = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
                   NSLog(@"Succeed: %@", response);
               } else {
                   NSLog(@"Failed: %@", error);
               }
           }];

```

## Future Updates

Use native Twitter API if device is using iOS 5 or above.