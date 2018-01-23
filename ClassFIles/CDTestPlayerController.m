//
//  CDTestPlayerController.m
//  CDTestVideo
//
//  Created by Cindy on 2018/1/19.
//  Copyright © 2018年 Cindy. All rights reserved.
//

#import "CDTestPlayerController.h"
#import "Masonry.h"
#import "CTPVideoPlayerView.h"

@interface CDTestPlayerController ()
@property (nonatomic,strong) UIView *viewNavigation;
@property (nonatomic,strong) CTPVideoPlayerView *playerView;@end

@implementation CDTestPlayerController

- (instancetype)initWithVideoURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.playerView.videoUrl = url;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"视频预览";
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(back)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"重放" style:UIBarButtonItemStyleDone target:self action:@selector(replay)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.playerView play];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

#pragma mark - IBAction
- (void)replay
{
    [self.playerView seekToTime:0];
    [self.playerView play];
}

- (void)back
{
    [self.playerView pause];
    _playerView = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.navigationController.navigationBarHidden) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
}

#pragma makr - Getter Method
- (UIView *)viewNavigation
{
    if (_viewNavigation == nil) {
        _viewNavigation = [[UIView alloc] init];
        _viewNavigation.backgroundColor = [UIColor blackColor];
        [self.view addSubview:_viewNavigation];
        [_viewNavigation mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.top.equalTo(self.view);
            make.height.equalTo(@64.0);
        }];
    }
    [self.view layoutIfNeeded];
    return _viewNavigation;
}




- (CTPVideoPlayerView *)playerView
{
    if (_playerView == nil) {
        _playerView = [[CTPVideoPlayerView alloc] initWithVideoUrl:nil];
        _playerView.backgroundColor = [UIColor cyanColor];
        [self.view addSubview:_playerView];
        [_playerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(_playerView.superview);
        }];
    }
    [self.view layoutIfNeeded];
    return _playerView;
}

@end
