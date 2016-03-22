//
//  GlobalDefine.h
//  SGXwHelp
//
//  Created by lihua on 16/3/3.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#ifndef GlobalDefine_h
#define GlobalDefine_h


/************1.方法缩略************************/
//强弱引用
#define WeakObj(o)                      autoreleasepool{} __weak typeof(o) o##Weak = o
#define StrongObj(o)                    autoreleasepool{} __strong typeof(o) o = o##Weak
//宽高度
#define ScreenWidth                     ([[UIScreen mainScreen] bounds].size.width)
#define ScreenHeight                    ([[UIScreen mainScreen] bounds].size.height)
#define KNavHeight                      self.navigationController.navigationBar.frame.size.height
#define KStateBarHeight                 [[UIApplication sharedApplication] statusBarFrame].size.height
//颜色
#define RGBA(r,g,b,a)                   [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]
#define RGB(r,g,b)                      RGBA(r,g,b,1.0f)
#define UIColorWithRGBA(rgbValue,a)     [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define UIColorWithRGB(rgbValue)        UIColorWithRGBA(rgbValue,1.0f)
#define Font(F)                              [UIFont systemFontOfSize:(F)]
#define boldFont(F)                     [UIFont boldSystemFontOfSize:(F)]

#define kNavBarTintColor                UIColorWithRGB(0xF7F6F2)
#define KCommentColor                   UIColorWithRGB(0x7B7B7B)
#define kMainBlackColor                 UIColorWithRGB(0x2A2A2A)

/**************2.Debug输出*******************/
#ifdef DEBUG
#define DLog(fmt, ...)                  NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define DLog(...)
#endif

/**************3.系统版本判断*******************/

#define SYSTEM_VERSION_GREATER_THAN(s)  ([[[UIDevice currentDevice] systemVersion] compare:s] != NSOrderedAscending )

/**************4.录音相关字符串定义*******************/
#define kRecordToolBarUnTouch @"按住说话"
#define kRecordToolBarTouch @"松开发送"
#define kFingersUpCancleRecord @"手指上滑，取消发送"
#define kFingersToOutSideCancleRecord @"手指松开，取消发送"

/**************5.Keys*******************/

#define APPID                           @"1033089957"

#define kDEVICEID                       @"deviceId"


/**************5.Notifications*******************/

#define DidUpdateLocationsNotification                           @"DidUpdateLocationsNotification"


#endif /* GlobalDefine_h */
