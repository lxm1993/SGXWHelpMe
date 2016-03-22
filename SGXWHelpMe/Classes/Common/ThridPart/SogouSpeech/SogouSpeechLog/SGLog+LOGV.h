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

#ifndef SogouSpeech_SGLog_LOGV_h
#define SogouSpeech_SGLog_LOGV_h

#import "SGLog.h"


#define SG_LOGV_MACRO(isAsynchronous, lvl, flg, ctx, atag, fnct, frmt, avalist) \
    [SGLog log:isAsynchronous                                                \
         level:lvl                                                           \
          flag:flg                                                           \
       context:ctx                                                           \
          file:__FILE__                                                      \
      function:fnct                                                          \
          line:__LINE__                                                      \
           tag:atag                                                          \
        format:frmt                                                          \
          args:avalist]

#define SG_LOGV_OBJC_MACRO(async, lvl, flg, ctx, frmt, avalist) \
             SG_LOGV_MACRO(async, lvl, flg, ctx, nil, sel_getName(_cmd), frmt, avalist)

#define SG_LOGV_C_MACRO(async, lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_MACRO(async, lvl, flg, ctx, nil, __FUNCTION__, frmt, avalist)



#define  SG_SYNC_LOGV_OBJC_MACRO(lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_OBJC_MACRO(NO, lvl, flg, ctx, frmt, avalist)

#define SG_ASYNC_LOGV_OBJC_MACRO(lvl, flg, ctx, frmt, avalist) \
         SG_LOGV_OBJC_MACRO(YES, lvl, flg, ctx, frmt, avalist)

#define  SYNC_LOGV_C_MACRO(lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_C_MACRO(NO, lvl, flg, ctx, frmt, avalist)

#define ASYNC_LOGV_C_MACRO(lvl, flg, ctx, frmt, avalist) \
         SG_LOGV_C_MACRO(YES, lvl, flg, ctx, frmt, avalist)



#define SG_LOGV_MAYBE(async, lvl, flg, ctx, fnct, frmt, avalist) \
    do { if(lvl & flg) SG_LOGV_MACRO(async, lvl, flg, ctx, nil, fnct, frmt, avalist); } while(0)


#define SG_LOGV_OBJC_MAYBE(async, lvl, flg, ctx, frmt, avalist) \
             SG_LOGV_MAYBE(async, lvl, flg, ctx, sel_getName(_cmd), frmt, avalist)

#define SG_LOGV_C_MAYBE(async, lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_MAYBE(async, lvl, flg, ctx, __FUNCTION__, frmt, avalist)

#define  SG_SYNC_LOGV_OBJC_MAYBE(lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_OBJC_MAYBE(NO, lvl, flg, ctx, frmt, avalist)

#define SG_ASYNC_LOGV_OBJC_MAYBE(lvl, flg, ctx, frmt, avalist) \
         SG_LOGV_OBJC_MAYBE(YES, lvl, flg, ctx, frmt, avalist)

#define  SG_SYNC_LOGV_C_MAYBE(lvl, flg, ctx, frmt, avalist) \
          SG_LOGV_C_MAYBE(NO, lvl, flg, ctx, frmt, avalist)

#define SG_ASYNC_LOGV_C_MAYBE(lvl, flg, ctx, frmt, avalist) \
         SG_LOGV_C_MAYBE(YES, lvl, flg, ctx, frmt, avalist)



#define SG_LOGV_OBJC_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, avalist) \
                 SG_LOGV_MACRO(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, avalist)

#define SG_LOGV_C_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, avalist) \
              SG_LOGV_MACRO(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, avalist)

#define SG_LOGV_TAG_MAYBE(async, lvl, flg, ctx, tag, fnct, frmt, avalist) \
    do { if(lvl & flg) SG_LOGV_MACRO(async, lvl, flg, ctx, tag, fnct, frmt, avalist); } while(0)

#define SG_LOGV_OBJC_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, avalist) \
             SG_LOGV_TAG_MAYBE(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, avalist)

#define LOGV_C_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, avalist) \
          LOGV_TAG_MAYBE(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, avalist)



#define SGLogvError(frmt, avalist)    SG_LOGV_OBJC_MAYBE(SG_LOG_ASYNC_ERROR,   sgLogLevel, SG_LOG_FLAG_ERROR,   0, frmt, avalist)
#define SGLogvWarn(frmt, avalist)     SG_LOGV_OBJC_MAYBE(SG_LOG_ASYNC_WARN,    sgLogLevel, SG_LOG_FLAG_WARN,    0, frmt, avalist)
#define SGLogvInfo(frmt, avalist)     SG_LOGV_OBJC_MAYBE(SG_LOG_ASYNC_INFO,    sgLogLevel, SG_LOG_FLAG_INFO,    0, frmt, avalist)
#define SGLogvVerbose(frmt, avalist)  SG_LOGV_OBJC_MAYBE(SG_LOG_ASYNC_VERBOSE, sgLogLevel, SG_LOG_FLAG_VERBOSE, 0, frmt, avalist)

#define SGLogvCError(frmt, avalist)   SG_LOGV_C_MAYBE(SG_LOG_ASYNC_ERROR,   sgLogLevel, SG_LOG_FLAG_ERROR,   0, frmt, avalist)
#define SGLogvCWarn(frmt, avalist)    SG_LOGV_C_MAYBE(SG_LOG_ASYNC_WARN,    sgLogLevel, SG_LOG_FLAG_WARN,    0, frmt, avalist)
#define SGLogvCInfo(frmt, avalist)    SG_LOGV_C_MAYBE(SG_LOG_ASYNC_INFO,    sgLogLevel, SG_LOG_FLAG_INFO,    0, frmt, avalist)
#define SGLogvCVerbose(frmt, avalist) SG_LOGV_C_MAYBE(SG_LOG_ASYNC_VERBOSE, sgLogLevel, SG_LOG_FLAG_VERBOSE, 0, frmt, avalist)

#endif /* ifndef Lumberjack_DDLog_LOGV_h */
