//
//  SGBaseViewController.m
//  SGXWHelpMe
//
//  Created by lihua on 16/3/4.
//  Copyright © 2016年 sogouSearch. All rights reserved.
//

#import "SGBaseViewController.h"

@interface SGBaseViewController ()

@end

@implementation SGBaseViewController

#pragma mark - lifeCycle
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self baseInitialObjects];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self baseInitialObjects];
    }
    return self;
}

- (void)baseInitialObjects
{
    self.devie = [DeviceManage deviceManage];
   
    //适配导航跨层跳转，在viewDidLoad中不执行的问题。
    UIBarButtonItem *returnButtonItem = [[UIBarButtonItem alloc] init];
    returnButtonItem.title = @" ";
    self.navigationItem.backBarButtonItem = returnButtonItem;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
