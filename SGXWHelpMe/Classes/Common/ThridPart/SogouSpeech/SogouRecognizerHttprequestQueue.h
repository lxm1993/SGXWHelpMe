//
//  SogouRecognizerHttprequestQueue.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-12-3.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SogouRecognizerHttpRequestQueueDelegate <NSObject>

-(void)didGetResult:(NSArray*)resultsArr confidence:(NSArray*)confidenceArr audioURL:(NSString*)url audioURLValid:(BOOL)url_valid isLastPart:(BOOL)isLast;

-(void)didFailed:(NSError*)error;

@optional

-(void)didReceiveRequest;

@end

@interface SogouRecognizerHttprequestQueue : NSObject
{

}
@property(nonatomic, assign)BOOL isContinuous;

@property(nonatomic,   weak)id<SogouRecognizerHttpRequestQueueDelegate> delegate;

-(instancetype)initWithStartTime:(NSTimeInterval)time;

-(void)postHttpRequestWithData:(NSData*)data isLast:(BOOL)isLast;

-(void)cancelAllHttpRequests;



@end
