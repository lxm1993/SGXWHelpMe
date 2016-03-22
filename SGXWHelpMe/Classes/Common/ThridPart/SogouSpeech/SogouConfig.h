//
//  SogouConfig.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#ifndef SGSpeechRecognize4cyou_SogouConfig_h
#define SGSpeechRecognize4cyou_SogouConfig_h

#include "SGLog.h"


#define SogouSpeechRecognizerVersion @"1.0.0"

//used by SGSpeechRecognizer
#define SGRecognizeTimeOut 38

//used by SGRecorder
#define kNumberBuffers           3
#define kSampleRate              16000
#define kBITS_PER_SAMPLE         16
#define kChannel                 1
#define kBufferDurationSeconds   0.3

#define kMinDBvalue -80.0

//used by SGRecognzerHttpRequest
#define SGRecognizeHttpRequest_MaxRetryTime  2
#define SGRecognizeHttpRequest_TimeoutInterval  10

#define SDK_VERSION 7150

//该参数暂时不起作用。
#define RESULT_AMOUNT 5

////定义debug控制台输出
////#define DEBUG_MARX
//#ifdef DEBUG_MARX
//# define DLog(fmt, ...) NSLog((fmt), ##__VA_ARGS__);
//#else
//# define DLog(...);
//#endif

extern SGLogLevel sgLogLevel;

#endif


@interface SogouConfig : NSObject
{
    
}
//获取当前应用的bundleId
+ (NSString *)getBundleId;

//获取网络类型
+ (int)netType;
+(NSString*)netTypeStr;

+ (NSString *)imei;
@end










/** 设置识别引擎的参数
 
 识别的引擎参数(key)取值如下：
 
 1. domain：应用的领域； 取值为iat、at、search、video、poi、music、asr；iat：普通文本听写； search：热词搜索； video：视频音乐搜索； asr：关键词识别;
 2. vad_bos：前端点检测；静音超时时间，即用户多长时间不说话则当做超时处理； 单位：ms； engine指定iat识别默认值为5000； 其他情况默认值为 4000，范围 0-10000。
 3. vad_eos：后断点检测；后端点静音检测时间，即用户停止说话多长时间内即认为不再输入， 自动停止录音；单位:ms，sms 识别默认值为 1800，其他默认值为 700，范围 0-10000。
 4. sample_rate：采样率，目前支持的采样率设置有 16000 和 8000。
 5. asr_ptt：否返回无标点符号文本； 默认为 1，当设置为 0 时，将返回无标点符号文本。
 6. asr_sch：是否需要进行语义处理，默认为0，即不进行语义识别，对于需要使用语义的应用，需要将asr_sch设为1。
 7. result_type：返回结果的数据格式，可设置为json，xml，plain，默认为json。
 8. grammarID：识别的语法 id，只针对 domain 设置为”asr”的应用。
 9. asr_audio_path：音频文件名；设置此参数后，将会自动保存识别的录音文件。路径为Documents/(指定值)。不设置或者设置为nil，则不保存音频。
 10. params：扩展参数，对于一些特殊的参数可在此设置，一般用于设置语义。
 
 11.max_record_interval:设置最长录音长度，单位秒
 12.continuous:、是否连续识别：默认为 0，当设置为 1 时，连续识别
 
 @param key 识别引擎参数
 @param value 参数对应的取值
 
 @return 设置的参数和取值正确返回YES，失败返回NO
 */
//-(BOOL) setParameter:(NSString *) value forKey:(NSString*)key;
