//
//  SogouRecognizeHttpRequest.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouRecognizeHttpRequest.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "SogouConfig.h"
#import "SogouSpeechLog.h"
#import "SogouSpeechRecognizerDelegate.h"
#import "libencrypt.h"

@interface SogouRecognizeHttpRequest ()

@property (nonatomic, strong) NSMutableURLRequest* request;
@property (nonatomic, strong) NSString *responseContent;
@end

@implementation SogouRecognizeHttpRequest

-(instancetype)initWithStartTime:(NSString *)time voiceData:(NSData *)voiceData sequence:(int)sequenceNo
{
    SGLogVerbose(@"http request operation init");
    self = [super init];
    if (self) {
        self.startTime = time;
        self.voiceData = voiceData;
        self.sequenceNo = sequenceNo;
        
        self.isContinue = [SogouSpeechRecognizeUserInfo sharedInstance].isContinue;
    }
    return self;
}

-(void)dealloc
{
    _request = nil;
    _responseContent = nil;
    _startTime =nil;
    _voiceData =nil;
    _responseError =nil;//包括语音识别服务器返回的错误
    _jsonDic = nil;
    _responseStr =nil;
    _responseMsg=nil;
    _recognizeResults=nil;
    _confidenceResults=nil;
    
}


-(NSURLRequest*)genRequestWithRequestTime:(int)rt
{
    SogouSpeechRecognizeUserInfo *userInfo = [SogouSpeechRecognizeUserInfo sharedInstance];
    NSMutableString * scookieStr = [NSMutableString stringWithFormat:@"id=%@&key=%@",userInfo.userID,userInfo.key];
    [scookieStr appendFormat:@"&in=%@",[SogouConfig imei]];
    [scookieStr appendFormat:@"&st=%@",self.startTime];
    [scookieStr appendFormat:@"&sn=%d",self.sequenceNo];
    if (self.sequenceNo< 0 && (self.voiceData == nil || [self.voiceData length]==0)) {
        char* zeroData = (char*) calloc(60, sizeof(char));
        self.voiceData = [NSData dataWithBytes:zeroData length:60];
        free(zeroData);
    }
    [scookieStr appendFormat:@"&vl=%d",(int)[self.voiceData length]];
    [scookieStr appendFormat:@"&nt=%@",[SogouConfig netTypeStr]];
    [scookieStr appendFormat:@"&rt=%d",rt];
    
//    if (self.isContinue)
    {
        [scookieStr appendFormat:@"&c=%d",1];
    }
//    else
//    {
//        [scookieStr appendFormat:@"&c=%d",0];
//    }
    
    [scookieStr appendFormat:@"&v=%d",SDK_VERSION];
    
    if (userInfo.province && ![userInfo.province isEqualToString:@""]) {
        [scookieStr appendFormat:@"&province=%@",userInfo.province];
    }
    if (userInfo.city && ![userInfo.city isEqualToString:@""]) {
        [scookieStr appendFormat:@"&city=%@",userInfo.city];
    }
    
    scookieStr =[[scookieStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]mutableCopy];
    
    const char *scookieCStr = [scookieStr UTF8String];
    int encrypt_data_len = (int)[scookieStr length];
    char * encrypt_data = (char*)malloc(300);
    s_cookie_encrypt(scookieCStr, encrypt_data, &encrypt_data_len);
    NSLog(@"%@",scookieStr);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:userInfo.serverURL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:SGRecognizeHttpRequest_TimeoutInterval];
    [request setValue:[NSString stringWithCString:encrypt_data encoding:NSUTF8StringEncoding]forHTTPHeaderField:@"S-COOKIE"];
    [request setHTTPMethod:@"POST"];
    
    free(encrypt_data);
    encrypt_data = NULL;
    [request setHTTPBody:self.voiceData];
    return request;
}

- (void)main{
    //用一个循环来实现重传机制
    @autoreleasepool {
        for (int i = 0; i<SGRecognizeHttpRequest_MaxRetryTime; i++) {
            if ([self isCancelled]) {
                return;
            }
            
            NSError *error = nil;
            self.responseError = nil;
            NSHTTPURLResponse *response = nil;
            NSURLRequest * requestCurrent = [self genRequestWithRequestTime:i];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:requestCurrent returningResponse:&response error:&error];
            if ([self isCancelled]) {
                return;
            }
            //如果请求发生错误，则直接跳出
            if (error) {
                self.responseError = error;
                //在NSCocoaErrorsDomain领域中，除非你知道具体的CFNetWorkError类型，非则用[Error code]便利构造
                //self.responseError = [NSError errorWithDomain:NSCocoaErrorDomain code:[error code] userInfo:[NSDictionary dictionary]];
                SGLogInfo(@"when http request, an error occurs, %@", error);
                break;
            }
            if ([self isCancelled]) {
                return;
            }
            //返回状态码非200则重发
            NSLog(@"%@",response);
            if ([response respondsToSelector:@selector(statusCode)] && response != nil) {
                long code  = [response statusCode];
                if (code != 200) //非200状态码，全归结为网络错误
                {
                    if (i<SGRecognizeHttpRequest_MaxRetryTime-1) {
                        SGLogInfo(@"http request times out ,retry!");
                        continue;
                    }else
                    {
                        if ([response respondsToSelector:@selector(allHeaderFields)]) {
                            self.responseError = [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:[response allHeaderFields]];
                        }
                        SGLogInfo(@"http request times out ,has retried %d times, stop trying!",SGRecognizeHttpRequest_MaxRetryTime);
                        break;
                    }
                }
            }
            if ([self isCancelled]) {
                return;
            }
            if (responseData != nil) {
                self.responseContent = [[NSString alloc] initWithData:responseData encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
            }
            //self.responseStr = @"{\"status\":3, \"message\":\"part_result.\", \"amount\":1, \"content\":[{\"num\":3,\"res\":[\"12345\", \"一二三四五\", \"一二三十五\"],\"con\":[1,2,3]}]}";
            SGLogDebug(@"http download data:%@, error:%@",self.responseContent,error);
//            NSLog(@"http download data:%@, error:%@",self.responseContent,error);
            if ([self isCancelled]) {
                return;
            }
            if (self.responseContent) {
                self.jsonDic = [NSJSONSerialization JSONObjectWithData:[self.responseContent dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
                if (error) {
                    SGLogInfo(@"response string to json error :%@",error);
                    self.responseError = error;
                    break;
                }
            }
            if ([self isCancelled]) {
                return;
            }
            if (self.responseError == nil && self.jsonDic) {
                [self parseJson];
                break;
            }
        }
    }
}

//输入法不需要返回confidence;
#define RECORD_TYPE_GET_VALUE_APP(x)   (x>>9 & 31)


-(void)parseJson
{
    //输入法不需要返回confidence;
    SGLogVerbose(@"parse json");
//    int flag = RECORD_TYPE_GET_VALUE_APP([SogouSpeechRecognizeUserInfo sharedInstance].typeNo);
    int flag = 1;

    if (_isContinue /*&& [self.jsonDic count]==4*/) {//连续语音识别（新版）
        int amount = [[self.jsonDic objectForKey:@"amount"]intValue];
        self.responseStatus = [[self.jsonDic objectForKey:@"status"]intValue];
        self.responseMsg = [self.jsonDic objectForKey:@"content"];
        if (amount >= 1)
        {
            _isMany = YES;
            switch (self.responseStatus) {
                case 0:
                    self.responseError = [NSError errorWithDomain:@"SogouSpeechRecognizerServerErrorDomain" code:ERROR_NO_MATCH userInfo:@{@"reason":self.responseMsg}];
                    break;
                case 1:
                    break;
                case 2:
                case 3:
                case 8:
                {
                    NSArray *str = [self.jsonDic objectForKey:@"content"];
                    self.recognizeResults = [str mutableCopy];
                    self.confidenceResults = [self.jsonDic objectForKey:@"confidence"];
                    self.audioURL = [self.jsonDic objectForKey:AUDIO_URL_KEY];
                    self.audioURLValid = [[self.jsonDic objectForKey:AUDIO_URL_VALID_KEY] boolValue];
                    break;
                }
                default:
                    self.responseError = [NSError errorWithDomain:@"SogouSpeechRecognizerServerErrorDomain" code:ERROR_RECOGNIZER_BUSY userInfo:@{@"reason":self.responseMsg}];
                    break;
            }
        }
    }
    else//非连续语音识别（旧版）
    {
//        if (flag != 0b01000 && [self.jsonDic count]!=5) {
//            SGLogWarn(@"json data not match old version");
//            SGLogWarn(@"version与isContinuous没有正确对应，可能导致不稳定");
//        }
        _isMany = NO;
        self.responseStatus = [[self.jsonDic objectForKey:@"status"]intValue];
        self.responseMsg = [self.jsonDic objectForKey:@"message"];
        switch (self.responseStatus) {
            case 0:
                self.responseError = [NSError errorWithDomain:@"SogouSpeechRecognizerServerErrorDomain" code:ERROR_NO_MATCH userInfo:@{@"reason":self.responseMsg}];
                break;
            case 1:
                break;
            case 2:
            case 8:
            {
                self.recognizeResults = [self.jsonDic objectForKey:@"content"];
                if (flag != 0b01000) {
                    self.confidenceResults = [self.jsonDic objectForKey:@"confidence"];
                }
                break;
            }
            default:
                self.responseError = [NSError errorWithDomain:@"SogouSpeechRecognizerServerErrorDomain" code:ERROR_RECOGNIZER_BUSY userInfo:@{@"reason":self.responseMsg}];
                break;
        }
    }
}


@end

