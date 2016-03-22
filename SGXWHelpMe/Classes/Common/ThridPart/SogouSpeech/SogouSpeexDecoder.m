//
//  SogouSpeexDecoder.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouSpeexDecoder.h"
#import "speex.h"
#import "speex_header.h"

#define FRAME_SIZE_DECODER 320

typedef struct
{
    char chChunkID[4];
    int nChunkSize;
}XCHUNKHEADER;

typedef struct
{
    short nFormatTag;
    short nChannels;
    int nSamplesPerSec;
    int nAvgBytesPerSec;
    short nBlockAlign;
    short nBitsPerSample;
}WAVEFORMAT;

typedef struct
{
    short nFormatTag;
    short nChannels;
    int nSamplesPerSec;
    int nAvgBytesPerSec;
    short nBlockAlign;
    short nBitsPerSample;
    short nExSize;
}WAVEFORMATX;

typedef struct
{
    char chRiffID[4];
    int nRiffSize;
    char chRiffFormat[4];
}RIFFHEADER;

typedef struct
{
    char chFmtID[4];
    int nFmtSize;
    WAVEFORMAT wf;
}FMTBLOCK;
//
typedef unsigned long long u64;
typedef long long s64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

u16 readUInt16(char* bis) {
    u16 result = 0;
    result += ((u16)(bis[0])) << 8;
    result += (u8)(bis[1]);
    return result;
}

u32 readUint32(char* bis) {
    u32 result = 0;
    result += ((u32) readUInt16(bis)) << 16;
    bis+=2;
    result += readUInt16(bis);
    return result;
}

s64 readSint64(char* bis) {
    s64 result = 0;
    result += ((u64) readUint32(bis)) << 32;
    bis+=4;
    result += readUint32(bis);
    return result;
}

@implementation SogouSpeexDecoder

void WriteWAVEHeader(NSMutableData* fpwave, int nFrame)
{
    char tag[10] = "";
    
    // 1. 写RIFF头
    RIFFHEADER riff;
    strcpy(tag, "RIFF");
    memcpy(riff.chRiffID, tag, 4);
    riff.nRiffSize = 4             // WAVE
    + sizeof(XCHUNKHEADER)         // fmt
    + sizeof(WAVEFORMATX)          // WAVEFORMATX
    + sizeof(XCHUNKHEADER)         // DATA
    + nFrame*320*sizeof(short);    //
    strcpy(tag, "WAVE");
    memcpy(riff.chRiffFormat, tag, 4);
    [fpwave appendBytes:&riff length:sizeof(RIFFHEADER)];
    
    // 2. 写FMT块
    XCHUNKHEADER chunk;
    WAVEFORMATX wfx;
    strcpy(tag, "fmt ");
    memcpy(chunk.chChunkID, tag, 4);
    chunk.nChunkSize = sizeof(WAVEFORMATX);
    [fpwave appendBytes:&chunk length:sizeof(XCHUNKHEADER)];
    memset(&wfx, 0, sizeof(WAVEFORMATX));
    wfx.nFormatTag = 1;
    wfx.nChannels = 1;          // 单声道
    wfx.nSamplesPerSec = 16000; // 16khz
    wfx.nAvgBytesPerSec = 16000;
    wfx.nBlockAlign = 2;
    wfx.nBitsPerSample = 16;    // 16位
    [fpwave appendBytes:&wfx length:sizeof(WAVEFORMATX)];
    
    // 3. 写data块头
    strcpy(tag, "data");
    memcpy(chunk.chChunkID, tag, 4);
    chunk.nChunkSize = nFrame*320*sizeof(short);
    [fpwave appendBytes:&chunk length:sizeof(XCHUNKHEADER)];
    
}

+(NSData*)DecodeSpeexToWAVE:(NSData *)data
{
    int dec_frame_size = 60;//重要参数
    char decode_array[dec_frame_size];
    short output[FRAME_SIZE_DECODER];
    short soutput[FRAME_SIZE_DECODER];
    int ret;
    SpeexBits dbits;
    speex_bits_init(&dbits);
    void *dec_state;
    dec_state = speex_decoder_init(&speex_wb_mode);
    //speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
    char *buf = (char *)[data bytes];
    int maxLen = [data length];
    int currentLen = 0;
    int frames = 0;
    NSMutableData *PCMRawData = [NSMutableData data];
    while (1)
    {
        if (currentLen >= maxLen)
        {
            break;
        }
        memcpy(decode_array, buf, dec_frame_size);
        currentLen += dec_frame_size;
        buf = buf + dec_frame_size;
        speex_bits_reset(&dbits);
        
        speex_bits_read_from(&dbits, decode_array, dec_frame_size);
        
        ret = speex_decode_int(dec_state, &dbits, output);
        
        for (int i = 0; i < FRAME_SIZE_DECODER; i++) {
            soutput[i] = output[i];
        }
        
        [PCMRawData appendBytes:soutput length:sizeof(short)*FRAME_SIZE_DECODER];
        frames++;
    }
    
    speex_bits_destroy(&dbits);
    speex_decoder_destroy(dec_state);
    
    
    NSMutableData *outData = [NSMutableData data];
    WriteWAVEHeader(outData, frames);
    [outData appendData:PCMRawData];
    return outData;
}

@end
