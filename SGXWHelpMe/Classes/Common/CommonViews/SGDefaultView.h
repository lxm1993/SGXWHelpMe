//
//  NDDefaultView.h
//  Need
//
//  Created by tcl on 15/8/26.
//  Copyright (c) 2015年 weplanter. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SGDefaultView : UIView

@property(nonatomic,copy)void(^myBlock)(UIButton *);

- (id)initWithFrame:(CGRect)frame AndY:(NSInteger)Y DefaultView:(NSString *)image AndText:(NSString *)text AndButton:(NSString *)buttonText AndBlock:(void(^)(UIButton*))a;

@end
