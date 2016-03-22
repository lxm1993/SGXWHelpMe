//
//  SogouRecorder.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>


typedef enum{
    SogouRecorderStopReason_UserOption,
    SogouRecorderStopReason_Error,
    SogouRecorderStopReason_Timesup,
    SogouRecorderStopReason_vadEnd
    
}SogouRecorderStopReason;

//录音协议：需要实现一个按照音频规定格式提供数据的消息方法。
@protocol SogouRecorderDelegate <NSObject>
@optional
-(void)onGetVoiceData:(NSData*)data sampleRate:(int)sampleRate channel:(int)channel;

-(void)recorderWillPrepare;
-(void)recorderDidPrepare;

-(void)recorderWillRecord;
-(void)recorderDidRecord;

-(void)recorderWillStop;
-(void)recorderDidStop:(int)status withError:(int)errCode;



/*
 这个回调函数在执行[- prepareRecord]时被调用，如果实现了该方法，请将AVAudioSession设置的相关代码置于其中，
 此方法的实现会覆盖默认的AVAudioSession设置(默认设置将categroy设置为AVAudioSessionCategoryRecord)。
 @return:是否成功设置了Audio Session
 */
-(BOOL)setAudioSessionWhenPrepare;

@end


@interface SogouRecorder : NSObject
{
    AudioStreamBasicDescription  mRecordFormat;                 // 声音格式设置
    AudioQueueRef                mQueue;                        // 每一块的音频流
    AudioQueueBufferRef          mBuffers[3];      // 内存分块
    AudioFileID                  mRecordFile;                    // 写入的文件ID
    SInt64                       mCurrentPacket;                // 当前读取包索引
    BOOL                         mIsRunning;
    BOOL                         isSaveWav;
    
    OSStatus errorStatus;
}
@property(nonatomic,assign)AudioStreamBasicDescription recordFormat;
@property(nonatomic,assign)BOOL isSaveWav;
@property(nonatomic, copy)NSString* audioPath;

@property(nonatomic,  weak)id<SogouRecorderDelegate> recordDelegate;

@property(nonatomic,assign)Float64 sampleRate; //采样率
@property(nonatomic,assign)UInt32  channels;   //
@property(nonatomic,assign)AudioFormatInfo audioFormat;
@property(nonatomic,assign)UInt32 bitsPerChannel;
@property(nonatomic,assign)float maxRecordInterval;
@property(nonatomic,assign)BOOL isRunning;


-(BOOL) prepareRecord;

-(BOOL) startRecord;

-(void) stopRecordWithReason:(SogouRecorderStopReason)reason;

-(float)currentLevelMeter;

@end




//计算实时的分贝以产生依据声音大小变化数值
@interface MeterTable : NSObject
{
    float	mMinDecibels;
    float	mDecibelResolution;
    float	mScaleFactor;
    float	*mTable;
}

-(id)init;
-(id)initWithData:(float)inMinDecibels size:(size_t)inTableSize root:(float)inRoot;
-(float)valueAt:(float)inDecibels;
-(double)dbToAmp:(double)inDb;

@end
