//
//  SogouSpeechRecognizer.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol SogouSpeechRecognizerDelegate;

@interface SogouSpeechRecognizer : NSObject

//  保存所有已经收到的识别结果。
@property (nonatomic,strong,readonly)NSMutableArray* resultsArray;

//  保存所有已经收到的识别结果对应的置信度（没有在回调函数中体现）。
@property (nonatomic,strong,readonly)NSMutableArray* confidencesArray;

//  响应回调函数的委托类
@property (nonatomic, weak) id<SogouSpeechRecognizerDelegate> recognizeDelegate;

//  是否正在识别
@property (nonatomic, readonly) BOOL isListening;

//  返回识别对象的单例
+ (SogouSpeechRecognizer*) sharedInstance;

//  开始识别，同时只能进行一路会话，这次会话没有结束不能进行下一路会话，否则会报错。若有需要多次回话，请在onError回调返回后请求下一路回话。
- (BOOL) startListening;

//  停止录音,调用此函数会停止录音，并开始进行语音识别
- (void) stopListening;

//  取消本次会话
- (void) cancel;

//  销毁识别对象。
- (BOOL) destroy;

//获取当前音量值,取值[0,100]
-(float)getCurrentVolume;



/** 音频流识别,写入音频流
 
 @param audioData 音频数据
 此方法的使用示例如下:
 [_sogouSpeechRecognizer prepareInputAudioStream];
 [_sogouSpeechRecognizer writeAudio:audioData];
 @return 写入成功返回YES，写入失败返回NO
 写入音频流后，如果未出结果不能再次进行输入，只有等本次结果出现或取消当次识别后才能进行下一次输入。
 */
- (BOOL)prepareInputAudioStream;

- (BOOL) writeAudio:(NSData *) audioData;


@end


