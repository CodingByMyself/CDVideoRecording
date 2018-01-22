//
//  CTPVideoPlayerView.m
//  CDTestVideo
//
//  Created by Cindy on 2018/1/19.
//  Copyright © 2018年 Cindy. All rights reserved.
//

#import "CTPVideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@interface CTPVideoPlayerView ()

@property (strong, nonatomic) AVPlayer *videoPlayer;
@property (strong, nonatomic) AVPlayerItem *playerItem;

@end


@implementation CTPVideoPlayerView


- (instancetype)initWithVideoUrl:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.videoUrl = url;
    }
    return self;
}

- (void)seekToTime:(CGFloat)time
{
    [self.videoPlayer seekToTime:CMTimeMake(time, 1)];
}

- (void)play
{
    [_videoPlayer pause];
    if (self.videoPlayer.currentItem == nil) {
        [self.videoPlayer replaceCurrentItemWithPlayerItem:self.playerItem];
    }
    [self.videoPlayer play];
}

- (void)pause
{
    [self.videoPlayer pause];
}

#pragma mark - getter Method
- (AVPlayer *)videoPlayer
{
    if (_videoPlayer == nil) {
        self.backgroundColor = [UIColor blackColor];
        _videoPlayer = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_videoPlayer];
        layer.frame = self.bounds;
        layer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self.layer addSublayer:layer];
    }
    return _videoPlayer;
}

- (AVPlayerItem *)playerItem
{
    if (_playerItem == nil) {
        _playerItem = [[AVPlayerItem alloc] initWithURL:self.videoUrl];
    }
    return _playerItem;
}

#pragma mark - Setter  Method
- (void)setVideoUrl:(NSURL *)videoUrl
{
    _videoUrl = videoUrl;
    _playerItem = nil;
}


@end
