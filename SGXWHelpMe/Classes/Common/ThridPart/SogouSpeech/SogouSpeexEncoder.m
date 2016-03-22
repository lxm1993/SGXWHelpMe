//
//  SogouSpeexEncoder.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouSpeexEncoder.h"
//#import "Speex.framework/Headers/speex.h"
#import "speex.h"
#import "SogouSpeechLog.h"
#import "SogouConfig.h"

#define FRAME_SIZE 320   //音频8khz*20ms/16khz*20ms -> 8000*0.02=160/16000*0.02=320
#define MAX_NB_BYTES 200 //被写入已编码的帧的指针的可被写入的最大字节数 200
#define QUALITY 7  //压缩质量 4/7

@interface SogouSpeexEncoder ()
{
    short speech[FRAME_SIZE]; //数据缓存
    short encodeShort[FRAME_SIZE];  //指向每个speex帧开始的short型指针
    char speexFrame[MAX_NB_BYTES];//即将被写入已被编码的帧的char型指针
    void * encode_state;
    SpeexBits bits;
    BOOL isCreatedFile;
}

@end

@implementation SogouSpeexEncoder

//每一个音频应该保证只有一个speex_encoder_init
- (id)init{
    return [self initWithQuality:QUALITY];
}

- (instancetype)initWithQuality:(int)quality{
    if (self= [super init]) {
        SGLogDebug(@"speex encoder init with quality=%d",quality);
        speex_bits_init(&bits);
        encode_state = speex_encoder_init(&speex_wb_mode);
        int qua = quality;
        speex_encoder_ctl(encode_state, SPEEX_SET_QUALITY, &qua);
        int complexity = 3;
        speex_encoder_ctl(encode_state, SPEEX_SET_COMPLEXITY, &complexity);
        _wavData = [NSMutableData data];
        _saveSpxPath = nil;
        isCreatedFile = NO;
    }
    return self;
}

//共用一个speex_encoder_init，因为压缩数据上下文相关，否则压缩后数据失真。
-(NSMutableData*)encode:(NSData *)rawData isLast:(BOOL)isLast
{
    SGLogDebug(@"%@",(isLast?@"encode last piece of wav data":@"encode middle piece of wav data"));
    [self.wavData appendData:rawData];
    if (isLast) {
        @autoreleasepool {
            if ([self.wavData length]>0) {
                NSMutableData *result = [NSMutableData data];
                while (1) {
                    if (sizeof(short)*FRAME_SIZE > [self.wavData length]) {
                        memset(speech, 0, FRAME_SIZE);
                        [self.wavData getBytes:speech range:NSMakeRange(0, [self.wavData length])];
                        [self.wavData replaceBytesInRange:NSMakeRange(0, [self.wavData length]) withBytes:NULL length:0];
                        speex_bits_reset(&bits);
                        speex_encode_int(encode_state, speech, &bits);
                        int byte_counter=0;
                        byte_counter = speex_bits_write(&bits, speexFrame, MAX_NB_BYTES);
                        [self.speexData appendBytes:speexFrame length:byte_counter];
                        [result appendBytes:speexFrame length:byte_counter];
                        break;
                    }else
                    {
                        [self.wavData getBytes:speech range:NSMakeRange(0, sizeof(short)*FRAME_SIZE)];
                        [self.wavData replaceBytesInRange:NSMakeRange(0, sizeof(short)*FRAME_SIZE) withBytes:NULL length:0];
                        
                        speex_bits_reset(&bits);
                        speex_encode_int(encode_state, speech, &bits);
                        int byte_counter = speex_bits_write(&bits, speexFrame, MAX_NB_BYTES);
                        [self.speexData appendBytes:speexFrame length:byte_counter];
                        [result appendBytes:speexFrame length:byte_counter];
                    }
                    
                }
                [self saveSpxToFile:result];
                return result;
            }else
            {
                SGLogVerbose(@"encode return none data at this piece");
                return nil;
            }

        }
    }
    else
    {
        @autoreleasepool {
            int byte_counter=0;
            if ([self.wavData length]>0) {
                NSMutableData *result = [NSMutableData data];
                while (1) {
                    if (sizeof(short)*FRAME_SIZE > [self.wavData length]) {
                        break;
                    }
                    [self.wavData getBytes:speech range:NSMakeRange(0, sizeof(short)*FRAME_SIZE)];
                    [self.wavData replaceBytesInRange:NSMakeRange(0, sizeof(short)*FRAME_SIZE) withBytes:NULL length:0];
                    
                    speex_bits_reset(&bits);
                    speex_encode_int(encode_state, speech, &bits);
                    byte_counter = speex_bits_write(&bits, speexFrame, MAX_NB_BYTES);
                    [self.speexData appendBytes:speexFrame length:byte_counter];
                    
                    [result appendBytes:speexFrame length:byte_counter];
                }
                [self saveSpxToFile:result];
                return result;
            }
        }
    }
    self.wavData = nil;
    SGLogVerbose(@"encode return none data at this piece");
    return nil;
}


-(void)saveSpxToFile:(NSData*)data
{
    if (self.saveSpxPath == nil) {
//        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//        [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
//        NSDate * dataBuffer = [NSDate dateWithTimeIntervalSince1970:[self.requestStartTime doubleValue]/1000.0f];
//        NSString *destDateString = [dateFormatter stringFromDate:dataBuffer];
//        [dateFormatter release];
//        recordFile = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.spx",destDateString]];
        return;
    }
    if (isCreatedFile == NO) {//如果本次压缩没有创建保存spx文件
        if ([[NSFileManager defaultManager]fileExistsAtPath:self.saveSpxPath]) {//删除上一次压缩保留的spx重名文件
            NSError *error;
            [[NSFileManager defaultManager]removeItemAtPath:self.saveSpxPath error:&error];
            if (error!=noErr) {
                SGLogError(@"remove file for last one saving speex data failed. please ensure the file path right");
                return;
            }
        }
        isCreatedFile = [[NSFileManager defaultManager] createFileAtPath:self.saveSpxPath contents:nil attributes:nil] ;
        if (isCreatedFile == NO) {
            SGLogError(@"create file for saving speex data failed. please ensure the file path right");
            return;
        }
    }
    if (data != nil) {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.saveSpxPath];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];
        [fileHandle closeFile];
    }

}

//-(void)saveSpxToFile:(NSData*)data
//{
//    if (self.saveSpxPath == nil) {
//        //        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//        //        [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
//        //        NSDate * dataBuffer = [NSDate dateWithTimeIntervalSince1970:[self.requestStartTime doubleValue]/1000.0f];
//        //        NSString *destDateString = [dateFormatter stringFromDate:dataBuffer];
//        //        [dateFormatter release];
//        //        recordFile = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.spx",destDateString]];
//        NSLog(@"没有spx数据，返回");
//        return;
//    }
//    if (isCreatedFile == NO) {//如果本次压缩没有创建保存spx文件
//        if ([[NSFileManager defaultManager]fileExistsAtPath:self.saveSpxPath]) {//删除上一次压缩保留的spx重名文件
//            NSError *error;
//            [[NSFileManager defaultManager]removeItemAtPath:self.saveSpxPath error:&error];
//            NSLog(@"删除上次的数据");
//            if (error!=noErr) {
//                SGLogError(@"remove file for last one saving speex data failed. please ensure the file path right");
//                NSLog(@"删除上次的数据出错，返回");
//                return;
//            }
//        }
//        isCreatedFile = [[NSFileManager defaultManager] createFileAtPath:self.saveSpxPath contents:nil attributes:nil] ;
//        NSLog(@"创建文件");
//        if (isCreatedFile == NO) {
//            SGLogError(@"create file for saving speex data failed. please ensure the file path right");
//            NSLog(@"创建文件出错，返回");
//            return;
//        }
//    }
//    if (data != nil) {
//        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:self.saveSpxPath];
//        [fileHandle seekToEndOfFile];
//        [fileHandle writeData:data];
//        [fileHandle closeFile];
//        NSLog(@"保存数据");
//    }else
//        NSLog(@"没有数据要保存");
//    
//}

-(void)destroyEncoder
{
    SGLogDebug(@"destroy speex encoder");
    speex_bits_destroy(&bits);
    speex_encoder_destroy(encode_state);
}
-(void)dealloc
{
    [self destroyEncoder];
}
@end
