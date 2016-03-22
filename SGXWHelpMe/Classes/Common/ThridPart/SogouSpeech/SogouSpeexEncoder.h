//
//  SogouSpeexEncoder.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SogouSpeexEncoder : NSObject

@property(nonatomic,strong)NSMutableData* speexData;

@property(nonatomic,strong)NSMutableData *wavData;

@property(nonatomic,copy)NSString* saveSpxPath;

- (id)initWithQuality:(int)quality;

//需要修改，返回值
-(NSMutableData*)encode:(NSData *)rawData isLast:(BOOL)isLast;

- (void)destroyEncoder;

@end
