//
//  SogouRecorder.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouRecorder.h"
#import "SogouSpeechLog.h"
#import "SogouConfig.h"
//#import "SogouSpeechSetting.h"

//typedef enum{
//    SGMRRecorderError_setupAudioFormat,
//    SGMRRecorderError_setAudioSession,
//    SGMRRecorderError_computeRecordBufferSize
//    
//}SGMRRecorderError;


@interface SogouRecorder()
{
    Float64 mSampleRate;
    BOOL mIsFailed;
}

@end


@implementation SogouRecorder
@synthesize isSaveWav = isSaveWav;
@synthesize recordDelegate=_recordDelegate;
@synthesize recordFormat = mRecordFormat;
@synthesize sampleRate = mSampleRate;

@synthesize isRunning = mIsRunning;

extern NSUInteger sgLogLevel;

-(id)init
{
    self = [super init];
    if (self) {
        mIsRunning = false;
        mSampleRate = 16000;
        isSaveWav = NO;
        mIsFailed = NO;
        _maxRecordInterval = 30;
    }
    return  self;
}

-(int) ComputeRecordBufferSize:(const AudioStreamBasicDescription*)format bufferDuration:(float)seconds
{
    SGLogVerbose(@"start computing record buffer sieze");
    int packets, frames, bytes = 0;
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0)
        bytes = frames * format->mBytesPerFrame;
    else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0)
            maxPacketSize = format->mBytesPerPacket;	// constant packet size
        else {
            UInt32 propertySize = sizeof(maxPacketSize);
            errorStatus = AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                                                &propertySize);
            if (errorStatus != noErr) {
                SGLogError(@"ComputeRecordBufferSize error:%d", (int)errorStatus);
                return 0;
            }
        }
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;
        else
            packets = frames;	// worst-case scenario: 1 frame in a packet
        if (packets == 0)		// sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    SGLogDebug(@"Compute Record Buffer Size successfully");
    return bytes;
}

-(void)CopyEncoderCookieToFile
{
    if (!isSaveWav) {
        SGLogVerbose(@"don't save wav audio, needn't set audio queue magic cookie");
        return ;
    }
    SGLogVerbose(@"begin set magic cookie");
    UInt32 propertySize;
    // get the magic cookie, if any, from the converter
    OSStatus err = AudioQueueGetPropertySize(mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    
    // we can get a noErr result and also a propertySize == 0
    // -- if the file format does support magic cookies, but this file doesn't have one.
    if (err == noErr && propertySize > 0) {
        Byte *magicCookie = malloc(sizeof(Byte)*propertySize);
        UInt32 magicCookieSize;
        AudioQueueGetProperty(mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize);
        magicCookieSize = propertySize;	// the converter lies and tell us the wrong size
        
        // now set the magic cookie on the output file
        UInt32 willEatTheCookie = false;
        // the converter wants to give us one; will the file take it?begin computing record buffer sieze
        err = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
        if (err == noErr && willEatTheCookie) {
            err = AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
            if (err) {
                SGLogError(@"audio file set property error,error code = %d",(int)err);
            }
        }
        free(magicCookie);
    }
    SGLogDebug(@"set audio queue magic cookie successfully");
}

-(void) setupAudioFormat
{
    SGLogVerbose(@"set up Audio format");
    memset(&mRecordFormat, 0, sizeof(mRecordFormat));
    mRecordFormat.mFormatID = kAudioFormatLinearPCM;
    mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    mRecordFormat.mSampleRate = mSampleRate;
    mRecordFormat.mChannelsPerFrame = 1;
    mRecordFormat.mBitsPerChannel = kBITS_PER_SAMPLE;
    mRecordFormat.mFramesPerPacket = 1;
    mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8)*mRecordFormat.mChannelsPerFrame;
    mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame * mRecordFormat.mFramesPerPacket;
}//设置音频格式 AudioStreamBasicDescription


static void MyAudioQueueInputCallback(void  *inUserData,
                                      AudioQueueRef inAQ,
                                      AudioQueueBufferRef inBuffer,
                                      const AudioTimeStamp *inStartTime,
                                      UInt32 inNumPackets,
                                      const AudioStreamPacketDescription *inPacketDescs)
{

    SogouRecorder *sgr = (__bridge SogouRecorder*)inUserData;
    if (!sgr->mIsRunning) {
        return;
    }
    SGLogDebug(@"正在录音");
    if (inNumPackets > 0) {
        AudioTimeStamp currentTimeStamp;
        OSStatus currentTimeStatus = AudioQueueGetCurrentTime(inAQ,NULL,&currentTimeStamp,NULL);
        if (currentTimeStatus == noErr && currentTimeStamp.mSampleTime/kSampleRate > sgr.maxRecordInterval) {
            SGLogDebug(@"times up %f seconds",sgr.maxRecordInterval);
            [sgr stopRecordWithReason:SogouRecorderStopReason_Timesup];
            //---------------------------------------------
            //将侦测出超时前的buffer（当前填满的buffer）中的数据取出
            //情况说明：
            if (sgr->isSaveWav) {
                AudioFileWritePackets(sgr->mRecordFile, FALSE, inBuffer->mAudioDataByteSize,inPacketDescs, sgr->mCurrentPacket, &inNumPackets, inBuffer->mAudioData);
            }
            sgr->mCurrentPacket += inNumPackets;
            //读内存里的数据
            if (sgr->_recordDelegate && [sgr->_recordDelegate respondsToSelector:@selector(onGetVoiceData:sampleRate:channel:)]) {
                NSData *voice_data = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
                [sgr->_recordDelegate onGetVoiceData:voice_data sampleRate:sgr->mSampleRate channel:sgr->_channels];
                //            [voice_data release];
            }
            //---------------------------------------------
            
            return;
        }
        
        //写文件到File
        if (sgr->isSaveWav) {
            AudioFileWritePackets(sgr->mRecordFile, FALSE, inBuffer->mAudioDataByteSize,inPacketDescs, sgr->mCurrentPacket, &inNumPackets, inBuffer->mAudioData);
        }
        
        sgr->mCurrentPacket += inNumPackets;
        //读内存里的数据
        if (sgr->_recordDelegate && [sgr->_recordDelegate respondsToSelector:@selector(onGetVoiceData:sampleRate:channel:)]) {
            NSData *voice_data = [[NSData alloc] initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
            [sgr->_recordDelegate onGetVoiceData:voice_data sampleRate:sgr->mSampleRate channel:sgr->_channels];
            //            [voice_data release];
        }
    }
    // 如果继续读取，重新排列的内存块将会再次被装满数据
    if(sgr->mIsRunning == YES){
        OSStatus errorStatus = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
        if (errorStatus) {
            SGLogWarn(@"My input buffer handle error:%d",(int)errorStatus);
        }
    }
}//声明读取包的回调函数 一个内存区域已经被装满 则调用此方法读取装满的内存区域


-(BOOL)setAudioSession{
    SGLogVerbose(@"start set audio session");
    if(self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(setAudioSessionWhenPrepare)]){
        return [self.recordDelegate setAudioSessionWhenPrepare];
    }
    
    AVAudioSession* session = [AVAudioSession sharedInstance];
    BOOL success;
    NSError* error;
    success = [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    if (!success)
    {
        SGLogError(@"AVAudioSession error setting category:%@",error);
        mIsFailed = YES;
        return NO;
    }
    success = [session setActive:YES error:&error];
    if (!success){
        SGLogError(@"AVAudioSession error activating: %@",error);
        mIsFailed = YES;
        return NO;
    }
    SGLogVerbose(@"set audio session successfully");
    return YES;
}

-(BOOL)prepareRecord
{
    SGLogVerbose(@"prepare record audio queue");
    if (self.recordDelegate &&[self.recordDelegate respondsToSelector:@selector(recorderWillPrepare)]) {
        [self.recordDelegate recorderWillPrepare];
    }
    [self setupAudioFormat];
    if (![self setAudioSession]) {
        SGLogError(@"setting audio session occur error");
        mIsFailed = YES;
        return NO;
    };
    errorStatus = AudioQueueNewInput(
                                     &mRecordFormat,
                                     MyAudioQueueInputCallback,
                                     (__bridge void *)(self) /* userData */,
                                     NULL /* run loop */, NULL /* run loop mode */,
                                     0 /* flags */, &mQueue);
    if (errorStatus) {
        SGLogError(@"Prepare record error:%d when AudioQueueNewInput ",(int) errorStatus);
        mIsFailed = YES;
        return NO;
    }
    mCurrentPacket = 0;
    int i ,bufferByteSize;
    UInt32 size;
    
    size = sizeof(mRecordFormat);
    errorStatus = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription,
                                        &mRecordFormat, &size);
    if (errorStatus) {
        SGLogError(@"Prepare record error:%d when AudioQueueGetProperty StreamDescription", (int)errorStatus);
        mIsFailed = YES;
        return NO;
    }
    UInt32 val = 1;
    errorStatus = AudioQueueSetProperty(mQueue, kAudioQueueProperty_EnableLevelMetering, &val, sizeof(UInt32));
    if (errorStatus) {
        SGLogError(@"Prepare record error:%d when AudioQueueGetProperty StreamDescription", (int)errorStatus);
        mIsFailed = YES;
        return NO;
    }
    
    bufferByteSize =[self ComputeRecordBufferSize:&mRecordFormat bufferDuration:kBufferDurationSeconds];
    for (i = 0; i < kNumberBuffers; ++i) {
        errorStatus = AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]);
        if (errorStatus) {
            SGLogError(@"Prepare record error:%d alloc and enqueue buffer", (int)errorStatus);
            mIsFailed = YES;
            return NO;
        }
        errorStatus = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
        if (errorStatus) {
            SGLogError(@"Prepare record error:%d alloc and enqueue buffer", (int)errorStatus);
            mIsFailed = YES;
            return NO;
        }
    }
    
    if (isSaveWav) {
        CFStringRef fileNameEscaped = nil;
        if (self.audioPath == nil) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            //zzz表示时区，zzz可以删除，这样返回的日期字符将不包含时区信息。
            [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
            NSString *destDateString = [dateFormatter stringFromDate:[NSDate date]];
            NSString *recordFile = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.wav",destDateString]];
            fileNameEscaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)recordFile, NULL, NULL, kCFStringEncodingUTF8);
            
            
        }else{
            fileNameEscaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)self.audioPath, NULL, NULL, kCFStringEncodingUTF8);
        }
        
        CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)fileNameEscaped, NULL);

        // create the audio file
        OSStatus status = AudioFileCreateWithURL(url, kAudioFileCAFType, &mRecordFormat, kAudioFileFlags_EraseFile, &mRecordFile);
        if (status != noErr) {
            SGLogWarn(@"AudioFileCreateWithURL failed");
        }
        CFRelease(url);
        CFRelease(fileNameEscaped);
        
        [self CopyEncoderCookieToFile];
    }
    
    if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(recorderDidPrepare)]) {
        [self.recordDelegate recorderDidPrepare];
    }
    SGLogVerbose(@"prepared record audio queue successfully");
    return YES;
}

-(BOOL)startRecord
{
    // start the queue
    if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(recorderWillRecord)]) {
        [self.recordDelegate recorderWillRecord];
    }
    SGLogDebug(@"录音开始");
    mIsRunning = true;
    errorStatus = AudioQueueStart(mQueue, NULL);
    if (errorStatus != noErr) {
        SGLogError(@"audio queue start error");
        mIsFailed = YES;
        return NO;
    }else{
        if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(recorderDidRecord)]) {
            [self.recordDelegate recorderDidRecord];
        }
        return YES;
    }
}
 

-(void)stopRecordWithReason:(SogouRecorderStopReason)reason
{
    if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(recorderWillStop)]) {
        [self.recordDelegate recorderWillStop];
    }
    mIsRunning = false;
    AudioQueueStop(mQueue, true);
    [self CopyEncoderCookieToFile];
    AudioQueueDispose(mQueue, true);
    AudioFileClose(mRecordFile);
    if (reason == SogouRecorderStopReason_Timesup) {
        SGLogDebug(@"达到设定录音设定长度,结束录音");
    }else
        SGLogDebug(@"结束录音");
    
    if (self.recordDelegate && [self.recordDelegate respondsToSelector:@selector(recorderDidStop:withError:)]) {
        [self.recordDelegate recorderDidStop:reason withError:0];
    }
}

-(float)currentLevelMeter
{
    if (mIsRunning) {
        static AudioQueueLevelMeterState	*chan_lvls;
        static UInt32 data_sz = sizeof(AudioQueueLevelMeterState) * 2;
        static dispatch_once_t onceToken;
        static MeterTable *meterT;
        dispatch_once(&onceToken, ^{
            chan_lvls = (AudioQueueLevelMeterState*)realloc(chan_lvls, 2 * sizeof(AudioQueueLevelMeterState));
            meterT = [[MeterTable alloc]initWithData:kMinDBvalue size:400 root:2.0];
        });
        
        OSErr status = AudioQueueGetProperty(mQueue, kAudioQueueProperty_CurrentLevelMeterDB, chan_lvls, &data_sz);
        if (status == noErr) {
            float result = [meterT valueAt:(float)(chan_lvls[0].mAveragePower)];
            return result;
        }else
        {
            SGLogError(@"LevelMeterDB error");
        }
    }
    return  0;
}

@end


@implementation MeterTable

-(id)init
{
    return [self initWithData:-80.0 size:400 root:2.0];
}

-(id)initWithData:(float)inMinDecibels size:(size_t)inTableSize root:(float)inRoot
{
    self = [super init];
    if (self) {
        mMinDecibels=inMinDecibels;
        mDecibelResolution=mMinDecibels / (inTableSize - 1);
        mScaleFactor=1. / mDecibelResolution;
        if (inMinDecibels >= 0.)
        {
            SGLogError(@"MeterTable inMinDecibels must be negative");
            return nil;
        }
        
        mTable = (float*)malloc(inTableSize*sizeof(float));
        
        double minAmp = [self dbToAmp:inMinDecibels];
        double ampRange = 1. - minAmp;
        double invAmpRange = 1. / ampRange;
        
        double rroot = 1. / inRoot;
        for (size_t i = 0; i < inTableSize; ++i) {
            double decibels = i * mDecibelResolution;
            double amp = [self dbToAmp:decibels];
            double adjAmp = (amp - minAmp) * invAmpRange;
            mTable[i] = pow(adjAmp, rroot);
        }
    }
    return self;
}

-(float)valueAt:(float)inDecibels
{
    if (inDecibels < mMinDecibels) return  0.;
    if (inDecibels >= 0.) return 1.;
    int index = (int)(inDecibels * mScaleFactor);
    return mTable[index];
}

-(double)dbToAmp:(double)inDb
{
    return pow(10., 0.05 * inDb);
}

-(void)dealloc
{
    free(mTable);
}

@end


