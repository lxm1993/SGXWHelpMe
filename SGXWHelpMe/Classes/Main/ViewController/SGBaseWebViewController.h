//
//  SGBaseWebViewController.h
//  SGXwHelp
//
//  Created by lihua on 16/3/3.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SGBaseViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>

@interface SGBaseWebViewController : SGBaseViewController

@property (nonatomic, strong) UIWebView *baseWebView;
@property (nonatomic, assign, readonly)  NSTimeInterval timeoutInterval;
 @property JSContext *mJSContext;

- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webViewDidFinishLoad:(UIWebView *)webView;


@end
