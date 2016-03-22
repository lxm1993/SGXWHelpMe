//
//  SogouSpeechRecognizer.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouSpeechRecognizer.h"
#import "SogouSpeechLog.h"
#import "SogouConfig.h"
#import "SogouRecorder.h"
#import "SogouVad.h"
#import "SogouSpeexEncoder.h"
#import "SogouRecognizerHttprequestQueue.h"
#import "SogouSpeechRecognizerDelegate.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "SogouRecognizerPingback.h"

typedef NS_OPTIONS(NSUInteger, SG_SPEECH_RECOGNIZER_STATUS) {
    SGRecognizer_status_idle,
    SGRecognizer_sataus_recording,
    SGRecognizer_status_recognizing
//    SGRecognizer_status_audioStreamOnly_waitingForResults
//    SGRecognizer_status_cancel,
//    SGRecognizer_status_error
};

@interface SogouSpeechRecognizer ()<SogouRecorderDelegate ,SogouRecognizerHttpRequestQueueDelegate>
{
    SG_SPEECH_RECOGNIZER_STATUS _recognize_status;
    dispatch_queue_t _pcm2speex_queue;
    
    //用来判断是否过快点击了停止按钮，如果还没有有效声音就点击了停止按钮，那么就会返回一个录音太短的错误。
    BOOL _voiceActive;
    
    BOOL _flag_time_to_show_record_message;
}
//@property(strong, nonatomic) dispatch_queue_t pcm2speex_queue;
@property(strong ,nonatomic) SogouRecorder* recorder;
@property(strong, nonatomic) SogouVad *vad;
@property(strong, nonatomic) SogouSpeexEncoder *encoder;
@property(strong, nonatomic) NSMutableData* encodeData;
@property(strong, nonatomic) SogouRecognizerHttprequestQueue *httpRequestQueue;

@property(strong, nonatomic) NSOperationQueue* readAudioStremQueue;

//@property(copy , nonatomic) NSString* audioPath;
//@property(copy , nonatomic) NSString* spxPath;

@property(strong, nonatomic,readwrite) NSMutableArray * resultsArray;
@property(strong, nonatomic) NSMutableArray * confidencesArray;

//屏幕刷新定时器。
@property(nonatomic, strong)CADisplayLink *volumeTimer;

@property(strong, nonatomic) NSString* recognizerStartTime;
@property(strong, nonatomic) SogouRecognizerPingback *pingback;
@property(assign, nonatomic) int click_pingback;
@property(assign, nonatomic) NSTimeInterval recorderEndTime;

@property(nonatomic, strong) NSMutableData* willHandleVoiceDataBuffer;//将要用于处理的原始音频数据，由于vad期望传入的数据足够小，所以增加一个缓存切分原始音频数据
@end

@implementation SogouSpeechRecognizer

static SogouSpeechRecognizer *__speechRecognizerInstance = nil;

+(SogouSpeechRecognizer*)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        __speechRecognizerInstance = [[SogouSpeechRecognizer alloc]init];
    });
    return __speechRecognizerInstance;
}

-(id)init
{
    if (self = [super init]) {
        _recognize_status = SGRecognizer_status_idle;
    }
    return self;
}

- (BOOL) destroy
{
    if (self.vad) {
        [self.vad destroy];
        self.vad =nil;
    }
    self.recorder = nil;
    _pcm2speex_queue = nil;
    self.encoder = nil;
    self.encodeData = nil;
    if (self.httpRequestQueue) {
        [self.httpRequestQueue cancelAllHttpRequests];
        self.httpRequestQueue = nil;
    }
    self.resultsArray = nil;
    self.confidencesArray =nil;
    self.recognizerStartTime = nil;
    if (self.pingback) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SGSR_pingback_vad_preInterval" object:nil];
        self.pingback = nil;
    }
    
    if (self.readAudioStremQueue) {
        self.readAudioStremQueue = nil;
    }
    
    self.willHandleVoiceDataBuffer = nil;
    return YES;
}
//需要测试是否提前返回
-(BOOL)checkRecordPermission
{
    //    AVAudioSessionRecordPermission permission = [[AVAudioSession sharedInstance]recordPermission];
    //    if (permission == AVAudioSessionRecordPermissionUndetermined)
    {
        if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)])
        {
            //requestRecordPermission麦克风权限
            __block BOOL denied;
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                denied = !granted;
            }];
            if (denied) {
                return NO;
            }else
            {
                return YES;
            }
        }
        return YES;
    }
}

-(BOOL)startListening
{
    if (![self userInfoSettingWarnning]) {
        return NO;
    }
    if (_recognize_status != SGRecognizer_status_idle) {
        SGLogWarn(@"can not start another recognizer!");
        return NO;
    }
    if (![self checkRecordPermission]) {
        NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_INSUFFICIENT_PERMISSIONS userInfo:@{@"reason":@"No record permission"}];
        [self switchErrorType:currentError];
        return NO;
    }
//-------------保证内存峰值不至于过高。
    [self destroy];
//-------------初始化recorder
    self.recorder = [[SogouRecorder alloc]init];
    [self.recorder setRecordDelegate:self];
    if ([SogouSpeechRecognizeUserInfo sharedInstance].audioPath) {
        [self.recorder setIsSaveWav:YES];
        [self.recorder setAudioPath:[SogouSpeechRecognizeUserInfo sharedInstance].audioPath];
    }
    BOOL prepared =[self.recorder prepareRecord];
    if (!prepared) {
        NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_AUDIO userInfo:@{@"reason":@"Prepare recorder error"}];
        [self switchErrorType:currentError];
        return NO;
    }
    
    _flag_time_to_show_record_message = NO;
//-------------初始化vad
    _voiceActive = NO;
    self.willHandleVoiceDataBuffer = [NSMutableData data];
    
    self.vad = [[SogouVad alloc]initWithFormat:self.recorder.recordFormat withHeadInterval:[SogouSpeechRecognizeUserInfo sharedInstance].vad_bos withTailInterval:[SogouSpeechRecognizeUserInfo sharedInstance].vad_eos withMaxWavInterval:[SogouSpeechRecognizeUserInfo sharedInstance].max_record_interval];
    [self.vad setIsAutoStop:YES];
//-------------初始化speex encoder，多线程操作。
    if (_pcm2speex_queue == nil) {
        _pcm2speex_queue = dispatch_queue_create("pcm2speex_queue",DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(_pcm2speex_queue, ^{
        self.encoder =[[SogouSpeexEncoder alloc]init];
        [self.encoder setSaveSpxPath:[SogouSpeechRecognizeUserInfo sharedInstance].speexPath];
        self.encodeData = [NSMutableData data];
    });
//-------------初始化网络传输queue
    self.recognizerStartTime = [NSString stringWithFormat:@"%lld",(long long)[[NSDate date] timeIntervalSince1970]*1000];
    self.httpRequestQueue = [[SogouRecognizerHttprequestQueue alloc]initWithStartTime:[self.recognizerStartTime longLongValue]];
    self.httpRequestQueue.isContinuous = NO;
    self.httpRequestQueue.delegate = self;
//-------------重置保存结果的队列和置信度队列
    self.resultsArray = [NSMutableArray array];
    self.confidencesArray= [NSMutableArray array];
    
//--------------
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        self.pingback = [[SogouRecognizerPingback alloc]init];
        [self.pingback setStartTime:self.recognizerStartTime];
        _click_pingback = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealNotification) name:@"SGSR_pingback_vad_preInterval" object:nil];
    }

    BOOL started =[self.recorder startRecord];
    if (started) {
        _recognize_status = SGRecognizer_sataus_recording;
        if ([self.recognizeDelegate respondsToSelector:@selector(onUpdateVolume:)]) {
            self.volumeTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateVolume)];
            [self.volumeTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    }else
    {
        NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_AUDIO userInfo:@{@"reason":@"Start recorder error"}];
        [self switchErrorType:currentError];
        return NO;
    }
    return YES;
}

-(void)dealNotification
{
    [self.pingback setPreInterval:[[NSDate date] timeIntervalSince1970]*1000 - [self.recognizerStartTime longLongValue]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SGSR_pingback_vad_preInterval" object:nil];
}

-(void)stopListening
{
//    if (self.recorder.isRunning == YES) {
//        [self.recorder stopRecordWithReason:SogouRecorderStopReason_UserOption];
////      手动停止录音需要像speex通知压缩缓存剩余数据，形成最后一个压缩包。
//        [self vadData2SpeexData:nil isLast:YES];
//    }
//    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
//        _click_pingback = _click_pingback | 1;
//        [self.pingback setClick :_click_pingback];
//    }
    if (self.recorder.isRunning == YES) {
        [self.recorder stopRecordWithReason:SogouRecorderStopReason_UserOption];
        
        if (_voiceActive == NO) {
            float recordInterval = [[NSDate date] timeIntervalSince1970] - [self.recognizerStartTime longLongValue] / 1000.0;
            if (recordInterval < [SogouSpeechRecognizeUserInfo sharedInstance].record_too_short_threshold) {
                NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_RECORDER_TOO_SHORT userInfo:@{@"reason":@"audio too short"}];
                [self switchErrorType:currentError];
            }
            else
            {
                NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_SPEECH_TIMEOUT userInfo:@{@"reason":@"No effective voice"}];
                [self switchErrorType:currentError];
            }
            return;
        }
        
        //      手动停止录音需要像speex通知压缩缓存剩余数据，形成最后一个压缩包。
        [self vadData2SpeexData:nil isLast:YES];
    }
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        _click_pingback = _click_pingback | 1;
        [self.pingback setClick :_click_pingback];
    }
}
-(void)cancel
{
    if (self.readAudioStremQueue) {
        [self.readAudioStremQueue cancelAllOperations];
        self.readAudioStremQueue = nil;
    }
    if (self.recorder.isRunning == YES) {
        [self.recorder stopRecordWithReason:SogouRecorderStopReason_UserOption];
    }
    if (self.httpRequestQueue != nil && _recognize_status == SGRecognizer_status_recognizing) {
        [self.httpRequestQueue cancelAllHttpRequests];
    }
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        _click_pingback = _click_pingback | 2;
        [self.pingback setClick :_click_pingback];
        if (_recognize_status == SGRecognizer_status_recognizing) {
            [self.pingback onEndWithText:nil error:0];
        }
    }
//    if (self.readAudioStremQueue) {
//        [self.readAudioStremQueue cancelAllOperations];
//        self.readAudioStremQueue = nil;
//    }
    _recognize_status = SGRecognizer_status_idle;
}

-(float)getCurrentVolume
{
    if (self.recorder && self.recorder.isRunning) {
        return [self.recorder currentLevelMeter]*100;
    }
    else
    {
        SGLogError(@"recorder has not started, current volume = 0");
        return 0.0;
    }
}


-(void)vadData2SpeexData:(NSData*)vadData_ isLast:(BOOL)isLast_;
{
    __weak typeof(self) weakSelf = self;
    if (!_pcm2speex_queue) {//添加此处以防在音频流识别过程中，调用取消cancel方法崩溃
        return;
    }
    dispatch_async(_pcm2speex_queue, ^{
        @autoreleasepool {
            if (isLast_) {
                NSData* speexData = [weakSelf.encoder encode:Nil isLast:YES];
                [weakSelf appendEncodedData:speexData isLast:YES];
            }
            else
            {
                NSData* speexData = [weakSelf.encoder encode:vadData_ isLast:NO];
                [weakSelf appendEncodedData:speexData isLast:NO];
            }
        }
    });
}

- (void)appendEncodedData:(NSData *)data isLast:(BOOL)isLast{
    [self.encodeData appendData:data];
    while ([self.encodeData length]>=3000) {
        @autoreleasepool {
            NSRange rangeToSend = NSMakeRange(0, 3000);
            NSData *dataToSend = [self.encodeData subdataWithRange:rangeToSend];
            [self.encodeData replaceBytesInRange:rangeToSend withBytes:NULL length:0];
            [self sendData2Server:dataToSend isLast:NO];
        }
        
    }
    
    if (isLast) {
        @autoreleasepool {
            NSRange rangeToSend = NSMakeRange(0, [self.encodeData length]);
            NSData *dataToSend = [self.encodeData subdataWithRange:rangeToSend];
            [self.encodeData replaceBytesInRange:rangeToSend withBytes:NULL length:0];
            [self sendData2Server:dataToSend isLast:YES];
        }
    }
}

-(void)sendData2Server:(NSData*)data isLast:(BOOL)isLast
{
    _recognize_status = SGRecognizer_status_recognizing;
    [self.httpRequestQueue postHttpRequestWithData:data isLast:isLast];
}



-(void)switchErrorType:(NSError*)err
{
    if (err == nil) {
        //如果连续识别有中间结果，不向上回调委托类实现的错误方法。但是标识这次识别结束，发送pingback
        //        if ([SogouSpeechRecognizeUserInfo sharedInstance].enablePingback) {
        //            [ self.pingback setSufInterval:([[NSDate date] timeIntervalSince1970] - self.recorderEndTime)*1000];
        //            [self.pingback onEndWithText:nil error:-1];
        //        }
        [self didGetResult:nil confidence:nil audioURL:nil audioURLValid:NO isLastPart:YES];
    }else
    {
        if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onError:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.recognizeDelegate onError:err];
            });
        }
        
        if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
            [self.pingback onEndWithText:nil error:err.code];
        }
        
        if (self.recorder.isRunning == YES) {
            [self.recorder stopRecordWithReason:SogouRecorderStopReason_UserOption];
        }
        if (self.httpRequestQueue != nil && _recognize_status == SGRecognizer_status_recognizing) {
            [self.httpRequestQueue cancelAllHttpRequests];
        }
    }
    _recognize_status = SGRecognizer_status_idle;
}



#pragma mark timer handler
- (void)updateVolume{
    if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onUpdateVolume:)]) {
        [self.recognizeDelegate onUpdateVolume:[self.recorder currentLevelMeter]*100];
    }
}


#pragma SogouRecorderDelegate
/**
 *  vad
 *
 *  @param voiceData 输入数据
 *  @param status
 status = -1表示出错
 status = 0检测中
 status = 1表示检测到开始（每次只有一个1）
 status = 2有效声音（）
 status = 3有停顿
 status = 4无有效声音(在语音识别中用到)
 *
 *  @return 输出数据
 */
-(void)onGetVoiceData:(NSData *)data sampleRate:(int)sampleRate channel:(int)channel
{
    if (self.recorder.isRunning == NO) {
        return;
    }
    //
    if (!_flag_time_to_show_record_message && !_voiceActive) {
        float recordInterval = [[NSDate date] timeIntervalSince1970] - [self.recognizerStartTime longLongValue] / 1000.0;
        if (recordInterval >= [SogouSpeechRecognizeUserInfo sharedInstance].time_to_show_record_message) {
            if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onRecordTimeAtPoint:)]) {
                [self.recognizeDelegate onRecordTimeAtPoint:[SogouSpeechRecognizeUserInfo sharedInstance].time_to_show_record_message];
            }
            _flag_time_to_show_record_message = YES;
        }
    }
    @synchronized(self.willHandleVoiceDataBuffer) {
        [self.willHandleVoiceDataBuffer appendData:data];
        
        while ([self.willHandleVoiceDataBuffer length]>0) {
            if (self.recorder.isRunning == NO) {
                return;
            }
            @autoreleasepool {
                //            int result = 0;
                //            NSData *vadData = [self.vad vadDetect:data status:&result];
                
                NSRange rangeToSend ;
                if ([self.willHandleVoiceDataBuffer length] >= 4096) {
                    rangeToSend = NSMakeRange(0, 4096);
                }else
                {
                    rangeToSend = NSMakeRange(0, [self.willHandleVoiceDataBuffer length]);
                }
                
                NSData *dataToSend = [self.willHandleVoiceDataBuffer subdataWithRange:rangeToSend];
                [self.willHandleVoiceDataBuffer replaceBytesInRange:rangeToSend withBytes:NULL length:0];
                
                int result = 0;
                
                NSData* vadData = [self.vad vadDetect:dataToSend status:&result];
                SGLogDebug(@"vad status = %d datalen = %lu",result, (unsigned long)[data length]);
                if (result == 3) {
                    [self.recorder stopRecordWithReason:SogouRecorderStopReason_vadEnd];
                    [self vadData2SpeexData:vadData isLast:YES];
                    _voiceActive = YES;
                }
                else if(result == 4)
                {
                    [self.recorder stopRecordWithReason:SogouRecorderStopReason_vadEnd];
                    NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_SPEECH_TIMEOUT userInfo:@{@"reason":@"No effective voice"}];
                    [self switchErrorType:currentError];
                }
                else if(result == 1 || result == 2)
                {
                    if ([vadData length]>0){
                        [self vadData2SpeexData:vadData isLast:NO];
                    }
                    _voiceActive = YES;
                }
                else if(result == 0)
                {
                    
                }
                else if(result == -1)
                {
                    [self.recorder stopRecordWithReason:SogouRecorderStopReason_vadEnd];
                    NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_SPEECH_TIMEOUT userInfo:@{@"reason":@"voice active detection error"}];
                    [self switchErrorType:currentError];
                }
                else
                {
                    [self.recorder stopRecordWithReason:SogouRecorderStopReason_vadEnd];
                    NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_SPEECH_TIMEOUT userInfo:@{@"reason":@"voice active detection unknown error"}];
                    [self switchErrorType:currentError];
                }
            }
        }
    }
    
}


-(void)recorderDidStop:(int)status withError:(int)errCode
{
    if (status == SogouRecorderStopReason_Timesup) {
        //超过20秒，将返回错误，并且中断语音识别
        NSError *currentError = [NSError errorWithDomain:@"SogouSpeechRecognizerClientErrorDomain" code:ERROR_RECORDER_TOO_LONG userInfo:@{@"reason":@"record more than 30 seconds"}];
        [self switchErrorType:currentError];
        
//        [self vadData2SpeexData:nil isLast:YES];
    }
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        self.recorderEndTime = [[NSDate date] timeIntervalSince1970];
    }
    if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onRecordStop)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recognizeDelegate onRecordStop];
            [self.volumeTimer invalidate];
            self.volumeTimer = nil;
        });
    }

}

//-(void)recorderDidRecord
//{
//    
//}

#pragma SogouRecognizerHttpRequestQueueDelegate
-(void)didGetResult:(NSArray *)resultsArr confidence:(NSArray *)confidenceArr audioURL:(NSString *)url audioURLValid:(BOOL)url_valid isLastPart:(BOOL)isLast
{
    
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/ && isLast) {
        [ self.pingback setSufInterval:([[NSDate date] timeIntervalSince1970] - self.recorderEndTime)*1000];
        [self.pingback onEndWithText:nil error:-1];
    }
    if (resultsArr) {
        [self.resultsArray addObject:resultsArr];
    }
    if (confidenceArr) {
        [self.confidencesArray addObject:confidenceArr];
    }
    if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onResults:confidence:audioURL:audioURLValid:isLastPart:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recognizeDelegate onResults:resultsArr confidence:confidenceArr audioURL:url audioURLValid:url_valid isLastPart:isLast];
        });
    }
    if (isLast) {
        _recognize_status = SGRecognizer_status_idle;
    }
    
    
}
-(void)didFailed:(NSError *)error
{
//    添加用来判断连续语音识别是否已收到中间识别结果，已经收到过中间识别结果后，此函数返回错误为nil。
    if (error == nil) {
        [self switchErrorType:nil];
        return;
    }
    
    int cfNetworkErrorEnumNumber = error.code;
    NSError * currentErr;
    if (cfNetworkErrorEnumNumber >=  -100 && cfNetworkErrorEnumNumber <= 100) {
        [self switchErrorType:error];
        return;
    }
//    else if (cfNetworkErrorEnumNumber > 0 && cfNetworkErrorEnumNumber < 10) {
//        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"host error"}];
//    }
    else if (cfNetworkErrorEnumNumber > 100 && cfNetworkErrorEnumNumber < 200) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"SOCKS error"}];
    }else if (cfNetworkErrorEnumNumber > 300) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"HTTP error"}];
    }else if (cfNetworkErrorEnumNumber > -1200 && cfNetworkErrorEnumNumber <= -996) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"CFURLConnection or CFURLProtocol error"}];
    }else if (cfNetworkErrorEnumNumber >=  -2000 && cfNetworkErrorEnumNumber <= -1200) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"SSL error"}];
    }else if (cfNetworkErrorEnumNumber ==  -4000) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"cookie error"}];
    }else if (cfNetworkErrorEnumNumber ==  2000) {
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"FTP error"}];
    }else{
        currentErr = [NSError errorWithDomain:@"SogouSpeechRecognizerNetworkErrorDomain" code:ERROR_NETWORK_STATUS_CODE userInfo:@{@"reason":@"unknown error"}];
    }
    
    [self switchErrorType:currentErr];
}

//-(void)didReceiveRequest
//{
//    NSLog(@"======");
//}



-(BOOL)prepareInputAudioStream
{
    if (![self userInfoSettingWarnning]) {
        return NO;
    }
    if (_recognize_status != SGRecognizer_status_idle) {
        SGLogWarn(@"can not start another recognizer!");
        return NO;
    }
    
    //-------------保证内存峰值不至于过高。
    [self destroy];
    
    //-------------
    self.readAudioStremQueue = [[NSOperationQueue alloc]init];
    
    //-------------初始化speex encoder，多线程操作。
    if (_pcm2speex_queue == nil) {
        _pcm2speex_queue = dispatch_queue_create("pcm2speex_queue",DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(_pcm2speex_queue, ^{
        self.encoder =[[SogouSpeexEncoder alloc]init];
        self.encodeData = [NSMutableData data];
    });
    //-------------初始化网络传输queue
    self.recognizerStartTime = [NSString stringWithFormat:@"%lld",(long long)[[NSDate date] timeIntervalSince1970]*1000];
    self.httpRequestQueue = [[SogouRecognizerHttprequestQueue alloc]initWithStartTime:[self.recognizerStartTime longLongValue]];
    self.httpRequestQueue.isContinuous = NO;
    self.httpRequestQueue.delegate = self;
    //-------------重置保存结果的队列和置信度队列
    self.resultsArray = [NSMutableArray array];
    self.confidencesArray= [NSMutableArray array];
    
    //--------------
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        self.pingback = [[SogouRecognizerPingback alloc]init];
        [self.pingback setStartTime:self.recognizerStartTime];
        _click_pingback = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dealNotification) name:@"SGSR_pingback_vad_preInterval" object:nil];
    }
    
    return YES;
}



-(BOOL)writeAudio:(NSData *)audioData
{
    if (_recognize_status != SGRecognizer_status_idle) {
        return NO;
    }
    
    NSInvocationOperation *op = [[NSInvocationOperation  alloc]initWithTarget:self selector:@selector(writeAudioData:) object:audioData];
    
    [self.readAudioStremQueue addOperation:op];
//    static dispatch_queue_t serialQueue = nil;
//    if (serialQueue == nil) {
//        serialQueue = dispatch_queue_create("com.example.CriticalTaskQueue", NULL);
//    }
//    
//    dispatch_async(serialQueue, ^{
//        //暂且不做重试与错误处理
//        do {
//            if (_recognize_status == SGRecognizer_status_audioStreamOnly_waitingForResults) {
//                break;
//            }
//            NSData *buffer = audioData;
//            int bufferIndex = 0;
//            while ([buffer length] - bufferIndex > 3200) {
//                NSData* data = [buffer subdataWithRange:NSMakeRange(bufferIndex, 3200)];
//                [self vadData2SpeexData:data isLast:NO];
//                bufferIndex += [data length];
//                [NSThread sleepForTimeInterval:0.05];
//            }
//            NSData* data = [buffer subdataWithRange:NSMakeRange(bufferIndex, [buffer length] - bufferIndex)];
//            
//            [self vadData2SpeexData:data isLast:YES];
//            _recognize_status = SGRecognizer_status_audioStreamOnly_waitingForResults;
//            NSLog(@"--------------------%d",_recognize_status);
//            if ([SogouSpeechRecognizeUserInfo sharedInstance].enablePingback) {
//                self.recorderEndTime = [[NSDate date] timeIntervalSince1970];
//            }
//            if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onRecordStop)]) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.recognizeDelegate onRecordStop];
//                });
//            }
//           
//        } while (0);
//
//    });
//
    return YES;
}


-(void)writeAudioData:(NSData*)data_
{
    NSData *buffer = data_;
    int bufferIndex = 0;
    while ([buffer length] - bufferIndex > 3200) {
        NSData* data = [buffer subdataWithRange:NSMakeRange(bufferIndex, 3200)];
        [self vadData2SpeexData:data isLast:NO];
        bufferIndex += [data length];
        [NSThread sleepForTimeInterval:0.1];
    }
    NSData* data = [buffer subdataWithRange:NSMakeRange(bufferIndex, [buffer length] - bufferIndex)];
    
    [self vadData2SpeexData:data isLast:YES];
//    _recognize_status = SGRecognizer_status_audioStreamOnly_waitingForResults;
//    NSLog(@"--------------------%d",_recognize_status);
    if (YES/*[SogouSpeechRecognizeUserInfo sharedInstance].enablePingback*/) {
        self.recorderEndTime = [[NSDate date] timeIntervalSince1970];
    }
    if (self.recognizeDelegate && [self.recognizeDelegate respondsToSelector:@selector(onRecordStop)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.recognizeDelegate onRecordStop];
        });
    }
}

-(BOOL)userInfoSettingWarnning{
    if ([SogouSpeechRecognizeUserInfo sharedInstance].userID == nil || [SogouSpeechRecognizeUserInfo sharedInstance].key == nil) {
        NSLog(@"not set user id or access key");
        SGLogError(@"please set user ID and access key");
        return NO;
    }
    return YES;
}

@end




