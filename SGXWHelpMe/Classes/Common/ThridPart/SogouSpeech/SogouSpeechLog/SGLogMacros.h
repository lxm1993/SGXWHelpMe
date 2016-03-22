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

#import "SGLog.h"

/**
 * Ready to use log macros.
 **/

#ifndef SG_LOG_LEVEL_DEF
    #define SG_LOG_LEVEL_DEF sgLogLevel
#endif

#define SGLogError(frmt, ...)   SG_LOG_OBJC_MAYBE(SG_LOG_ASYNC_ERROR,   SG_LOG_LEVEL_DEF, SG_LOG_FLAG_ERROR,   0, frmt, ## __VA_ARGS__)
#define SGLogWarn(frmt, ...)    SG_LOG_OBJC_MAYBE(SG_LOG_ASYNC_WARN,    SG_LOG_LEVEL_DEF, SG_LOG_FLAG_WARN,    0, frmt, ## __VA_ARGS__)
#define SGLogInfo(frmt, ...)    SG_LOG_OBJC_MAYBE(SG_LOG_ASYNC_INFO,    SG_LOG_LEVEL_DEF, SG_LOG_FLAG_INFO,    0, frmt, ## __VA_ARGS__)
#define SGLogDebug(frmt, ...)   SG_LOG_OBJC_MAYBE(SG_LOG_ASYNC_DEBUG,   SG_LOG_LEVEL_DEF, SG_LOG_FLAG_DEBUG,   0, frmt, ## __VA_ARGS__)
#define SGLogVerbose(frmt, ...) SG_LOG_OBJC_MAYBE(SG_LOG_ASYNC_VERBOSE, SG_LOG_LEVEL_DEF, SG_LOG_FLAG_VERBOSE, 0, frmt, ## __VA_ARGS__)
