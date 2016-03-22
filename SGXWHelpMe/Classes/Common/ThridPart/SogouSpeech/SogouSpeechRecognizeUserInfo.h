//
//  SogouSpeechRecognizeUserInfo.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-28.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SogouSpeechRecognizeUserInfo : NSObject
{
    
}
@property(nonatomic, copy, readonly)NSString* serverURL;
@property(nonatomic, assign)int area;
@property(nonatomic, assign)int vad_bos;
@property(nonatomic, assign)int vad_eos;
@property(nonatomic, assign)int max_record_interval;
@property(nonatomic, strong)NSString* audioPath;
@property(nonatomic, strong)NSString* speexPath;
@property(nonatomic, assign)BOOL isContinue;
@property(nonatomic,copy)NSString* userID;
@property(nonatomic,copy)NSString* key;
@property(nonatomic, copy)NSString* province;
@property(nonatomic, copy)NSString* city;

@property(nonatomic, assign)float record_too_short_threshold;
//当录音达到这个时间长度，且没有有效声音被检测到，则会产生回调
@property(nonatomic, assign)float time_to_show_record_message;

//设置语音识别相关参数，单例模式
+ (instancetype)sharedInstance;

/* 设置账号密码。（开始识别前，必须设置）
 @param userID:账号； @param key:密码 */
+ (void)setUserID:(NSString*)userID andKey:(NSString*)key;

//默认为0,设置方言（目前支持普通话，粤语）
+ (void)setArea:(int)area;

//  设置vad头部和尾部的判断时间长度（单位：毫秒。默认为3000ms头部，900ms尾部）
//@param: vad_bos：前端点检测；静音超时时间，即用户多长时间不说话则当做超时处理；
//@param: vad_eos：后断点检测；后端点静音检测时间，即用户停止说话多长时间内即认为不再输入，自动停止录音.
+ (void) setVadHeadInterval:(int)vad_bos withTailInterval:(int)vad_eos;

//  音频文件名；设置此参数后，将会自动保存识别的录音文件。不设置或者设置为nil，则不保存音频。
+ (void) setAsrAudioPath:(NSString*)asrAudioPath;

//  设置录音最多能够录多少秒。
+ (void) setMaxRecordInterval:(float)interval;

//  设置保存语音压缩后数据的路径，设置此参数后，将会自动保存录音的压缩文件。不设置或者设置为nil，则不保存。
+ (void) setSaveSpxPath:(NSString*)spxPathStr;

//选择识别的方式：连续语音识别YES,非连续语音识别NO。默认YES。
//二者区别是：非连续语音识别只在语音结束后返回一个识别结果；
//          连续语音识别是录音过程中持续返回结果。
+ (void) setIsContinuous:(BOOL)isContinuous;


//  设置提示录音太短的时间阈值，比如在调用识别之后，在interavl时间内调用了停止方法，会返回录音太短的错误（ERROR_RECORDER_TOO_SHORT = 14）。
//  默认为3秒。
//  注意：这个值如果大于vad_bos，则不会出现录音太短的错误，会报以未检测到有效声音（ERROR_SPEECH_TIMEOUT = 6）的错误来代替。
+ (void) setRecorderTooShortThreshold:(float)interval;

//当录音达到这个时间长度，且没有有效声音被检测到，则会产生回调，默认2秒
+ (void) setTimeToShowRecordMessage:(float)interval;

+ (void) setProvince:(NSString*)province;
+ (void) setCity:(NSString*)city;
@end
