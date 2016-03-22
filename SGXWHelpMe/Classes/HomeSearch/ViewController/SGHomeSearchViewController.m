//
//  SGHomeSearchViewController.m
//  SGXwHelp
//
//  Created by lihua on 16/3/3.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import "SGHomeSearchViewController.h"

#import <AVFoundation/AVFoundation.h>
#import "DXMessageToolBar.h"
#import "SogouSpeechRecognizer.h"
#import "SogouSpeechRecognizeUserInfo.h"
#import "SogouSpeechRecognizerDelegate.h"



@interface SGHomeSearchViewController ()<DXMessageToolBarDelegate,SogouSpeechRecognizerDelegate,UIScrollViewDelegate,UIGestureRecognizerDelegate>

{
    int _lastPosition;
    UITapGestureRecognizer *_tap;
    DXRecordView *tmpView ;
}

@property (strong, nonatomic) DXMessageToolBar *chatToolBar;

@end

@implementation SGHomeSearchViewController

#pragma mark - lifeCycle
-(void)dealloc
{
    DLog(@"主界面内存释放");
}
- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.title = @"小汪帮忙";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"详情" style:UIBarButtonItemStylePlain target:self action:@selector(SearchDetail)];
    
    //添加单击webView键盘消失的手势
    self.baseWebView.scrollView.delegate = self;
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(keyBoardHidden)];
    _tap.delegate = self;
    
    [self.baseWebView addGestureRecognizer:_tap];
    [self.view addSubview:self.chatToolBar];
    
   [self loadRequestWithUrlString:@"http://10.134.14.117:8080/app/dialog/www/talking.html"];
     //[self loadExamplePage:self.baseWebView];
}
- (void)loadExamplePage:(UIWebView*)webView {
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"ExampleApp" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [webView loadHTMLString:appHtml baseURL:baseURL];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    
    @WeakObj(self);
    [self.baseWebView mas_updateConstraints:^(MASConstraintMaker *make) {
        @StrongObj(self);
        make.top.equalTo(self.view.mas_top);
        make.left.equalTo(self.view.mas_left);
        make.width.mas_equalTo(ScreenWidth);
        make.height.mas_equalTo(ScreenHeight-2*[DXMessageToolBar defaultHeight]);
    }];

}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - action
-(void)SearchDetail
{
   
}
#pragma mark - UIWebViewDelegate
-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    [super webViewDidFinishLoad:webView];
    
    static BOOL isLoad = YES;
    if (isLoad) {
        
        for (int i =0; i<3; i++) {
            //OS调用JS的方法
            NSString *textJS =[NSString stringWithFormat:@"window.JSInvoker.speech.speek('%@')",@"测试"];
            [self.mJSContext evaluateScript:textJS];
        }

        isLoad = NO;
    }
   
    NSInteger height = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] intValue];
    NSString* javascript = [NSString stringWithFormat:@"window.scrollBy(0, %ld);", (long)height];
    [webView stringByEvaluatingJavaScriptFromString:javascript];
    
    
}
#pragma mark - GestureRecognizer
// 点击背景隐藏
-(void)keyBoardHidden
{
    [self.chatToolBar endEditing:YES];
}
#pragma mark - GestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _tap)
    {
        return YES;
    }
    return NO;
}
#pragma mark -SCrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    int currentPostion = scrollView.contentOffset.y;
    if (currentPostion - _lastPosition > 25) {
        _lastPosition = currentPostion;
       // DLog(@"ScrollUp now");
    }
    else if (_lastPosition - currentPostion > 25)
    {
        _lastPosition = currentPostion;
        if (self.chatToolBar.inputTextView.isFirstResponder) {
            
            [self.chatToolBar endEditing:YES];
        }
    }
}
#pragma mark - DXMessageToolBarDelegate
- (void)inputTextViewWillBeginEditing:(XHMessageTextView *)messageInputTextView{
    
    
}

- (void)didChangeFrameToHeight:(CGFloat)toHeight
{
    [UIView animateWithDuration:0.3 animations:^{
        CGRect rect = self.baseWebView.frame;
        rect.origin.y = 0;
        rect.size.height = self.view.frame.size.height - toHeight;
        self.baseWebView.frame = rect;
    }];
    
}

- (void)didSendText:(NSString *)text
{
    if (text && text.length > 0) {
        [self sendTextMessage:text];
    }
}

/**
 *  按下录音按钮开始录音
 */
- (void)didStartRecordingVoiceAction:(UIView *)recordView
{
    DLog(@"开始录音");
    [[SogouSpeechRecognizer sharedInstance] setRecognizeDelegate:self];
    [[SogouSpeechRecognizer sharedInstance] startListening];
    
    tmpView = (DXRecordView *)recordView;
    tmpView.center = self.view.center;
    [self.view addSubview:tmpView];
    [self.view bringSubviewToFront:recordView];
    
}

/**
 *  手指向上滑动取消录音
 */
- (void)didCancelRecordingVoiceAction:(UIView *)recordView
{
    DLog(@"手指向上滑动取消了录音");
    [[SogouSpeechRecognizer sharedInstance]cancel];
    [[SogouSpeechRecognizer sharedInstance]destroy];
}

/**
 *  松开手指完成录音
 */
- (void)didFinishRecoingVoiceAction:(UIView *)recordView
{
    DLog(@"完成录音");
    [[SogouSpeechRecognizer sharedInstance]stopListening];
}

#pragma mark - method
-(void)loadRequestWithUrlString:(NSString *)urlStr
{
    NSURL * requestUrl = [NSURL URLWithString:urlStr];
    NSURLRequest * request = [NSURLRequest requestWithURL:requestUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeoutInterval];
    
    [self.baseWebView loadRequest:request];
}

//发送文字
-(void)sendTextMessage:(NSString *)textMessage
{
    [self keyBoardHidden];
    DLog(@"发送文字信息");
    //OS调用JS的方法
   NSString *textJS =[NSString stringWithFormat:@"window.JSInvoker.speech.speek('%@')",textMessage];
    [self.mJSContext evaluateScript:textJS];
}
#pragma mark - souGouSpeechDelegate
- (void)onResults:(NSArray*)results confidence:(NSArray *)confidences audioURL:(NSString *)url audioURLValid:(BOOL)url_valid isLastPart:(BOOL)isLastPart
{
    DLog(@"url = %@ ; valid = %d ; last = %d",url, url_valid, isLastPart);
    if (isLastPart) {
        NSString * sayContent = [results objectAtIndex:0];
        [tmpView recordButtonTouchUpInside:sayContent andImageName:@""];
        [self sendTextMessage:sayContent];
        }
   DLog(@"%@",[SogouSpeechRecognizer sharedInstance].resultsArray);
    
}

//返回错误时回调
- (void)onError:(NSError*)error{
     NSString* st = [NSString stringWithFormat:@"%@-code:%ld-%@",error.domain,(long)error.code,[error.userInfo objectForKey:@"reason"]];
      DLog(@"%@",st);
    
    //    ERROR_RECORDER_TIMEOUT =1, //=========识别结果在语音结束后(SGRecognizeTimeOut)秒没有返回结果。
    //    ERROR_NETWORK_STATUS_CODE = 2, //-----网络异常且超重试次数
    //    ERROR_AUDIO = 3,//====================录音任务错误
    //    ERROR_SERVER = 4,//-------------------后端服务器错误
    //    ERROR_CLIENT = 5,//===================客户端错误
    //    ERROR_SPEECH_TIMEOUT = 6,//-----------未检测到有效语音
    //    ERROR_NO_MATCH = 7,//=================无解码结果
    //    ERROR_RECOGNIZER_BUSY = 8,//----------服务器繁忙
    //    ERROR_INSUFFICIENT_PERMISSIONS=9,//===禁止操作，录音权限不足
    //    ERROR_PREPROCESS = 10,//--------------预处理任务错误
    //    ERROR_NETWORK_UNAVAILABLE = 11,//=====网络不可达
    //    ERROR_NETWORK_PROTOCOL = 12,//--------网络协议错误
    //    ERROR_NETWORK_IO = 13,//==============网络IO错误
    //    ERROR_RECORDER_TOO_SHORT = 14,//------录音时间太短
    //    ERROR_RECORDER_TOO_LONG = 15, //------录音时间太长，超过三十秒（按照错误来处理，后续请求将取消）
    NSString * errorStr = nil;
    if (error.code == ERROR_SPEECH_TIMEOUT) {
        errorStr = @"抱歉没听清楚，换个姿势再试试吧！";
    }else if (error.code == ERROR_RECORDER_TOO_SHORT)
    {
        errorStr = @"请说完再试试吧！";
    }else if (error.code == ERROR_RECORDER_TOO_LONG)
    {
        errorStr = @"录音时长超过30秒";
    }else
    {
        errorStr = [error.userInfo objectForKey:@"reason"];
    }
    [tmpView recordButtonTouchUpInside:errorStr andImageName:@"dog"];
//    UIAlertView * alter = [[UIAlertView alloc]initWithTitle:@"你说" message:errorStr delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
//    [alter show];
}

// 录音结束后回调
- (void)onRecordStop{
    
   // recordEnd = [[NSDate date]timeIntervalSince1970];
    
}

-(void)onRecordTimeAtPoint:(float)time
{
    DLog(@"已经录了%f秒，暂时未检测到有效声音",time);
    dispatch_async(dispatch_get_main_queue(), ^{
//        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
//        hud.color = [UIColor grayColor];
//        hud.mode = MBProgressHUDModeText;
//        hud.labelText = @"请继续，我在听";
//        hud.labelColor = [UIColor whiteColor];
//        [hud hide:YES afterDelay:1];
    });
    
}
///*
// 音量回调，取值[0,100]
// 默认以屏幕刷新率进行回调
// */
- (void)onUpdateVolume:(int)volume{
       DLog(@"%f",volume/100.0);
//    [self.micFlowView updateWithLevel:volume/100.0];
}


#pragma mark - setter and getter
- (DXMessageToolBar *)chatToolBar
{
    if (_chatToolBar == nil) {
        _chatToolBar = [[DXMessageToolBar alloc] initWithFrame:CGRectMake(0, ScreenHeight - [DXMessageToolBar defaultHeight], self.view.frame.size.width, [DXMessageToolBar defaultHeight])];
        _chatToolBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
        _chatToolBar.delegate = self;
        
        _chatToolBar.moreView = [[DXChatBarMoreView alloc] initWithFrame:CGRectMake(0, (kVerticalPadding * 2 + kInputTextViewMinHeight), _chatToolBar.frame.size.width, 80) type:ChatMoreTypeChat];
        _chatToolBar.moreView.backgroundColor = [UIColor whiteColor];
        _chatToolBar.moreView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    }
    
    return _chatToolBar;
}


@end
