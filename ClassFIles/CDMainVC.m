//
//  CDMainVC.m
//  CDTestVideo
//
//  Created by Cindy on 2017/10/9.
//  Copyright © 2017年 Cindy. All rights reserved.
//

#import "CDMainVC.h"
#import "Masonry.h"
#import "CTPCameraVideoController.h"
#import "CDTestPlayerController.h"

@interface CDMainVC ()

@property (nonatomic,strong) UIButton *buttonVideo;

//@property (nonatomic,strong) CTPVideoPlayerView *videoPlayer;

@end

@implementation CDMainVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"MAIN";
    
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    self.buttonVideo.backgroundColor = [UIColor whiteColor];
    [self.buttonVideo addTarget:self action:@selector(buttonVideoClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)buttonVideoClickedEvent:(UIButton *)button
{
    NSLog(@"事件");
    CTPCameraVideoController *cameraController = [CTPCameraVideoController defaultCameraController];
    
    __weak CTPCameraVideoController *weakCameraController = cameraController;
    
    cameraController.takePhotosCompletionBlock = ^(UIImage *image, NSError *error) {
        NSLog(@"takePhotosCompletionBlock");
        
        [weakCameraController dismissViewControllerAnimated:YES completion:nil];
    };
    
    cameraController.shootCompletionBlock = ^(NSURL *videoUrl, CGFloat videoTimeLength, UIImage *thumbnailImage, NSError *error) {
        NSLog(@"shootCompletionBlock");
        NSLog(@"保存路径：%@",videoUrl);
        [weakCameraController dismissViewControllerAnimated:YES completion:nil];
        
        NSError *errorInfo = nil;
        
        NSDictionary *attri = [[NSFileManager defaultManager] attributesOfItemAtPath:videoUrl.path error:&errorInfo];
        NSLog(@"errorInfo : %@",errorInfo);
        NSLog(@"%@",attri);
        CGFloat sizeM = [attri fileSize]/1000.0/1000.0;
        NSLog(@"NSFileSize = %.2f M",sizeM);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CDTestPlayerController *playerVC = [[CDTestPlayerController alloc] initWithVideoURL:videoUrl];
            [self presentViewController:[[UINavigationController alloc] initWithRootViewController:playerVC] animated:YES completion:nil];
        });
        
    };
    
    [self presentViewController:cameraController animated:YES completion:nil];
    
}

#pragma mark - Getter Method
- (UIButton *)buttonVideo
{
    if (_buttonVideo == nil) {
        _buttonVideo = [[UIButton alloc] init];
        [_buttonVideo setTitle:@"test take video" forState:UIControlStateNormal];
        [_buttonVideo setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        
        [self.view addSubview:_buttonVideo];
        [_buttonVideo mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.centerY.equalTo(self.view);
            make.height.equalTo(@(40.0));
        }];
    }
    return _buttonVideo;
}

//- (CTPVideoPlayerView *)videoPlayer
//{
//    if (_videoPlayer == nil) {
//        _videoPlayer = [[CTPVideoPlayerView alloc] initWithVideoUrl:nil];
//        _videoPlayer.backgroundColor = [UIColor cyanColor];
//        [self.view addSubview:_videoPlayer];
//        [_videoPlayer mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.left.equalTo(_videoPlayer.superview).offset(30.0);
//            make.right.equalTo(_videoPlayer.superview).offset(-30.0);
//            make.bottom.equalTo(_videoPlayer.superview).offset(-30.0);
//            make.height.equalTo(_videoPlayer.mas_width);
//        }];
//    }
//    [self.view layoutIfNeeded];
//    return _videoPlayer;
//}


@end
