//
//  SogouSpeechSetting.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 日志打印等级
 */
typedef NS_ENUM(NSUInteger, SOGOU_SPEECH_LOG_LEVEL) {
    SG_LOG_LVL_OFF       = 0,
    SG_LOG_LVL_Error     = 1,          // 0...00001
    SG_LOG_LVL_Warning   = 3,          // 0...00011
    SG_LOG_LVL_Info      = 7,          // 0...00111
    SG_LOG_LVL_Debug     = 15,         // 0...01111
    SG_LOG_LVL_Verbose   = 31,         // 0...11111
    SG_LOG_LVL_All       = NSUIntegerMax  // 1111....11111
};


@interface SogouSpeechSetting : NSObject

/** 获取版本号
 @return 版本号
 */
+ (NSString *) getSpeechRecognizeVersion;

/** 获取日志等级
 @return  返回日志等级
 */
+ (SOGOU_SPEECH_LOG_LEVEL) logLvl;


/** 是否打印控制台log
 在软件发布时，建议关闭此log。
 @param   showLog         -[in] YES,打印log;NO,不打印
 */
+ (void) showLogcat:(BOOL) showLog;

/**
 设置日志生成路径以及日志等级
 @param   level            -[in] 日志打印等级
 */
+ (void) setLogLevel:(SOGOU_SPEECH_LOG_LEVEL) level;

/**
 设置是否保存log到文件
 @param   saveLog         -[in] YES,保存log;NO,不保存
 */
+ (void) saveLogToFile:(BOOL)saveLog;





@end
