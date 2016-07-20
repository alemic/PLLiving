//
//  LDRoomPanelViewController.m
//  PLLivingDemo
//
//  Created by TaoZeyu on 16/7/20.
//  Copyright © 2016年 com.pili-engineering. All rights reserved.
//

#import "LDRoomPanelViewController.h"
#import "LDTouchTransparentView.h"
#import "LDChatDataSource.h"
#import "LDChatBubbleView.h"
#import "LDChatItem.h"

@interface LDRoomPanelViewController () <UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, assign) LDRoomPanelViewControllerMode mode;
@property (nonatomic, assign) CGFloat presetKeyboardHeight;
@property (nonatomic, strong) LDTouchTransparentView *containerView;
@property (nonatomic, strong) LDChatDataSource *chatDataSource;
@property (nonatomic, strong) UITableView *chatTableView;
@property (nonatomic, strong) UITextField *chatTextField;
@property (nonatomic, strong) UIButton *spectatorListButton;
@property (nonatomic, strong) UIButton *sharingButton;
@end

@interface _LDRoomPanelView : LDTouchTransparentView
@property (nonatomic, readonly) LDRoomPanelViewController *roomPanelViewController;
- (instancetype)initWithRomPanelViewController:(LDRoomPanelViewController *)roomPanelViewController;
@end

@implementation LDRoomPanelViewController

- (instancetype)initWithMode:(LDRoomPanelViewControllerMode)mode
{
    if (self = [self init]) {
        _mode = mode;
        _chatDataSource = [[LDChatDataSource alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView
{
    self.view = ({
        _LDRoomPanelView *view = [[_LDRoomPanelView alloc] initWithRomPanelViewController:self];
        if (self.mode == LDRoomPanelViewControllerMode_Spectator) {
            // 只有主播才需要 touch 后面的 preview 来调节摄像头 focus。
            // 观众的房间后面是 player，就算遮蔽了也没有关系。
            view.maskAllScreen = YES;
        }
        view;
    });
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.containerView = ({
        LDTouchTransparentView *view = [[LDTouchTransparentView alloc] init];
        view.frame = [UIScreen mainScreen].bounds;
        [self.view addSubview:view];
        view.maskAllScreen = NO;
        view;
    });
    
    UIView *bottomBar = ({
        UIView *bar = [[UIView alloc] init];
        [self.containerView addSubview:bar];
        bar.backgroundColor = [UIColor whiteColor];
        [bar mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.and.bottom.equalTo(self.containerView);
            make.height.mas_equalTo(klayRoomPanelBottomBarHeight);
        }];
        bar;
    });
    self.spectatorListButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [bottomBar addSubview:button];
        [button setTitle:@"观" forState:UIControlStateNormal];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.bottom.equalTo(bottomBar);
            make.left.equalTo(bottomBar);
        }];
        button;
    });
    self.sharingButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [bottomBar addSubview:button];
        [button setTitle:@"享" forState:UIControlStateNormal];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.bottom.equalTo(bottomBar);
            make.right.equalTo(bottomBar);
        }];
        button;
    });
    
    if (self.mode == LDRoomPanelViewControllerMode_Spectator) {
        // 主播不能打字，她可以直接通过麦克风说话。只有观众需要打字。
        self.chatTextField = ({
            UITextField *field = [[UITextField alloc] init];
            field.delegate = self;
            [bottomBar addSubview:field];
            [field mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.and.bottom.equalTo(bottomBar);
                make.left.equalTo(self.spectatorListButton.mas_right);
                make.right.equalTo(self.sharingButton.mas_left);
            }];
            field;
        });
    }
    
    self.chatTableView = ({
        UITableView *tableView = [[UITableView alloc] init];
        [self.containerView addSubview:tableView];
        
        tableView.backgroundColor = [UIColor clearColor];
        [tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [tableView setShowsVerticalScrollIndicator:NO];
        tableView.estimatedRowHeight = 44.5;
        tableView.rowHeight = UITableViewAutomaticDimension;
        
        tableView.dataSource = self.chatDataSource;
        [tableView registerClass:[LDChatBubbleView class] forCellReuseIdentifier:LDChatBubbleViewIdentifer];
        [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.left.and.right.equalTo(self.containerView);
            make.bottom.equalTo(bottomBar.mas_top);
        }];
        tableView;
    });
    [self addNotifications];
}

- (void)addNotifications
{
    NSNotificationCenter *notificationCenger = [NSNotificationCenter defaultCenter];
    [notificationCenger addObserver:self selector:@selector(_onFoundKeyboardWasShown:)
                               name:UIKeyboardWillShowNotification object:nil];
    [notificationCenger addObserver:self selector:@selector(_onFoundKeyboardWillBeHidden:)
                               name:UIKeyboardWillHideNotification object:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSString *message = [textField.text stringByReplacingOccurrencesOfRegex:@"(^\\s+|\\s+$)" withString:@""];
    if (![message isEqualToString:@""]) {
        LDChatItem *chatItem = [[LDChatItem alloc] init];
        chatItem.message = message;
        [self.chatDataSource addChatItem:chatItem];
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForRow:self.chatDataSource.count - 1 inSection:0];
        [self.chatTableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationRight];
        [self.chatTableView reloadData];
    } else {
        [self.chatTextField resignFirstResponder];
    }
    self.chatTextField.text = @"";
    
    return YES;
}

- (void)_onFoundKeyboardWasShown:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    self.presetKeyboardHeight = MIN(keyboardFrame.size.width, keyboardFrame.size.height);
    [UIView animateWithDuration:duration animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
    if ([self.delegate respondsToSelector:@selector(onKeyboardWasShownWithHeight:withDuration:)]) {
        [self.delegate onKeyboardWasShownWithHeight:self.presetKeyboardHeight withDuration:duration];
    }
}

- (void)_onFoundKeyboardWillBeHidden:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    self.presetKeyboardHeight = 0;
    [UIView animateWithDuration:duration animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
    if ([self.delegate respondsToSelector:@selector(onKeyboardWasShownWithHeight:withDuration:)]) {
        [self.delegate onKeyboardWillBeHiddenWithDuration:duration];
    }
}

@end

@implementation _LDRoomPanelView

- (instancetype)initWithRomPanelViewController:(LDRoomPanelViewController *)roomPanelViewController
{
    if (self = [self init]) {
        _roomPanelViewController = roomPanelViewController;
    }
    return self;
}

- (void)layoutSubviews
{
    CGRect frame = self.bounds;
    frame.origin.y = -_roomPanelViewController.presetKeyboardHeight;
    for (UIView *subview in self.subviews) {
        subview.frame = frame;
    }
    [super layoutSubviews];
}

@end
