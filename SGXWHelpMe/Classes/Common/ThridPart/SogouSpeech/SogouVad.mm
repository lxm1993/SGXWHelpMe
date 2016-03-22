//
//  SogouVad.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouVad.h"

#import "detectvadres.h"
#import "vad.h"

#import "SogouSpeechLog.h"
#import "SogouConfig.h"

#define MAX_LEN		        256
#define WIN_SIZE            400
#define SHIFT_SIZE          160
#define SHORT_LEN	        2048
#define PRE_RESERVE_LEN     8000

#define THRES_02            2.2
#define THRES_24            2.5
#define THRES_46            3.0
#define THRES_68            4.0
#define FFT_SIZE            512
#define SAMPLE_RATE	        16000
#define CHANNEL_NUM	        1

//#define MAX_BEGIN_WAIT_TIME 3.0
//#define MAX_END_WAIT_TIME   1.0

@interface SogouVad (){

    Client_Vad *_client_vad;
    CVadRes _vad_result;
    
    //检测有效声音输入结束用，经过tailPackNum时间无有效声音则判定语音结束
    float _tailUnvoicedPackNum;
    //开始检测有效声音时判断的时长，如果超过headUnvoicedPackNum设定值则判定没有有效声音
    float _headUnvoicedPackNum;
}
//@property(nonatomic, strong)NSString* fileName;

@end

@implementation SogouVad


-(void)destroy
{
    SGLogDebug(@"vad destroy");
    delete _client_vad;
//    deleteDetectwav(wavVadDetector);
//    wavVadDetector = NULL;
}

-(instancetype)initWithFormat:(AudioStreamBasicDescription)recordFormat withHeadInterval:(int)headInterval withTailInterval:(int)tailInterval withMaxWavInterval:(int)recordInterval{
    self = [super init];
    if(self){
        SGLogVerbose(@"vad init with header=%d, tail=%d, recordLong=%d",headInterval,tailInterval,recordInterval);
        _tailUnvoicedPackNum = (float)tailInterval / 1000.0;
        _headUnvoicedPackNum = (float)headInterval /1000.0;

        
        _vad_result = new CVadRes();
        _pack_id = 0;
        _client_vad = new Client_Vad(  SAMPLE_RATE,            // sampling frequency
                                     WIN_SIZE,               // window size
                                     SHIFT_SIZE,             // shift size
                                     SHORT_LEN,              // packet length
                                     PRE_RESERVE_LEN,        // previous reserve length
                                     0.8,                    // alfa_ff
                                     0.995,                  // alfa_sf
                                     0.96,                   // beta_sf
                                     0.99,                   // alfa_snr
                                     THRES_02,               // threshold from 0kHz to 2kHz
                                     THRES_24,               // threshold from 2kHz to 4kHz
                                     THRES_46,               // threshold from 4kHz to 6kHz
                                     THRES_68,               // threshold from 6kHz to 8kHz
                                     FFT_SIZE,               // fft size
                                     8                       // freq_win_len
                                     );
        _isAutoStop = YES;
        _isVoiced = NO;
        
//        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//        [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
//        NSString *destDateString = [dateFormatter stringFromDate:[NSDate date]];
//        self.fileName = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.log",destDateString]];
    }
    return self;
}


-(NSData*)vadDetect:(NSData *)voiceData status:(int *)status
{
    @autoreleasepool {
        SGLogDebug(@"put voice data into vad system，vad检测中");
        if ([voiceData length] > 0) {
            @try {
                int src_len = (int)[voiceData length] / 2;
                short *src_data = (short*)malloc(sizeof(short)*src_len);
                
                short y_raw[PRE_RESERVE_LEN+SHORT_LEN] = { 0 };
                int len;
                
                _pack_id ++;
                [voiceData getBytes:src_data length:src_len * 2];
                _client_vad->detect_speech(src_data, (int)src_len, _pack_id, _vad_result);
                
                
//                NSData* dddd = [NSData dataWithBytes:src_data length:src_len*2];
//                //
//                [self saveLogToFile:dddd];
                
//                SGLogVerbose(@"is speech = %d", _vad_result.m_is_speech);
                free(src_data);
                
                
                
                if ( _vad_result.m_is_speech_found ) // speech has already be detected
                {
                    if ( _vad_result.m_is_speech )   // current segment in speech
                    {
                        if ( _vad_result.m_is_first_found )
                        {
                            _client_vad->output_pre_speech( y_raw, len );
                            NSMutableData* vadData = [NSMutableData dataWithBytes:y_raw length:len*2];
                            _client_vad->output_speech( y_raw, len );
                            [vadData appendBytes:y_raw length:len*2];
                            *status = 1;//开始
                            return vadData;
                        }
                        
                        _client_vad->output_speech( y_raw, len );
                        NSMutableData* vadData = [NSMutableData dataWithBytes:y_raw length:len*2];
                        *status = 2;//有效声音
                        return vadData;
                    }
                    else
                    {
                        if (  _vad_result.m_end_wait_time < _tailUnvoicedPackNum  )
                        {
                            _client_vad->output_speech( y_raw, len );
                            NSData * vadData = [NSData dataWithBytes:y_raw length:len*2];
                            *status = 2;//有效
                            return vadData;
                        }
                        else
                        {
                            *status = 3;//录音结束
                            return nil;
                        }
                    }
                }
                else    // speech has not been detected yet
                {
                    if ( _vad_result.m_begin_wait_time <  _headUnvoicedPackNum)
                    {
                        // go on detecting
                        _vad_result.m_begin_wait_time += src_len / 16000.0;
                        *status = 0;//检测中,继续检测
                        return nil;
                    }
                    else
                    {
                        *status = 4;//无有效声音
                        return nil;
                    }
                }
            }
            @catch (NSException *exception) {
                *status = -1;
                return nil;
            }
        }
        else
        {
            *status = -1;
            return nil;
        }
    }
}


//-(void)saveLogToFile:(NSData*)data
//{
//    if (![[NSFileManager defaultManager]fileExistsAtPath:self.fileName]) {//删除上一次压缩保留的spx重名文件
//        [[NSFileManager defaultManager] createFileAtPath:self.fileName contents:nil attributes:nil];
//    }
//    
//    if (data != nil) {
//        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.fileName];
//        [fileHandle seekToEndOfFile];
//        [fileHandle writeData:data];
//        [fileHandle closeFile];
//    }
//}

@end
