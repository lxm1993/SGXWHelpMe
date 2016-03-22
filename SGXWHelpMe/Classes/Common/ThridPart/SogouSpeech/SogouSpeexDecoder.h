//
//  SogouSpeexDecoder.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SogouSpeexDecoder : NSObject

+(NSData*)DecodeSpeexToWAVE:(NSData *)data;

@end
