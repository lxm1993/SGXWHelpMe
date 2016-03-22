//
//  SGBaseWebViewController.m
//  SGXwHelp
//
//  Created by lihua on 16/3/3.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import "SGBaseWebViewController.h"


#import <NJKWebViewProgress.h>
#import <NJKWebViewProgressView.h>
#import "SNLocationManager.h"

#import "SGDefaultView.h"

#import "SGHomeSeachDetailController.h"

const static NSTimeInterval webTimeInterval = 60;

@interface SGBaseWebViewController ()<UIWebViewDelegate,NJKWebViewProgressDelegate>
{
@private
    NJKWebViewProgress *mProgressPoxy;
    NJKWebViewProgressView *mProgressView;
}

@property (nonatomic,  strong) SGDefaultView *failLoadingView;
@property (nonatomic,  assign) NSTimeInterval  timeoutInterval;
@property (nonatomic,  strong) CLLocation  *location;

@end

@implementation SGBaseWebViewController

#pragma mark - lifeCycle
- (void)dealloc{
    
    DLog(@"基类webView内存释放");
    _baseWebView.delegate = nil;
    [ _baseWebView loadHTMLString:@"" baseURL:nil];
    [ _baseWebView stopLoading];
    [ _baseWebView removeFromSuperview];
    if (_failLoadingView) {
        [_failLoadingView removeFromSuperview];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.timeoutInterval = webTimeInterval;
       
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.baseWebView = [UIWebView new];
    _baseWebView.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_baseWebView];
    
    mProgressPoxy = [NJKWebViewProgress new];
    _baseWebView.delegate = mProgressPoxy;
    mProgressPoxy.webViewProxyDelegate = self;
    mProgressPoxy.progressDelegate = self;
    
    CGFloat progressBarHeight = 1.0f;
    CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight, navigationBarBounds.size.width, progressBarHeight);
    mProgressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    mProgressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.navigationController.navigationBar addSubview:mProgressView];
    
    [[SNLocationManager shareLocationManager] startUpdatingLocationWithSuccess:^(CLLocation *location, CLPlacemark *placemark) {
        self.location = location;
    } andFailure:^(CLRegion *region, NSError *error) {
        
    }];


    
}


-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // Remove progress view
    // because UINavigationBar is shared with other ViewControllers
    [mProgressView removeFromSuperview];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark -method

//JS与iOS的方法
-(void)jsGetInfoFromIos:(UIWebView *)webView{
    
    //首先创建JSContext 对象（此处通过当前webView的键获取到jscontext）
    _mJSContext=[webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    
    //异常
    
    _mJSContext.exceptionHandler = ^(JSContext *context, JSValue *exceptionValue) {
        context.exception = exceptionValue;
        DLog(@"%@", exceptionValue);
    };
    
    //在JS中添加了方法指针提供给JS调用
    
    @WeakObj(self);
    _mJSContext[@"jSInvokerGetMid"] = ^(void){
         DLog(@"JS获取UUID");
        
        @StrongObj(self);
        return  self.devie.mac;
    };
    
    _mJSContext[@"jSInvokerGetLocation"] = ^(void){
          DLog(@"JS获取坐标");
        
        @StrongObj(self);
        id devicePoint = @{
                           @"latitude": [NSString stringWithFormat:@"%f", self.location.coordinate.latitude],
                           @"longitude": [NSString stringWithFormat:@"%f", self.location.coordinate.longitude]
                           };
        return devicePoint;
        
    };
    
    _mJSContext[@"jSInvokerGetUserSgid"] = ^(void){
        DLog(@"JS用户的ID");
        return @"UserId";
    };
    
    _mJSContext[@"jSInvokerSpeechSubView"] = ^(void){
        DLog(@"将要进行界面跳转由h5界面跳转到原生界面");
        
        @StrongObj(self);
        NSArray *args = [JSContext currentArguments];
       JSValue * value = args[0];
        NSString * str = value.toString;
    //必须放入主线程中更新UI否则会出错
    dispatch_async(dispatch_get_main_queue(), ^{
        SGHomeSeachDetailController * detailViewCon = [[SGHomeSeachDetailController alloc]init];
        detailViewCon.baseUrl = str;
        [self.navigationController pushViewController: detailViewCon animated:YES];

        });
        
    };

    //iOS调用JS进行初始化
    
    NSString *textJS = @"window.ios_callback('这里是JS中alert弹出的message')";
    [_mJSContext evaluateScript:textJS];


}

#pragma mark - NJKWebViewProgressDelegate
-(void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress{
    
    [mProgressView setProgress:progress animated:YES];
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    
    NSURL *url = [request URL];
    DLog(@"scheme : %@",[url scheme]);
    DLog(@"host : %@",[url host]);
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        
        SGHomeSeachDetailController * detailViewCon = [[SGHomeSeachDetailController alloc]init];
        detailViewCon.baseUrl = url.absoluteString;
        [self.navigationController pushViewController:detailViewCon animated:YES];
        return NO;
    }
    return YES;

}
- (void)webViewDidStartLoad:(UIWebView *)webView{
    
     mProgressView.progressBarView.backgroundColor = [UIColor blueColor];
}


- (void)webViewDidFinishLoad:(UIWebView *)webView{
    
    //加载完成后进度颜色
    mProgressView.progressBarView.backgroundColor = [UIColor clearColor];
    [self.failLoadingView removeFromSuperview];
    [self  jsGetInfoFromIos:webView];
    //内存释放对象销毁
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDiskImageCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitOfflineWebApplicationCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    
    mProgressView.progressBarView.backgroundColor = [UIColor clearColor];
    //如果load一个url还没结束就立即load另一个url，那么就会callback didFailLoadWithError method，error code is -999
    if ([error code] != NSURLErrorCancelled) {
        
        self.failLoadingView = [[SGDefaultView alloc] initWithFrame:self.view.bounds AndY:100 DefaultView:@"no_network_img" AndText:@"Ooops！网络不好..." AndButton:@"刷新"AndBlock:nil];
        [self.view addSubview:_failLoadingView];
        
    }
}
@end
