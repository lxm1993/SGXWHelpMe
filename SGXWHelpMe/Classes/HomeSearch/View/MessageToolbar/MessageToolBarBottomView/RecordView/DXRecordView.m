/************************************************************
  *  * EaseMob CONFIDENTIAL 
  * __________________ 
  * Copyright (C) 2013-2014 EaseMob Technologies. All rights reserved. 
  *  
  * NOTICE: All information contained herein is, and remains 
  * the property of EaseMob Technologies.
  * Dissemination of this information or reproduction of this material 
  * is strictly forbidden unless prior written permission is obtained
  * from EaseMob Technologies.
  */

#import "DXRecordView.h"
//#import "EMCDDeviceManager.h"
@interface DXRecordView ()
{
    NSTimer *_timer;
    // 显示动画的ImageView
    UIImageView *_recordAnimationView;
    // 提示文字
    UILabel *_textLabel;
}

@end

@implementation DXRecordView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        UIView *bgView = [[UIView alloc] initWithFrame:self.bounds];
        bgView.backgroundColor = [UIColor grayColor];
        bgView.layer.cornerRadius = 5;
        bgView.layer.masksToBounds = YES;
//        bgView.alpha = 0.8;
        [self addSubview:bgView];
        
        _recordAnimationView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width , self.bounds.size.height - 35)];
        
        
        _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(5,
                                                               CGRectGetMaxY(_recordAnimationView.frame)+5,
                                                               self.bounds.size.width - 10,
                                                               25)];
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.font = [UIFont systemFontOfSize:13];
        _textLabel.textColor = [UIColor whiteColor];
        _textLabel.layer.cornerRadius = 5;
        _textLabel.layer.borderColor = [[UIColor redColor] colorWithAlphaComponent:0.5].CGColor;
        _textLabel.layer.masksToBounds = YES;
        
        [self addSubview:_recordAnimationView];
        [self addSubview:_textLabel];
    }
    return self;
}

// 录音按钮按下
-(void)recordButtonTouchDown
{
    // 需要根据声音大小切换recordView动画
    _textLabel.text = kFingersToOutSideCancleRecord;
    _textLabel.backgroundColor = [UIColor clearColor];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                              target:self
                                            selector:@selector(setVoiceImage)
                                            userInfo:nil
                                             repeats:NO];
    
}
// 手指在录音按钮内部时离开
-(void)recordButtonTouchUpInside:(NSString *)text andImageName:(NSString *)imageName;
{
    [self stopImageViewAnnimation];
    _textLabel.text = text;
    _recordAnimationView.image = [UIImage imageNamed:imageName];
    _textLabel.backgroundColor = [UIColor clearColor];
     [_timer invalidate];
    [self performSelector:@selector(dimissAlertView) withObject:nil afterDelay:1.5f];
}
- (void)dimissAlertView{
     [self removeFromSuperview];
}
// 手指在录音按钮外部时离开
-(void)recordButtonTouchUpOutside
{
    [self stopImageViewAnnimation];
    [_timer invalidate];
}
// 手指移动到录音按钮内部
-(void)recordButtonDragInside
{
     [self stopImageViewAnnimation];
    _textLabel.text = kFingersUpCancleRecord;
    _textLabel.backgroundColor = [UIColor clearColor];
}

// 手指移动到录音按钮外部
-(void)recordButtonDragOutside
{
     [self stopImageViewAnnimation];
    _textLabel.text = kFingersUpCancleRecord;
     _recordAnimationView.image = [UIImage imageNamed:@"cancleRecordImage"];
    _textLabel.backgroundColor = [UIColor clearColor];
}

-(void)stopImageViewAnnimation
{
    if (_recordAnimationView.isAnimating) {
        
        [_recordAnimationView stopAnimating];
        _recordAnimationView.animationImages = nil;

    }
}
-(void)setVoiceImage {
    
    //设置动画帧
    NSMutableArray *arr = [[NSMutableArray alloc]init];
    for (int i = 1; i<=20; i++)
    {
        NSString *str =[ [NSString alloc]initWithFormat:@"VoiceSearchFeedback0%02d.png",i ];
        UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] bundlePath], str]];
        [arr addObject:image];
    }
       _recordAnimationView.animationImages =(NSArray *)arr;
    //设置动画总时间
    _recordAnimationView.animationDuration=2.3;
    //设置重复次数,0表示不重复
    _recordAnimationView.animationRepeatCount=0;
    //开始动画
    [_recordAnimationView startAnimating];

    
}

@end
