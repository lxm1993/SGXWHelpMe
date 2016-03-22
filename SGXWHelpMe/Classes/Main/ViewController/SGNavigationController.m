//
//  NDNavControllerViewController.m
//  Need
//
//  Created by 刘哓敏 on 15/10/9.
//  Copyright (c) 2015年 weplanter. All rights reserved.
//

#import "SGNavigationController.h"


@interface UINavigationController (UINavigationControllerNeedShouldPopItem)

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wincomplete-implementation"
@implementation UINavigationController (UINavigationControllerNeedShouldPopItem)
@end
#pragma clang diagnostic pop

@interface SGNavigationController ()<UINavigationBarDelegate,UINavigationControllerDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, weak) UIViewController *currentShowVC;
@end

@implementation SGNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
   
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
   
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {

    
    if (self = [super initWithRootViewController:rootViewController]) {
        self.delegate = self;
        self.interactivePopGestureRecognizer.delegate = self;
        // 设置navigationBar是否透明，不透明的话会使可用界面原点下移（0，0）点为导航栏左下角下方的那个点
        self.navigationBar.translucent = NO;
        // 设置navigationBar是不是使用系统默认返回，默认为YES
        self.interactivePopGestureRecognizer.enabled = YES;
        // 设置navigationBar的背景颜色，根据需要自己设置
        self.navigationBar.barTintColor = kNavBarTintColor;
        // 设置navigationBar元素的背景颜色，不包括title
        self.navigationBar.tintColor = KCommentColor;
        // 设置navigationController的title的字体颜色
        NSDictionary * dict=[NSDictionary dictionaryWithObject:kMainBlackColor forKey:NSForegroundColorAttributeName];
        self.navigationBar.titleTextAttributes = dict;
        
        // 统一替换 back item 的图片
        UIImage * image = [UIImage imageNamed:@"com_navigatin_back_bt"];
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        [self.navigationBar setBackIndicatorImage:image];
        [self.navigationBar setBackIndicatorTransitionMaskImage:image];
    }
    
    return self;
}

#pragma mark - UINavigationBarDelegate
-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if(self.viewControllers.count>0){
        viewController.hidesBottomBarWhenPushed=YES; //当push 的时候隐藏底部兰
    }
    [super pushViewController:viewController animated:animated];
    
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (1 == navigationController.viewControllers.count) {
        
        self.currentShowVC = nil;
    } else {
        self.currentShowVC = viewController;
    }
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.interactivePopGestureRecognizer) {
        return (self.currentShowVC == self.topViewController);
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] &&
        [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        return YES;
    } else {
        return NO;
    }
}
//解决：手指在滑动的时候，被 pop 的 ViewController 中的 UIScrollView 会跟着一起滚动
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [gestureRecognizer isKindOfClass:UIScreenEdgePanGestureRecognizer.class];
}
@end
