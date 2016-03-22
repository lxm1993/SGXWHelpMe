//
//  SogouSpeechRecognizeUserInfo.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-28.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouSpeechRecognizeUserInfo.h"
#import <UIKit/UIKit.h>
//#import <CommonCrypto/CommonDigest.h>
//#import <sys/utsname.h>
//#import <sys/socket.h>
//#import <sys/sysctl.h>
//#import <sys/utsname.h>
//#import <sys/socket.h>
//#import <net/if.h>
//#import <net/if_dl.h>

#import "SogouSpeechLog.h"
#import "SogouConfig.h"

@interface SogouSpeechRecognizeUserInfo ()
{
    
}

@property(nonatomic, copy)NSString* serverURL;


@end

@implementation SogouSpeechRecognizeUserInfo

+(instancetype)sharedInstance
{
    static SogouSpeechRecognizeUserInfo* _sharedUserInfoInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        _sharedUserInfoInstance = [[self alloc]init];
    });
    return _sharedUserInfoInstance;
}

-(id)init
{
    self = [super init];
    if (self) {
        _serverURL = @"http://search.speech.sogou.com/index.cgi";
        _area = 0;
        
        _vad_bos = 3000;
        _vad_eos = 900;
        _max_record_interval = 30;
        _audioPath = nil;
        _speexPath = nil;
        _userID  = nil;
        _key = nil;
        
        _record_too_short_threshold = 3.0;
        _time_to_show_record_message = 2.0;
        SGLogDebug(@"initialize recognizer user information");
    }
    return self;
}

#pragma set configuration
+(void)setCustomUrl:(NSString *)str
{
    SGLogVerbose(@"set url");
    [[self sharedInstance] setServerURL:str];
}

+(void)setArea:(int)area
{
    SGLogVerbose(@"set area");
    [[self sharedInstance] setArea:area];
}

+ (void)setRecognizerVersion:(int)aVersion
{
    SGLogVerbose(@"set speech recognizer version");
    [[self sharedInstance] setRecognizerVersion:aVersion];
}

+ (void) setVadHeadInterval:(int)vad_bos withTailInterval:(int)vad_eos
{
    [[self sharedInstance]setVad_bos:vad_bos];
    [[self sharedInstance]setVad_eos:vad_eos];
}

//  音频文件名；设置此参数后，将会自动保存识别的录音文件。不设置或者设置为nil，则不保存音频。
+ (void) setAsrAudioPath:(NSString*)asrAudioPath
{
    [[self sharedInstance]setAudioPath:asrAudioPath];
}

//  设置录音最多能够录多少秒。
+ (void) setMaxRecordInterval:(float)interval
{
    [[self sharedInstance]setMax_record_interval:interval];
}

//  设置保存语音压缩后数据的路径，设置此参数后，将会自动保存录音的压缩文件。不设置或者设置为nil，则不保存。
+ (void) setSaveSpxPath:(NSString*)spxPathStr{
    [[self sharedInstance]setSpeexPath:spxPathStr];
}

+(void)setIsContinuous:(BOOL)isContinuous
{
    [[self sharedInstance]setIsContinue:isContinuous];
}

-(void)setUserID:(NSString *)userID andKey:(NSString *)key
{
    self.userID = userID;
    self.key =key;
}
+(void)setUserID:(NSString *)userID andKey:(NSString *)key
{
    [[self sharedInstance]setUserID:userID andKey:key];
}

+(void)setRecorderTooShortThreshold:(float)interval
{
    [[self sharedInstance]setRecord_too_short_threshold:interval];
}

+(void)setTimeToShowRecordMessage:(float)interval
{
    [[self sharedInstance]setTime_to_show_record_message:interval];
}


+(void)setProvince:(NSString *)province
{
    [[self sharedInstance]setProvince:province];
}
+(void)setCity:(NSString *)city
{
    [[self sharedInstance]setCity:city];
}
@end
