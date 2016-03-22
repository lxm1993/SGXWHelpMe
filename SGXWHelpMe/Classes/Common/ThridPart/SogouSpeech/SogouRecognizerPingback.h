//
//  SogouRecognizerPingback.h
//  SGSpeechRecognize4cyou
//
//  Created by Sogou on 14-11-21.
//  Copyright (c) 2014年 Sogou. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SogouRecognizerPingback : NSObject
//指令类别，助手应用固定设置为siri_cb
@property (nonatomic, copy) NSString *cmd;

//发起语音请求时的毫秒级Unix时间戳，用于定位语音。
@property (nonatomic, copy) NSString *startTime;

//发起语音请求时发送的IMEI，用于定位语音。
//@property (nonatomic, copy) NSString *imeiNo;

//从点击start按钮( 调用startListening())到检测到有效声音（VAD的wavVadDetectorRes->voiced值变为true）的毫秒级时间，默认值为-1，表示未指定或异常。
@property (nonatomic, assign) int preInterval;

//从录音结束（调用stopListening()）到收到语音识别结果（调用onResults方法）的毫秒级时间，默认值为-1，表示未指定或异常。
@property (nonatomic, assign) int sufInterval;

//网络类型，值为unknown（判别不出来网络类型时赋该值），wifi，或者mobile-X。X用于区分2G、3G和4G，Android版中，2G值为1,2,4,7,11；3G值为3,5,6,8,9,10,12,14,15；4G值为13；未知值为0。Android版的NetworkService类的getDetailNetworkType方法可以获取该值；iOS版如果无法区分开的话，就设置为定值unknown，能区分开的话，如果没有像Android那么多的值，就按各类别的第一个值赋值即可，如2G就固定设置为mobile-1，3G固定设置为mobile-3，3G固定设置为mobile-13，wifi网络就固定设置为wifi。
//@property (nonatomic, copy) NSString *netType;

//用户的点击行为，值为0表示未点击stop也未点击cancel；值为1表示未点击stop点击cancel；值为2表示点击stop未点击cancel；值为3表示既点击stop又点击cancel；默认值为-1，表示没执行到该步骤或者异常。
@property (nonatomic, assign) int click;

//用户选择候选结果的序号，5个候选序号依次为0～4，默认值为-2表示错误，用户点击取消按钮，则值为-1（表示丢弃候选）
@property (nonatomic, assign) int chosen;

//方言归属地
//@property (nonatomic, assign) int area;

//所选定的语音识别结果（或者校准后的结果），如果异常或者无识别结果，则不赋值（即样例为text=）
@property (nonatomic, copy) NSString *text;

//客户端错误码，-1表示用户正常输入；0表示说话后，退出语音输入界面；1连接网络超时；2表示网络错误；3表示录音错误；4表示服务器错误（JSON返回的status为负数）；5表示其他客户端错误；6表示未检测到有效声音；7表示无识别结果（JSON返回的status为0）；8表示服务器繁忙（保留，无具体依据）；9表示客户端缺少授权；10表示客户端API出现异常；11表示网络不可用（保留，与2含义基本一样）。重点反馈的错误码为-1，0，1，2，3，4，6。
@property (nonatomic, assign) int error;

//Speech API版本号。
//@property (nonatomic, assign) int v;


//在调用此函数钱设置的参数才有效。
- (void)onEndWithText:(NSString *)text error:(int)error;


@end
