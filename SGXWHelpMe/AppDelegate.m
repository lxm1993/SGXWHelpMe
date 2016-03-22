//
//  AppDelegate.m
//  SGXWHelpMe
//
//  Created by lihua on 16/3/4.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import "AppDelegate.h"
#import "SGNavigationController.h"
#import "SGHomeSearchViewController.h"

#import "SogouSpeechSetting.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFNetworkReachabilityManager.h"
#import "MBProgressHUD.h"


@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    //建立web缓存
    [self createCache];
    
    //设备信息
    
    DeviceManage * device = [DeviceManage deviceManage];
    [device getDeviceInfo];
    DLog(@"%@",[DeviceManage deviceManage]);
    
    //1.监测网络变化
    [self testNetWork];

    
    //搜狗语音识别配置
    [self SouGouSpeechSet];
    
    SGHomeSearchViewController * homeSearchViewCon = [[SGHomeSearchViewController alloc]init];
    SGNavigationController * searchNavBar = [[SGNavigationController alloc]initWithRootViewController:homeSearchViewCon];
    self.window.rootViewController = searchNavBar;
    
    
    // Override point for customization after application launch.
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application{
    
    DLog(@"内存警告！！！！！！");
    [self clearCache];
}
#pragma mark -method
-(void)testNetWork{
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (status == AFNetworkReachabilityStatusNotReachable) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.window.rootViewController.view animated:YES];
            hud.mode = MBProgressHUDModeText;
            hud.labelText= @"网络异常，请您检查网络设置";
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud hide:YES afterDelay:4];
                });
            });
        }
    }];

}
//建立缓存
-(void)createCache{
    /** If you need to do any extra app-specific initialization, you can do it here
     *  -jm
     **/
    NSHTTPCookieStorage* cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    int cacheSizeMemory = 8 * 1024 * 1024; // 8MB
    int cacheSizeDisk = 32 * 1024 * 1024; // 32MB
#if __has_feature(objc_arc)
    NSURLCache* sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"];
#else
    NSURLCache* sharedCache = [[[NSURLCache alloc] initWithMemoryCapacity:cacheSizeMemory diskCapacity:cacheSizeDisk diskPath:@"nsurlcache"] autorelease];
#endif
    [NSURLCache setSharedURLCache:sharedCache];
}
//清除缓存
- (void)clearCache
{
    //清除cookies
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies])
    {
        [storage deleteCookie:cookie];
    }
    
    //清除UIWebView的缓存
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSURLCache * cache = [NSURLCache sharedURLCache];
    [cache removeAllCachedResponses];
    [cache setDiskCapacity:0];
    [cache setMemoryCapacity:0];
    
}

#pragma mark - 搜狗语音识别配置
-(void)SouGouSpeechSet
{
    //    调试时打印log，以及设置log级别。
    [SogouSpeechSetting showLogcat:YES];
    [SogouSpeechSetting setLogLevel:SG_LOG_LVL_All];
    [SogouSpeechRecognizeUserInfo setUserID:@"VORH9623" andKey:@"6361FdmG"];
    [SogouSpeechRecognizeUserInfo setIsContinuous:YES];
    //如果达到两秒还没检测到有效声音，将回调- (void)onRecordTimeAtPoint:(float)time;
    [SogouSpeechRecognizeUserInfo setTimeToShowRecordMessage:2.0];
    //如果3秒内点调用了stop,且未检测到有效声音，onError将返回录音过短的错误（ERROR_RECORDER_TOO_SHORT = 14,//------录音时间太短）
    [SogouSpeechRecognizeUserInfo setRecorderTooShortThreshold:3.0];
    
    [SogouSpeechRecognizeUserInfo setVadHeadInterval:31000 withTailInterval:100000];
}
@end
