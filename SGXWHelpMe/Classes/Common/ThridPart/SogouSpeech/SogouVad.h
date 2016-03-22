//
//  SogouVad.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface SogouVad : NSObject

@property(assign, nonatomic)int pack_id;

//是否已经检测出有效声音
@property(nonatomic, assign, readonly)BOOL isVoiced;

//设置是否自动检测语音结束
@property(nonatomic, assign)BOOL isAutoStop;

//设置vad是否有效
@property(nonatomic, assign)BOOL vadEnable;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)recordFormat withHeadInterval:(int)headInterval withTailInterval:(int)tailInterval withMaxWavInterval:(int)recordInterval;
//
////@param result:vad处理后的状态：0表示无处理；1表示检测到语音结束；2表示未检测到有效声音
//- (NSData *)appendVadData:(NSData *)voiceData result:(int *)result;


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
-(NSData*)vadDetect:(NSData* )voiceData status:(int*) status;


- (void)destroy;


@end














//
//
////设置vad后语音最大长度
//- (void)setMaxWavInterval:(int)recordInterval;
//
////设置vad的检测头和尾的时长
////检测有效声音输入结束用，经过tailPackNum时间无有效声音则判定语音结束
////开始检测有效声音时判断的时长，如果超过headUnvoicedPackNum设定值则判定没有有效声音
//- (void)setHeadInterval:(int)headInterval tailInterval:(int)tailInterval;