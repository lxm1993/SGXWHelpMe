//
//  SogouRecognizerPingback.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouRecognizerPingback.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "SogouSpeechRecognizer.h"
#import "SogouSpeechLog.h"
#import "SogouConfig.h"

@implementation SogouRecognizerPingback


- (id)init{
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void)reset{
    self.startTime = nil;
    self.preInterval = -1;
    self.sufInterval = -1;
    self.click = 0;
    self.chosen = 0;
    self.text = nil;
    self.error = -2;
}

- (void)dealloc{
    self.cmd = nil;
    self.startTime = nil;
    self.text = nil;
}

-(NSString*)netType
{
    int networkType = [SogouConfig netType];
    switch (networkType) {
        case 1:
            return @"mobile-1";
        case 2:
            return @"mobile-3";
        case 3:
        case 4:
            return @"mobile-13";
        case 5:
            return @"wifi";
        default:
            return @"unknow";
    }
}

- (void)onEndWithText:(NSString *)text error:(int)error{
    
    NSString *urlStr = @"http://op.speech.sogou.com/index.cgi?";
    SogouSpeechRecognizeUserInfo *info = [SogouSpeechRecognizeUserInfo sharedInstance];
    NSMutableDictionary *urlParams = [NSMutableDictionary dictionaryWithDictionary:@{@"cmd":@"siri_cb",
                                                                                     @"start_time":self.startTime,
                                                                                     @"imei_no":[SogouConfig imei],
                                                                                     @"pre_interval":@(self.preInterval),
                                                                                     @"suf_interval":@(self.sufInterval),
                                                                                     @"net_type":[self netType],
                                                                                     @"click":@(self.click),
                                                                                     @"text":@"",
                                                                                     @"error":@(error),
//                                                                                     @"v":@(info.recognizerVersion),
                                                                                     @"chosen":@(self.chosen),
                                                                                     @"area":@(info.area),
                                                                                     }];

    for (NSString *key in [urlParams allKeys]) {
        urlStr = [urlStr stringByAppendingFormat:@"&%@=%@",key,[urlParams objectForKey:key]];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        //暂且不做重试与错误处理
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        [request setHTTPMethod:@"POST"];
        [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
//        SGLogDebug(@"%@",request);
    });
}
@end
