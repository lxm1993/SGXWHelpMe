//
//  NDDefaultView.m
//  Need
//
//  Created by tcl on 15/8/26.
//  Copyright (c) 2015年 weplanter. All rights reserved.
//

#import "SGDefaultView.h"
#import "Masonry.h"
#define WidthScale ([UIScreen mainScreen].bounds.size.width/375)
#define HeightScale ([UIScreen mainScreen].bounds.size.height/667)

@implementation SGDefaultView

-(id)initWithFrame:(CGRect)frame AndY:(NSInteger)Y DefaultView:(NSString *)image AndText:(NSString *)text AndButton:(NSString *)buttonText AndBlock:(void (^)(UIButton *))a
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor whiteColor];
        UIImage *defaultImage = [UIImage imageNamed:image];
        CGSize imageSize = defaultImage.size;
        UIImageView *defaultImageView = [UIImageView new];
        defaultImageView.image = defaultImage;
        [self addSubview:defaultImageView];
         @WeakObj(self);
        [defaultImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            @StrongObj(self);
            make.centerX.equalTo(self);
            make.top.equalTo(self).with.offset(Y*HeightScale);
            make.width.mas_equalTo(imageSize.width);
            make.height.mas_equalTo(imageSize.height);
        }];
        
        UILabel *textLabel = [UILabel new];
        textLabel.text = text;
        textLabel.font = [UIFont systemFontOfSize:14.0];
        textLabel.textColor = UIColorWithRGB(0xB8B8B8);
        textLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:textLabel];
        [textLabel mas_makeConstraints:^(MASConstraintMaker *make) {
             @StrongObj(self);
            make.centerX.equalTo(self);
            make.top.equalTo(defaultImageView.mas_bottom).with.offset(5*HeightScale);
            make.width.equalTo(self);
            make.height.mas_equalTo(@(20*HeightScale));
        }];
        
        if (buttonText != nil)
        {
            self.myBlock = a;
            UIButton *btn = [UIButton new];
            btn.layer.borderColor = UIColorWithRGB(0xEE4F4E).CGColor;
            btn.layer.borderWidth = 1;
            btn.layer.cornerRadius = 15;
            btn.layer.masksToBounds = YES;
            [btn setTitle:buttonText forState:UIControlStateNormal];
            [btn setTitleColor:UIColorWithRGB(0xEE4F4E) forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                @StrongObj(self);
                make.top.equalTo(textLabel.mas_bottom).with.offset(20*HeightScale);
                make.centerX.equalTo(self);
                make.width.mas_equalTo(@(98*WidthScale));
                make.height.mas_equalTo(@(30));
            }];
        }
    }
    return self;
}

-(void)click:(UIButton *)btn
{
    if (self.myBlock)
    {
        self.myBlock(btn);
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
