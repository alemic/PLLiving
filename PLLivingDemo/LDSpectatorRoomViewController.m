//
//  LDSpectatorRoomViewController.m
//  PLLivingDemo
//
//  Created by TaoZeyu on 16/7/19.
//  Copyright © 2016年 com.pili-engineering. All rights reserved.
//

#import "LDSpectatorRoomViewController.h"
#import "LDRoomPanelViewController.h"
#import "LDAlertUtil.h"

@interface LDSpectatorRoomViewController () <PLPlayerDelegate, LDRoomPanelViewControllerDelegate>
@property (nonatomic, assign) BOOL didPlayFirstFrame;
@property (nonatomic, strong) PLPlayer *player;
@property (nonatomic, strong) LDRoomPanelViewController *roomPanelViewControoler;
@property (nonatomic, strong) UIView *playerContainerView;
@property (nonatomic, strong) UIButton *closeButton;
@end

@implementation LDSpectatorRoomViewController

- (instancetype)initWithURL:(NSURL *)url
{
    if (self = [super init]) {
        self.player = [PLPlayer playerWithURL:url option:[PLPlayerOption defaultOption]];
        self.player.delegate = self;
        self.roomPanelViewControoler = [[LDRoomPanelViewController alloc] initWithMode:LDRoomPanelViewControllerMode_Spectator];
        self.roomPanelViewControoler.delegate = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.playerContainerView = ({
        UIView *container = [[UIView alloc] init];
        [self.view addSubview:container];
        container.frame = self.view.bounds;
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleTopMargin |
                                     UIViewAutoresizingFlexibleBottomMargin;
        container;
    });
    ({
        UIView *view = self.player.playerView;
        [self.playerContainerView addSubview:view];
        view.alpha = 0; //在播放器播出第一帧画面前，隐藏它，使观众不至于只能看到一片漆黑。
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.left.and.right.equalTo(self.playerContainerView);
        }];
    });
    ({
        UIView *view = self.roomPanelViewControoler.view;
        [self.view addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.left.and.right.equalTo(self.view);
        }];
    });
    self.closeButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.view addSubview:button];
        [button setTitle:@"X" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor redColor]];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).with.offset(40);
            make.right.equalTo(self.view).with.offset(-20);
        }];
        button;
    });
    [self.closeButton addTarget:self action:@selector(_onPressedCloseButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.player play];
}

- (void)onKeyboardWasShownWithHeight:(CGFloat)keyboardHeight withDuration:(NSTimeInterval)duration
{
    CGRect frame = self.view.bounds;
    frame.origin.y = -keyboardHeight/2;
    
    [UIView animateWithDuration:duration animations:^{
        self.playerContainerView.frame = frame;
    }];
}

- (void)onKeyboardWillBeHiddenWithDuration:(NSTimeInterval)duration
{
    [UIView animateWithDuration:duration animations:^{
        self.playerContainerView.frame = self.view.bounds;
    }];
}

- (void)player:(nonnull PLPlayer *)player statusDidChange:(PLPlayerStatus)state
{
    if (state == PLPlayerStatusReady && // 播放器已经完全准备好，可以播放出第一帧了。
        !self.didPlayFirstFrame) {
        [UIView animateWithDuration:0.7 animations:^{
            player.playerView.alpha = 1.0;
        }];
    }
}

- (void)player:(nonnull PLPlayer *)player stoppedWithError:(nullable NSError *)error
{
    // 该方法调用的时候，player 已经因为错误的停止了。
    // 如果这个错误能被处理，在处理完这个错误以后，应该调用 [self.player start]，让播放器重新开始播放。
    // 不过这里我没有处理这个错误，仅仅弹出错误信息就退出房间了。
    NSString *title = LDString("player-found-error-and-have-to-exit");
    NSString *message = [NSString stringWithFormat:@"%@", error];
    [LDAlertUtil alertParentViewController:self title:title error:message complete:^{
        [self.basicViewController removeViewController:self animated:NO completion:nil];
    }];
}

- (void)_onPressedCloseButton:(UIButton *)button
{
    [self.player stop];
    [self.basicViewController removeViewController:self animated:NO completion:nil];
}

@end
