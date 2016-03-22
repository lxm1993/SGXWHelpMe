//
//  SogouConfig.m
//  SogouSpeechRecognize_Inc_Arc
//
//  Created by Sogou on 15-1-27.
//  Copyright (c) 2015年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SogouConfig.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <net/if.h>
#import <net/if_dl.h>

#import "SogouSpeechLog.h"

SGLogLevel sgLogLevel;

@implementation SogouConfig

+ (NSString *)applicationName {
    static NSString *_appName;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        
        if (!_appName) {
            _appName = [[NSProcessInfo processInfo] processName];
        }
        if (!_appName) {
            _appName = @"";
        }
    });
    return _appName;
}

+(NSString*)getBundleId
{
    static NSString *bundleId;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary* infoDict =[[NSBundle mainBundle] infoDictionary];
        bundleId =[infoDict objectForKey:@"CFBundleIdentifier"];
    });
    return bundleId;
}

//网络类型是随时可变的，不可实现为静态返回值
+ (int)netType
{
    UIApplication *app = [UIApplication sharedApplication];
    NSArray *subviews = [[[app valueForKey:@"statusBar"] valueForKey:@"foregroundView"] subviews];
    id dataNetworkItemView = nil;
    for (id subview in subviews) {
        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]]) {
            dataNetworkItemView = subview;
            break;
        }
    }
    if (dataNetworkItemView) {
        NSNumber * num = [dataNetworkItemView valueForKey:@"dataNetworkType"];
        if (num && [num isKindOfClass:[NSNumber class]]) {
            return [num intValue];
        }
    }
    //如果该方法失效，默认wifi吧。。。
    SGLogVerbose(@"获取网络类型失败，返回wifi");
    return 5;
}

+(NSString*)netTypeStr
{
    int networkType = [self netType];
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


+ (NSString *)getMacAddress
{
    int					mib[6];
    size_t				len;
    char				*buf;
    unsigned char		*ptr;
    struct if_msghdr	*ifm;
    struct sockaddr_dl	*sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex("en0")) == 0) {
        printf("Error: if_nametoindex error\n");
        return NULL;
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 1\n");
        return NULL;
    }
    
    if ((buf = (char *)malloc(len)) == NULL) {
        printf("Could not allocate memory. error!\n");
        return NULL;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 2");
        free(buf);
        return NULL;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    
    NSString *outstring = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    return [outstring uppercaseString];
}
+ (NSString *)imei{
    static NSString *imei;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *uuid = nil;
        if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
            uuid = [[[[UIDevice currentDevice] identifierForVendor] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        }
        else{
            uuid = [self getMacAddress];
        }
        const char *cStr = [uuid UTF8String];
        unsigned char result[16];
        CC_MD5(cStr, strlen(cStr), result);
        imei = [[NSString alloc] initWithFormat:@"%02X%02X%02X%02X",result[12],result[13],result[14],result[15]];
    });
    return imei;
}


@end

