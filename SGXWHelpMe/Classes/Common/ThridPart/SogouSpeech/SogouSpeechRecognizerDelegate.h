//
//  SogouSpeechRecognizerDelegate.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#ifndef SogouSpeechRecognize_SogouSpeechRecognizerDelegate_h
#define SogouSpeechRecognize_SogouSpeechRecognizerDelegate_h



/******************************************
 定义搜狗语音识别错误代码。
 ******************************************/
typedef enum SG_ERROR {
    ERROR_RECORDER_TIMEOUT =1, //=========识别结果在语音结束后(SGRecognizeTimeOut)秒没有返回结果。
    ERROR_NETWORK_STATUS_CODE = 2, //-----网络异常且超重试次数
    ERROR_AUDIO = 3,//====================录音任务错误
    ERROR_SERVER = 4,//-------------------后端服务器错误
    ERROR_CLIENT = 5,//===================客户端错误
    ERROR_SPEECH_TIMEOUT = 6,//-----------未检测到有效语音
    ERROR_NO_MATCH = 7,//=================无解码结果
    ERROR_RECOGNIZER_BUSY = 8,//----------服务器繁忙
    ERROR_INSUFFICIENT_PERMISSIONS=9,//===禁止操作，录音权限不足
    ERROR_PREPROCESS = 10,//--------------预处理任务错误
    ERROR_NETWORK_UNAVAILABLE = 11,//=====网络不可达
    ERROR_NETWORK_PROTOCOL = 12,//--------网络协议错误
    ERROR_NETWORK_IO = 13,//==============网络IO错误
    ERROR_RECORDER_TOO_SHORT = 14,//------录音时间太短
    ERROR_RECORDER_TOO_LONG = 15, //------录音时间太长，超过三十秒（按照错误来处理，后续请求将取消）
    ERROR_UNKNOWN = 100
}SGSPEECH_RECOGNIZE_ERROR;


/******************************************
 设置委托对象：
 ******************************************/
@protocol SogouSpeechRecognizerDelegate<NSObject>

/*
 返回结果时回调
 @param results
 记录识别结果的NSArray，一个由NSString* 构成的数组NSArray。
 @param confidences
 记录识别结果置信度的NSArray，一个由NSString* 构成的数组NSArray。
 @param isLastPart
 标识是否是服务器返回的最后一个结果。
 @param url
 服务器保存的录音地址。
 @param url_valid
 对应的url地址是否有效。
 */
- (void)onResults:(NSArray*)results confidence:(NSArray*)confidences audioURL:(NSString*)url audioURLValid:(BOOL)url_valid isLastPart:(BOOL)isLastPart;

//返回错误时回调
- (void)onError:(NSError*)error;

// 录音结束后回调
- (void)onRecordStop;

@optional
/*
 音量回调，取值[0,100]
 默认以屏幕刷新率进行回调
 */
- (void)onUpdateVolume:(int)volume;

// 当录音达到 [SogouSpeechRecognizeUserInfo sharedInstance].time_to_show_record_message 秒，且没有有效声音，会回调这个方法。
- (void)onRecordTimeAtPoint:(float)time;
@end

#endif
