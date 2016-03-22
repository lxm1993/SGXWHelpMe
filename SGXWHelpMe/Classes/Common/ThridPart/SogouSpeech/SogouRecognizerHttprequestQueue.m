//
//  SogouRecognizerHttprequestQueue.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-12-3.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouRecognizerHttprequestQueue.h"
#import "SogouConfig.h"
#import "SogouSpeechLog.h"
#import "SogouRecognizeHttpRequest.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "SogouSpeechRecognizerDelegate.h"


@interface SogouRecognizerHttprequestQueue ()
{
    int _currentRequestIndex;
    BOOL _hasReceiveEnd;
    BOOL _hasPartResults;
}

@property(nonatomic, strong)NSOperationQueue * requestQueue;
@property(nonatomic, assign)NSTimeInterval timeInterval;
@property(nonatomic, strong)NSTimer* recognizeTimer;


@end

@implementation SogouRecognizerHttprequestQueue

-(id)init
{
    return [self initWithStartTime:[[NSDate date] timeIntervalSince1970]*1000];
}

-(instancetype)initWithStartTime:(NSTimeInterval)time
{
    if (self = [super init]) {
        SGLogVerbose(@"initialize http request queue");
        _requestQueue = [[NSOperationQueue alloc]init];
        [_requestQueue setMaxConcurrentOperationCount:1];
        _currentRequestIndex = 0;
        _timeInterval = time;
        _hasReceiveEnd = NO;
        _hasPartResults = NO;
    }
    return self;
}

-(void)dealloc
{
    SGLogVerbose(@"http request queue dealloc");
    _requestQueue = nil;
    if (self.recognizeTimer) {
        [self.recognizeTimer invalidate];
        self.recognizeTimer = nil;
    }
}

-(void)postHttpRequestWithData:(NSData*)data isLast:(BOOL)isLast
{
    @autoreleasepool {
        int sequence_no = _currentRequestIndex+1;
        _currentRequestIndex ++;
        SogouRecognizeHttpRequest *request = [[SogouRecognizeHttpRequest alloc]initWithStartTime:[NSString stringWithFormat:@"%f",self.timeInterval] voiceData:data sequence:(isLast?-sequence_no:sequence_no)];
        
        BOOL canPerformSelecter = self.delegate
        && [self.delegate respondsToSelector:@selector(didGetResult:confidence:audioURL:audioURLValid:isLastPart:)]
        && [self.delegate respondsToSelector:@selector(didFailed:)];
        //使用__weak避免循环引用
        __weak typeof(request) weakRequest = request;
        __weak SogouRecognizerHttprequestQueue* weakSelf = self;
        if (isLast) {
            if (weakSelf.recognizeTimer) {
                [weakSelf.recognizeTimer invalidate];
                weakSelf.recognizeTimer = nil;
            }
            
            self.recognizeTimer = [NSTimer timerWithTimeInterval:SGRecognizeTimeOut target:self selector:@selector(recognizeTimeout:) userInfo:nil repeats:NO];
            [[NSRunLoop mainRunLoop]addTimer:self.recognizeTimer forMode:NSRunLoopCommonModes];
            [request setCompletionBlock:^{
                if (weakSelf.recognizeTimer) {
                    [weakSelf.recognizeTimer invalidate];
                    weakSelf.recognizeTimer = nil;
                }
                if (weakRequest && ![weakRequest isCancelled]) {
                    if (weakRequest.responseStatus==2 || (weakRequest.responseStatus ==8 && !_hasReceiveEnd)) {
                        _hasReceiveEnd = YES;
                        if (canPerformSelecter) {
                            [weakSelf.delegate didGetResult:weakRequest.recognizeResults confidence:weakRequest.confidenceResults audioURL:weakRequest.audioURL audioURLValid:weakRequest.audioURLValid isLastPart:YES];
                        }
                    }
                    else //error ：服务器返回解码错误 或者 网络错误。
                    {
                        if (canPerformSelecter) {
                            if(_hasPartResults == NO)
                                [weakSelf.delegate didFailed:weakRequest.responseError];
                            else
                                [weakSelf.delegate didFailed:nil];//连续语音识别在已收到中间识别结果后，返回的错误为nil
                        }
                    }
                }
            }];
        }
        else{
            [request setCompletionBlock:^{
                if (weakRequest && ![weakRequest isCancelled]) {
                    //其中一个请求失败时，传出错误信息，在外部调用取消后续所有请求
                    if (weakRequest.responseStatus == 3 ) {//中间包，有中间识别结果。则添加到resultsArr中，调用委托函数
                        _hasPartResults = YES;
                        if (canPerformSelecter) {
                            [weakSelf.delegate didGetResult:weakRequest.recognizeResults confidence:weakRequest.confidenceResults audioURL:weakRequest.audioURL audioURLValid:weakRequest.audioURLValid isLastPart:NO];
                        }
                    }
                    else if(weakRequest.responseStatus == 1){
                        if (self.delegate && [self.delegate respondsToSelector:@selector(didReceiveRequest)]) {
                            [weakSelf.delegate didReceiveRequest];
                        }
                    }
                    else
                    {
                        if (canPerformSelecter) {
                            if(_hasPartResults == NO)
                                [weakSelf.delegate didFailed:weakRequest.responseError];
                            else
                                [weakSelf.delegate didFailed:nil];//连续语音识别在已收到中间识别结果后，返回的错误为nil
                        }
                    }
                }
            }];
        }
        
        SGLogVerbose(@"add http request operation to operation queue");
        [self.requestQueue addOperation:request];
        
    }
}

-(void)cancelAllHttpRequests
{
    SGLogDebug(@"cancel all http request");
    [self.requestQueue cancelAllOperations];
}

//语音识别超时，录音最后一个包发出后开启计时器。
- (void)recognizeTimeout:(NSTimer*) timer
{
    [self cancelAllHttpRequests];
    NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_RECORDER_TIMEOUT userInfo:@{@"reason":@"recognizer time out"}];
    BOOL canPerformSelecter = self.delegate && [self.delegate respondsToSelector:@selector(didFailed:)];
    if (canPerformSelecter) {
            [self.delegate didFailed:currentError];
    }
}


@end
