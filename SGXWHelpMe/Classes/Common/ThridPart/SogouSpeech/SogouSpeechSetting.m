//
//  SogouSpeechSetting.m
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import "SogouSpeechSetting.h"
#import "SogouConfig.h"
#import "SogouSpeechLog.h"

#pragma implement the delegate SGLogFormatter
@interface Formatter : NSObject<SGLogFormatter>

@end

@interface Formatter ()

@property (nonatomic, strong) NSDateFormatter *threadUnsafeDateFormatter;   // for date/time formatting

@end


@implementation Formatter

- (id)init {
    if (self = [super init]) {
        _threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
        [_threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [_threadUnsafeDateFormatter setDateFormat:@"HH:mm:ss.SSS"];
    }
    
    return self;
}

- (NSString *)formatLogMessage:(SGLogMessage *)logMessage {
    NSString *dateAndTime = [self.threadUnsafeDateFormatter stringFromDate:(logMessage->timestamp)];
    
    NSString *logLevel = nil;
    switch (logMessage->logFlag) {
        case SGLogFlagError     : logLevel = @"E"; break;
        case SGLogFlagWarning   : logLevel = @"W"; break;
        case SGLogFlagInfo      : logLevel = @"I"; break;
        case SGLogFlagDebug     : logLevel = @"D"; break;
        case SGLogFlagVerbose   : logLevel = @"V"; break;
        default                 : logLevel = @"?"; break;
    }
    
    NSString *formattedLog = [NSString stringWithFormat:@"%@ |%@| [%@ %@] #%d: %@",
                              dateAndTime,
                              logLevel,
                              logMessage.fileName,
                              logMessage.methodName,
                              logMessage->lineNumber,
                              logMessage->logMsg];
    
    return formattedLog;
}

@end


@implementation SogouSpeechSetting

static bool isShowLogcat = NO;
static bool isSaveLog = NO;

+ (NSString *) getSpeechRecognizeVersion
{
    return SogouSpeechRecognizerVersion;
}

+ (SOGOU_SPEECH_LOG_LEVEL) logLvl
{
    return sgLogLevel;
}

+ (void) showLogcat:(BOOL) showLog
{
    isShowLogcat = showLog;
    if(isShowLogcat){
        Formatter *formatter = [[Formatter alloc] init];
        [[SGTTYLogger sharedInstance] setLogFormatter:formatter];
        [SGLog addLogger:[SGTTYLogger sharedInstance]];
    }
}

+ (void) setLogLevel:(SOGOU_SPEECH_LOG_LEVEL) level
{
    sgLogLevel = level;
}

+(void) saveLogToFile:(BOOL)saveLog
{
    isSaveLog = saveLog;
    if (isSaveLog) {
        SGFileLogger *fileLogger = [[SGFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        [SGLog addLogger:fileLogger];
    }
}

///** 设置日志文件的路径
// 日志文件默认存放在Documents目录。
// @param   path    -[in] 日志文件的全路径
// */
//+ (void) setLogFilePath:(NSString*) path
//{
//    SGFileLogger *fileLogger = [[SGFileLogger alloc] init];
//    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
//    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
//    [SGLog addLogger:fileLogger];
//}


///** 设置日志文件的路径
//
// 日志文件默认存放在Documents目录。
//
// @param   path    -[in] 日志文件的全路径
// */
//+ (void) setLogFilePath:(NSString*) path;


@end
