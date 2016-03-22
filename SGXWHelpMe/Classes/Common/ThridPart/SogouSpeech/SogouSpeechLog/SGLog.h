// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2014, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

#import <Foundation/Foundation.h>

@class SGLogMessage;

@protocol SGLogger;
@protocol SGLogFormatter;

/**
 * This is the single macro that all other macros below compile into.
 * This big multiline macro makes all the other macros easier to read.
 **/

#define SG_LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, fnct, frmt, ...) \
    [SGLog log : isAsynchronous                                         \
         level : lvl                                                    \
          flag : flg                                                    \
       context : ctx                                                    \
          file : __FILE__                                               \
      function : fnct                                                   \
          line : __LINE__                                               \
           tag : atag                                                   \
        format : (frmt), ## __VA_ARGS__]

/**
 * Define the Objective-C and C versions of the macro.
 * These automatically inject the proper function name for either an objective-c method or c function.
 *
 * We also define shorthand versions for asynchronous and synchronous logging.
 **/

#define SG_LOG_OBJC_MACRO(async, lvl, flg, ctx, frmt, ...) \
             SG_LOG_MACRO(async, lvl, flg, ctx, nil, __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)

#define SG_SYNC_SG_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
         SG_LOG_OBJC_MACRO(NO, lvl, flg, ctx, frmt, ## __VA_ARGS__)

#define SG_ASG_SYNC_SG_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
         SG_LOG_OBJC_MACRO(YES, lvl, flg, ctx, frmt, ## __VA_ARGS__)

/**
 * Define version of the macro that only execute if the logLevel is above the threshold.
 * The compiled versions essentially look like this:
 *
 * if (logFlagForThisLogMsg & SGLogLevel) { execute log message }
 *
 * When SG_LOG_LEVEL_DEF is defined as SGLogLevel.
 *
 * As shown further below, Lumberjack actually uses a bitmask as opposed to primitive log levels.
 * This allows for a great amount of flexibility and some pretty advanced fine grained logging techniques.
 *
 * Note that when compiler optimizations are enabled (as they are for your release builds),
 * the log messages above your logging threshold will automatically be compiled out.
 *
 * (If the compiler sees SG_LOG_LEVEL_DEF/SGLogLevel declared as a constant, the compiler simply checks to see
 *  if the 'if' statement would execute, and if not it strips it from the binary.)
 *
 * We also define shorthand versions for asynchronous and synchronous logging.
 **/

#define SG_LOG_MAYBE(async, lvl, flg, ctx, fnct, frmt, ...)                       \
    do { if(lvl & flg) SG_LOG_MACRO(async, lvl, flg, ctx, nil, fnct, frmt, ##__VA_ARGS__); } while(0)

#define SG_LOG_OBJC_MAYBE(async, lvl, flg, ctx, frmt, ...) \
             SG_LOG_MAYBE(async, lvl, flg, ctx, __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)

#define SG_SYNC_SG_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
         SG_LOG_OBJC_MAYBE(NO, lvl, flg, ctx, frmt, ## __VA_ARGS__)

#define SG_ASG_SYNC_SG_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
         SG_LOG_OBJC_MAYBE(YES, lvl, flg, ctx, frmt, ## __VA_ARGS__)

/**
 * Define versions of the macros that also accept tags.
 *
 * The SGLogMessage object includes a 'tag' ivar that may be used for a variety of purposes.
 * It may be used to pass custom information to loggers or formatters.
 * Or it may be used by 3rd party extensions to the framework.
 *
 * Thes macros just make it a little easier to extend logging functionality.
 **/

#define SG_LOG_OBJC_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, ...) \
                 SG_LOG_MACRO(async, lvl, flg, ctx, tag, __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)

#define SG_LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, fnct, frmt, ...)              \
    do { if(lvl & flg) SG_LOG_MACRO(async, lvl, flg, ctx, tag, fnct, frmt, ##__VA_ARGS__); } while(0)

#define SG_LOG_OBJC_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, ...) \
             SG_LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, __PRETTY_FUNCTION__, frmt, ## __VA_ARGS__)

/**
 * Define the standard options.
 *
 * We default to only 4 levels because it makes it easier for beginners
 * to make the transition to a logging framework.
 *
 * More advanced users may choose to completely customize the levels (and level names) to suite their needs.
 * For more information on this see the "Custom Log Levels" page:
 * Documentation/CustomLogLevels.md
 *
 * Advanced users may also notice that we're using a bitmask.
 * This is to allow for custom fine grained logging:
 * Documentation/FineGrainedLogging.md
 *
 * -- Flags --
 *
 * Typically you will use the SG_LOG_LEVELS (see below), but the flags may be used directly in certain situations.
 * For example, say you have a lot of warning log messages, and you wanted to disable them.
 * However, you still needed to see your error and info log messages.
 * You could accomplish that with the following:
 *
 * static const int SGLogLevel = SG_LOG_FLAG_ERROR | SG_LOG_FLAG_INFO;
 *
 * When SG_LOG_LEVEL_DEF is defined as SGLogLevel.
 *
 * Flags may also be consulted when writing custom log formatters,
 * as the SGLogMessage class captures the individual flag that caused the log message to fire.
 *
 * -- Levels --
 *
 * Log levels are simply the proper bitmask of the flags.
 *
 * -- Booleans --
 *
 * The booleans may be used when your logging code involves more than one line.
 * For example:
 *
 * if (SG_LOG_VERBOSE) {
 *     for (id sprocket in sprockets)
 *         SGLogVerbose(@"sprocket: %@", [sprocket description])
 * }
 *
 * -- Async --
 *
 * Defines the default asynchronous options.
 * The default philosophy for asynchronous logging is very simple:
 *
 * Log messages with errors should be executed synchronously.
 *     After all, an error just occurred. The application could be unstable.
 *
 * All other log messages, such as debug output, are executed asynchronously.
 *     After all, if it wasn't an error, then it was just informational output,
 *     or something the application was easily able to recover from.
 *
 * -- Changes --
 *
 * You are strongly discouraged from modifying this file.
 * If you do, you make it more difficult on yourself to merge future bug fixes and improvements from the project.
 * Instead, create your own MyLogging.h or ApplicationNameLogging.h or CompanyLogging.h
 *
 * For an example of customizing your logging experience, see the "Custom Log Levels" page:
 * Documentation/CustomLogLevels.md
 **/

typedef NS_OPTIONS(NSUInteger, SGLogFlag) {
    SGLogFlagError      = (1 << 0),  // 0...00001
    SGLogFlagWarning    = (1 << 1),  // 0...00010
    SGLogFlagInfo       = (1 << 2),  // 0...00100
    SGLogFlagDebug      = (1 << 3),  // 0...01000
    SGLogFlagVerbose    = (1 << 4)   // 0...10000
};

typedef NS_ENUM(NSUInteger, SGLogLevel) {
    SGLogLevelOff       = 0,
    SGLogLevelError     = (SGLogFlagError),                             // 0...00001
    SGLogLevelWarning   = (SGLogLevelError | SGLogFlagWarning),         // 0...00011
    SGLogLevelInfo      = (SGLogLevelWarning | SGLogFlagInfo),          // 0...00111
    SGLogLevelDebug     = (SGLogLevelInfo | SGLogFlagDebug),            // 0...01111
    SGLogLevelVerbose   = (SGLogLevelDebug | SGLogFlagVerbose),         // 0...11111
    SGLogLevelAll       = NSUIntegerMax                                 // 1111....11111 (SG_LOG_LEVEL_VERBOSE plus any other flags)
};

// Most preprocessor variables aren't available under Swift.

#define SG_LOG_FLAG_ERROR    SGLogFlagError
#define SG_LOG_FLAG_WARN     SGLogFlagWarning
#define SG_LOG_FLAG_INFO     SGLogFlagInfo
#define SG_LOG_FLAG_DEBUG    SGLogFlagDebug
#define SG_LOG_FLAG_VERBOSE  SGLogFlagVerbose

#define SG_LOG_LEVEL_OFF     SGLogLevelOff
#define SG_LOG_LEVEL_ERROR   SGLogLeveError
#define SG_LOG_LEVEL_WARN    SGLogLevelWarning
#define SG_LOG_LEVEL_INFO    SGLogLevelInfo
#define SG_LOG_LEVEL_DEBUG   SGLogLevelDebug
#define SG_LOG_LEVEL_VERBOSE SGLogLevelVerbose
#define SG_LOG_LEVEL_ALL     SGLogLevelAll

#define SG_LOG_ERROR         (SG_LOG_LEVEL_DEF & SGLogFlagError)
#define SG_LOG_WARN          (SG_LOG_LEVEL_DEF & SGLogFlagWarning)
#define SG_LOG_INFO          (SG_LOG_LEVEL_DEF & SGLogFlagInfo)
#define SG_LOG_DEBUG         (SG_LOG_LEVEL_DEF & SGLogFlagDebug)
#define SG_LOG_VERBOSE       (SG_LOG_LEVEL_DEF & SGLogFlagVerbose)

#define SG_LOG_ASYNC_ENABLED YES

#define SG_LOG_ASYNC_ERROR   ( NO && SG_LOG_ASYNC_ENABLED)
#define SG_LOG_ASYNC_WARN    (YES && SG_LOG_ASYNC_ENABLED)
#define SG_LOG_ASYNC_INFO    (YES && SG_LOG_ASYNC_ENABLED)
#define SG_LOG_ASYNC_DEBUG   (YES && SG_LOG_ASYNC_ENABLED)
#define SG_LOG_ASYNC_VERBOSE (YES && SG_LOG_ASYNC_ENABLED)

/**
 * The THIS_FILE macro gives you an NSString of the file name.
 * For simplicity and clarity, the file name does not include the full path or file extension.
 *
 * For example: SGLogWarn(@"%@: Unable to find thingy", THIS_FILE) -> @"MyViewController: Unable to find thingy"
 **/

NSString * SGExtractFileNameWithoutExtension(const char *filePath, BOOL copy);

#define THIS_FILE         (SGExtractFileNameWithoutExtension(__FILE__, NO))

/**
 * The THIS_METHOD macro gives you the name of the current objective-c method.
 *
 * For example: SGLogWarn(@"%@ - Requires non-nil strings", THIS_METHOD) -> @"setMake:model: requires non-nil strings"
 *
 * Note: This does NOT work in straight C functions (non objective-c).
 * Instead you should use the predefined __FUNCTION__ macro.
 **/

#define THIS_METHOD       NSStringFromSelector(_cmd)


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SGLog : NSObject

/**
 * Provides access to the underlying logging queue.
 * This may be helpful to Logger classes for things like thread synchronization.
 **/

+ (dispatch_queue_t)loggingQueue;

/**
 * Logging Primitive.
 *
 * This method is used by the macros above.
 * It is suggested you stick with the macros as they're easier to use.
 **/

+ (void)log:(BOOL)synchronous
      level:(SGLogLevel)level
       flag:(SGLogFlag)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format, ...__attribute__((format(__NSString__, 9, 10)));

/**
 * Logging Primitive.
 *
 * This method can be used if you have a prepared va_list.
 **/

+ (void)log:(BOOL)asynchronous
      level:(SGLogLevel)level
       flag:(SGLogFlag)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)argList;

/**
 * Logging Primitive.
 *
 * This method can be used if you manualy prepared SGLogMessage.
 **/

+ (void)log:(BOOL)asynchronous
    message:(SGLogMessage *)logMessage;

/**
 * Since logging can be asynchronous, there may be times when you want to flush the logs.
 * The framework invokes this automatically when the application quits.
 **/

+ (void)flushLog;

/**
 * Loggers
 *
 * In order for your log statements to go somewhere, you should create and aSG a logger.
 *
 * You can aSG multiple loggers in order to direct your log statements to multiple places.
 * And each logger can be configured separately.
 * So you could have, for example, verbose logging to the console, but a concise log file with only warnings & errors.
 **/

/**
 * ASGs the logger to the system.
 *
 * This is equivalent to invoking [SGLog aSGLogger:logger withLogLevel:SG_LOG_LEVEL_ALL].
 **/
+ (void)addLogger:(id <SGLogger>)logger;

/**
 * ASGs the logger to the system.
 *
 * The logLevel that you provide here is a preemptive filter (for performance).
 * That is, the logLevel specified here will be used to filter out logMessages so that
 * the logger is never even invoked for the messages.
 *
 * More information:
 * When you issue a log statement, the logging framework iterates over each logger,
 * and checks to see if it should forward the logMessage to the logger.
 * This check is done using the logLevel parameter passed to this method.
 *
 * For example:
 * [SGLog aSGLogger:consoleLogger withLogLevel:SG_LOG_LEVEL_VERBOSE];
 * [SGLog aSGLogger:fileLogger    withLogLevel:SG_LOG_LEVEL_WARN];
 *
 * SGLogError(@"oh no"); => gets forwarded to consoleLogger & fileLogger
 * SGLogInfo(@"hi");     => gets forwarded to consoleLogger only
 *
 * It is important to remember that Lumberjack uses a BITMASK.
 * Many developers & third party frameworks may define extra log levels & flags.
 * For example:
 *
 * #define SOME_FRAMEWORK_SG_LOG_FLAG_TRACE (1 << 6) // 0...1000000
 *
 * So if you specify SG_LOG_LEVEL_VERBOSE to this method, you won't see the framework's trace messages.
 *
 * (SOME_FRAMEWORK_SG_LOG_FLAG_TRACE & SG_LOG_LEVEL_VERBOSE) => (01000000 & 00011111) => NO
 *
 * Consider passing SG_LOG_LEVEL_ALL to this method, which has all bits set.
 * You can also use the exclusive-or bitwise operator to get a bitmask that has all flags set,
 * except the ones you explicitly don't want. For example, if you wanted everything except verbose & debug:
 *
 * ((SG_LOG_LEVEL_ALL ^ SG_LOG_LEVEL_VERBOSE) | SG_LOG_LEVEL_INFO)
 **/
+ (void)addLogger:(id <SGLogger>)logger withLogLevel:(SGLogLevel)logLevel;

+ (void)removeLogger:(id <SGLogger>)logger;
+ (void)removeAllLoggers;

+ (NSArray *)allLoggers;

/**
 * Registered Dynamic Logging
 *
 * These methods allow you to obtain a list of classes that are using registered dynamic logging,
 * and also provides methods to get and set their log level during run time.
 **/

+ (NSArray *)registeredClasses;
+ (NSArray *)registeredClassNames;

+ (SGLogLevel)logLevelForClass:(Class)aClass;
+ (SGLogLevel)logLevelForClassWithName:(NSString *)aClassName;

+ (void)setLogLevel:(SGLogLevel)logLevel forClass:(Class)aClass;
+ (void)setLogLevel:(SGLogLevel)logLevel forClassWithName:(NSString *)aClassName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol SGLogger <NSObject>
@required

- (void)logMessage:(SGLogMessage *)logMessage;

/**
 * Formatters may optionally be aSGed to any logger.
 *
 * If no formatter is set, the logger simply logs the message as it is given in logMessage,
 * or it may use its own built in formatting style.
 **/
@property id <SGLogFormatter> logFormatter;

@optional

/**
 * Since logging is asynchronous, aSGing and removing loggers is also asynchronous.
 * In other words, the loggers are aSGed and removed at appropriate times with regards to log messages.
 *
 * - Loggers will not receive log messages that were executed prior to when they were aSGed.
 * - Loggers will not receive log messages that were executed after they were removed.
 *
 * These methods are executed in the logging thread/queue.
 * This is the same thread/queue that will execute every logMessage: invocation.
 * Loggers may use these methods for thread synchronization or other setup/teardown tasks.
 **/
- (void)didAddLogger;
- (void)willRemoveLogger;

/**
 * Some loggers may buffer IO for optimization purposes.
 * For example, a database logger may only save occasionaly as the disk IO is slow.
 * In such loggers, this method should be implemented to flush any pending IO.
 *
 * This allows invocations of SGLog's flushLog method to be propogated to loggers that need it.
 *
 * Note that SGLog's flushLog method is invoked automatically when the application quits,
 * and it may be also invoked manually by the developer prior to application crashes, or other such reasons.
 **/
- (void)flush;

/**
 * Each logger is executed concurrently with respect to the other loggers.
 * Thus, a dedicated dispatch queue is used for each logger.
 * Logger implementations may optionally choose to provide their own dispatch queue.
 **/
- (dispatch_queue_t)loggerQueue;

/**
 * If the logger implementation does not choose to provide its own queue,
 * one will automatically be created for it.
 * The created queue will receive its name from this method.
 * This may be helpful for debugging or profiling reasons.
 **/
- (NSString *)loggerName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol SGLogFormatter <NSObject>
@required

/**
 * Formatters may optionally be aSGed to any logger.
 * This allows for increased flexibility in the logging environment.
 * For example, log messages for log files may be formatted differently than log messages for the console.
 *
 * For more information about formatters, see the "Custom Formatters" page:
 * Documentation/CustomFormatters.md
 *
 * The formatter may also optionally filter the log message by returning nil,
 * in which case the logger will not log the message.
 **/
- (NSString *)formatLogMessage:(SGLogMessage *)logMessage;

@optional

/**
 * A single formatter instance can be aSGed to multiple loggers.
 * These methods provides hooks to notify the formatter of when it's aSGed/removed.
 *
 * This is primarily for thread-safety.
 * If a formatter is explicitly not thread-safe, it may wish to throw an exception if aSGed to multiple loggers.
 * Or if a formatter has potentially thread-unsafe code (e.g. NSDateFormatter),
 * it could possibly use these hooks to switch to thread-safe versions of the code.
 **/
- (void)didAddToLogger:(id <SGLogger>)logger;
- (void)willRemoveFromLogger:(id <SGLogger>)logger;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol SGRegisteredDynamicLogging

/**
 * Implement these methods to allow a file's log level to be managed from a central location.
 *
 * This is useful if you'd like to be able to change log levels for various parts
 * of your code from within the running application.
 *
 * Imagine pulling up the settings for your application,
 * and being able to configure the logging level on a per file basis.
 *
 * The implementation can be very straight-forward:
 *
 * + (int)SGLogLevel
 * {
 *     return SGLogLevel;
 * }
 *
 * + (void)SGSetLogLevel:(int)logLevel
 * {
 *     SGLogLevel = logLevel;
 * }
 **/

+ (SGLogLevel)SGLogLevel;
+ (void)SGSetLogLevel:(SGLogLevel)logLevel;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The SGLogMessage class encapsulates information about the log message.
 * If you write custom loggers or formatters, you will be dealing with objects of this class.
 **/

enum {
    SGLogMessageCopyFile     = 1 << 0,
    SGLogMessageCopyFunction = 1 << 1
};
typedef int   SGLogMessageOptions;

@interface SGLogMessage : NSObject <NSCopying>
{
// The public variables below can be accessed directly (for speed).
// For example: logMessage->logLevel

    @public
    SGLogLevel logLevel;
    SGLogFlag logFlag;
    int logContext;
    NSString *logMsg;
    NSDate *timestamp;
    char *file;
    char *function;
    int lineNumber;
    mach_port_t machThreadID;
    char *queueLabel;
    NSString *threadName;

    // For 3rd party extensions to the framework, where flags and contexts aren't enough.
    id tag;

    // For 3rd party extensions that manually create SGLogMessage instances.
    SGLogMessageOptions options;
}

/**
 * Standard init method for a log message object.
 * Used by the logging primitives. (And the macros use the logging primitives.)
 *
 * If you find need to manually create logMessage objects, there is one thing you should be aware of:
 *
 * If no flags are passed, the method expects the file and function parameters to be string literals.
 * That is, it expects the given strings to exist for the duration of the object's lifetime,
 * and it expects the given strings to be immutable.
 * In other words, it does not copy these strings, it simply points to them.
 * This is due to the fact that __FILE__ and __FUNCTION__ are usually used to specify these parameters,
 * so it makes sense to optimize and skip the unnecessary allocations.
 * However, if you need them to be copied you may use the options parameter to specify this.
 * Options is a bitmask which supports SGLogMessageCopyFile and SGLogMessageCopyFunction.
 **/
- (instancetype)initWithLogMsg:(NSString *)logMsg
                         level:(SGLogLevel)logLevel
                          flag:(SGLogFlag)logFlag
                       context:(int)logContext
                          file:(const char *)file
                      function:(const char *)function
                          line:(int)line
                           tag:(id)tag
                       options:(SGLogMessageOptions)optionsMask;
- (instancetype)initWithLogMsg:(NSString *)logMsg
                         level:(SGLogLevel)logLevel
                          flag:(SGLogFlag)logFlag
                       context:(int)logContext
                          file:(const char *)file
                      function:(const char *)function
                          line:(int)line
                           tag:(id)tag
                       options:(SGLogMessageOptions)optionsMask
                     timestamp:(NSDate *)aTimestamp;

/**
 * Returns the threadID as it appears in NSLog.
 * That is, it is a hexadecimal value which is calculated from the machThreadID.
 **/
- (NSString *)threadID;

/**
 * Convenience property to get just the file name, as the file variable is generally the full file path.
 * This method does not include the file extension, which is generally unwanted for logging purposes.
 **/
- (NSString *)fileName;

/**
 * Returns the function variable in NSString form.
 **/
- (NSString *)methodName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The SGLogger protocol specifies that an optional formatter can be aSGed to a logger.
 * Most (but not all) loggers will want to support formatters.
 *
 * However, writting getters and setters in a thread safe manner,
 * while still maintaining maximum speed for the logging process, is a difficult task.
 *
 * To do it right, the implementation of the getter/setter has strict requiremenets:
 * - Must NOT require the logMessage method to acquire a lock.
 * - Must NOT require the logMessage method to access an atomic property (also a lock of sorts).
 *
 * To simplify things, an abstract logger is provided that implements the getter and setter.
 *
 * Logger implementations may simply extend this class,
 * and they can ACCESS THE FORMATTER VARIABLE DIRECTLY from within their logMessage method!
 **/

@interface SGAbstractLogger : NSObject <SGLogger>
{
    id <SGLogFormatter> formatter;

    dispatch_queue_t loggerQueue;
}
@property (strong) id <SGLogFormatter> logFormatter;

// For thread-safety assertions
- (BOOL)isOnGlobalLoggingQueue;
- (BOOL)isOnInternalLoggerQueue;

@end
