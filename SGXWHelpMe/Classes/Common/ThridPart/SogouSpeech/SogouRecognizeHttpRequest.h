//
//  SogouRecognizeHttpRequest.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AUDIO_URL_KEY @"url"
#define AUDIO_URL_VALID_KEY @"effect"

@interface SogouRecognizeHttpRequest : NSOperation

//输入
@property(nonatomic, strong)NSString* startTime;
@property(nonatomic, assign)int sequenceNo;
@property(nonatomic, strong)NSData * voiceData;
@property BOOL isContinue;

//输出

@property (nonatomic, strong) NSError *responseError;//包括语音识别服务器返回的错误
@property (nonatomic, strong) NSDictionary *jsonDic;
@property (nonatomic, strong) NSString *responseStr;
@property (nonatomic, strong) NSString *responseMsg;
@property int  responseStatus;
@property BOOL isMany;
@property (nonatomic, strong) NSMutableArray *recognizeResults;
@property (nonatomic, strong) NSMutableArray *confidenceResults;

@property (nonatomic, copy)NSString* audioURL;
@property (nonatomic, assign)BOOL audioURLValid;

//-(instancetype)initWithStartTime:(NSString*)time voiceData:(NSData*)voiceData sequence:(int)sequenceNo otherParams:(NSDictionary*)otherParams;

-(instancetype)initWithStartTime:(NSString*)time voiceData:(NSData*)voiceData sequence:(int)sequenceNo;

@end
