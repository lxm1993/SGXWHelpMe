//
//  SGHomeSeachDetailController.m
//  SGXwHelp
//
//  Created by lihua on 16/3/3.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import "SGHomeSeachDetailController.h"

@implementation SGHomeSeachDetailController

#pragma mark - lifeCycle
-(void)dealloc{
    
    DLog(@"详情界面内存释放");
    
}
- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem= [[UIBarButtonItem alloc]
                             initWithImage:[UIImage imageNamed:@"com_navigatin_back_bt"]
                             style:UIBarButtonItemStylePlain
                             target:self
                             action:@selector(returnBack:)];
    
    [self loadRequestWithUrlString:self.baseUrl];
    
}
-(void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    [self initViewHeight];
    
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - initial Views
-(void)initViewHeight{
    
    @WeakObj(self);
    [self.baseWebView mas_updateConstraints:^(MASConstraintMaker *make) {
        @StrongObj(self);
        make.edges.equalTo(self.view);
    }];
    
}

#pragma mark - method
-(void)loadRequestWithUrlString:(NSString *)urlStr
{
    DLog(@"SGHomeSeachDetailControllerloadURL===%@",urlStr);
    NSURL * requestUrl = [NSURL URLWithString:urlStr];
    NSURLRequest * request = [NSURLRequest requestWithURL:requestUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:self.timeoutInterval];
    
    [self.baseWebView loadRequest:request];
}
#pragma mark -action 
//用苹果自带的返回键按钮处理如下(自定义的返回按钮)
- (void)returnBack:(UIBarButtonItem *)btn
{
    if ([self.baseWebView canGoBack]) {
        [self.baseWebView goBack];
        
    }else{
        [self.view resignFirstResponder];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - UIWebViewDelegate
-(void)webViewDidFinishLoad:(UIWebView *)webView
{
    [super webViewDidFinishLoad:webView];
    
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
   
}
//如果是H5页面里面自带的返回按钮处理如下:
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    //截获页面内返回
         if (navigationType == UIWebViewNavigationTypeBackForward) {
             
         }
    return YES;
}
@end
