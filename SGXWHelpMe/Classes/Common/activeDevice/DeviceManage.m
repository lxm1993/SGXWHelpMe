//
//  DeviceManage.m
//  Need
//
//  Created by Cheng Jimmy on 15-1-4.
//  Copyright (c) 2015年 weplanter. All rights reserved.
//

#import "DeviceManage.h"
#import  <UIKit/UIKit.h>
#import "UIDevice+IdentifierAddition.h"

@interface DeviceManage ()
{
    NSString *mSource;
    NSString *mOSVersion;
    NSString *mMac;
    NSString *mDevType;
    NSString *mResolution;
    
    float mScaleW;//宽缩放比率
    float mScaleH;//高缩放比率
    
    NSString *mAppID;
    NSString *mAppName;
    NSString *mAppVersion;
    NSString *mAppBuildVersion;
}
@property (nonatomic, strong) UIDevice *curDev;                //获取当前设备句柄
@property (nonatomic, strong) NSDictionary *appInfoDictionary; //App信息
@end


@implementation DeviceManage
#pragma mark - 单例
/*------------单例--------------*/
+ (DeviceManage *)deviceManage
{
    static DeviceManage *manage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
         manage = [[super allocWithZone:NULL]init];
        
    });
    return manage;
}

+(instancetype) allocWithZone:(struct _NSZone *)zone{
    return [self deviceManage];
}

+(id) copyWithZone:(struct _NSZone *)zone{
    return [self deviceManage];
}
/*------------结束--------------*/

- (void)getDeviceInfo
{
    mSource = self.source;
    mOSVersion = self.osVersion;
    mMac = self.mac;
    mDevType = self.deviceType;
    mResolution = self.resolution;
    
    mScaleW = self.widthScaleRatio;
    mScaleH = self.heighScaleRatio;
    
    mAppID = self.AppID;
    mAppName = self.AppName;
    mAppVersion = self.AppVersion;
    mAppBuildVersion = self.AppBuildVersion;
}


#pragma mark - DeviceInfo
/*-----------------------DeviceInfo------------------------*/
- (UIDevice *)curDev
{
    if (!_curDev) {
        _curDev = [UIDevice currentDevice];
    }
    return _curDev;
}

- (NSString *)source
{
    if (!_source) {
//        _source = self.curDev.systemName;
        _source = @"IOS";
    }
    return _source;
}

- (NSString *)osVersion
{
    if (!_osVersion) {
        _osVersion = self.curDev.systemVersion;
    }
    return _osVersion;
}

- (NSString *)mac
{
    if (!_mac) {
//        _mac = self.curDev.identifierForVendor.UUIDString; //卸载后变动
        _mac = [self.curDev uniqueDeviceIdentifier];
        
    }
    return _mac;
}

- (NSString *)deviceType
{
    if (!_deviceType) {
        _deviceType = self.curDev.model;
    }
    return _deviceType;
}

- (NSString *)localModel
{
    if (!_localModel) {
        _localModel = self.curDev.localizedModel;
    }
    return _localModel;
}

- (NSString *)releaseChannel
{
    if (!_releaseChannel) {
        _releaseChannel = @"APPSTORE";
    }
    return _releaseChannel;
}

- (NSString *)resolution
{
    if (!_resolution) {
        UIScreen *screen = [UIScreen mainScreen];
        CGFloat width  = screen.bounds.size.width;
        CGFloat height = screen.bounds.size.height;
        CGFloat scale = screen.scale;
        _resolution = [NSString stringWithFormat:@"%ldx%ld",(long)(width*scale),(long)(height*scale)];
    }
    return _resolution;
}

- (NeediPhoneSize) iPhoneSize
{
    if (_iPhoneSize == 0) {
        //这种情况如何使用switch ?
        if ([self.resolution isEqualToString:@"1242x2208"]) {
            _iPhoneSize = iPhoneSize5_5;
        }else if ([self.resolution isEqualToString:@"750x1334"]){
            _iPhoneSize = iPhoneSize4_7;
        }else if ([self.resolution isEqualToString:@"640x1136"]){
            _iPhoneSize = iPhoneSize4_0;
        }else if ([self.resolution isEqualToString:@"640x960"]){
            _iPhoneSize = iPhoneSize3_5;
        }else{
            _iPhoneSize = 0;
        }
    }
    return _iPhoneSize;
}
- (NSString *)launchImageName
{
    if (!_launchImageName) {
        switch (self.iPhoneSize) {
            case 4:
                _launchImageName = @"LaunchImage-800-Portrait-736h";
                break;
            case 3:
                _launchImageName = @"LaunchImage-800-667h";
                break;
            case 2:
                _launchImageName = @"LaunchImage-700-568h";
                break;
            case 1:
                _launchImageName = @"LaunchImage-700";
                break;
            default:
                 _launchImageName = @"LaunchImage";
                break;
        }
    }
    return _launchImageName;
}

#pragma mark - 缩放比率
- (CGFloat) scale
{
    if (_scale == 0) {
        UIScreen *screen = [UIScreen mainScreen];
        _scale = screen.scale;
    }
    return _scale;
}

- (CGFloat)screenWidth
{
    if (_screenWidth == 0) {
        UIScreen *screen = [UIScreen mainScreen];
        _screenWidth = screen.bounds.size.width;
    }
    return _screenWidth;
}

- (CGFloat)screenHeigh
{
    if (_screenHeigh == 0) {
        UIScreen *screen = [UIScreen mainScreen];
        _screenHeigh = screen.bounds.size.height;
    }
    return _screenHeigh;
}

- (CGFloat)widthScaleRatio
{
    if (_widthScaleRatio == 0) {
        UIScreen *screen = [UIScreen mainScreen];
        _widthScaleRatio = screen.bounds.size.width / 375.0 ;
    }
    return _widthScaleRatio;
}

- (CGFloat)heighScaleRatio
{
    if (_heighScaleRatio == 0) {
        UIScreen *screen = [UIScreen mainScreen];
        _heighScaleRatio = screen.bounds.size.height / 667.0 ;
    }
    return _heighScaleRatio;
}
/*-----------------------DeviceInfo结束------------------------*/

#pragma mark - AppInfo
/*-----------------------AppInfo------------------------*/
- (NSDictionary *)appInfoDictionary
{
    if (!_appInfoDictionary) {
        _appInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    }
    return _appInfoDictionary;
}
- (NSString *)AppID
{
    if (!_AppID) {
        _AppID = APPID;
    }
    return _AppID;
}

- (NSString *)AppName
{
    if (!_AppName) {
        _AppName = [self.appInfoDictionary objectForKey:@"CFBundleDisplayName"];
    }
    return _AppName;
}
- (NSString *)AppVersion
{
    if (!_AppVersion) {
        _AppVersion = [self.appInfoDictionary objectForKey:@"CFBundleShortVersionString"];
    }
    return  _AppVersion;
}

- (NSString *)AppBuildVersion
{
    if (!_AppBuildVersion) {
        _AppBuildVersion = [self.appInfoDictionary objectForKey:@"CFBundleVersion"];
    }
    return _AppBuildVersion;
}
/*-----------------------AppInfo结束------------------------*/

#pragma mark - 继承描述
- (NSString *)description
{
    NSString *devInfo = [NSString stringWithFormat:@"\n/***********设备信息**********\n来源: %@ \n版本: %@ \nMac地址: %@ \n设备类型: %@ \n分辨率: %@\n/****************",mSource,mOSVersion,mMac,mDevType,mResolution];
    NSString *scaleInfo = [NSString stringWithFormat:@"\n/***********适配比率**********\n宽度适配率: %f\n高度适配率: %f\n/****************",mScaleW,mScaleH];
    NSString *appInfo = [NSString stringWithFormat:@"\n/***********APP信息**********\n显示名称: %@\n版本号: %@\n构建版本号: %@\nID: %@\n/****************",mAppName,mAppVersion,mAppBuildVersion,mAppID];
    return [NSString stringWithFormat:@"%@%@%@",devInfo,scaleInfo,appInfo];
}

@end
