//
//  CTPVideoPlayerView.h
//  CDTestVideo
//
//  Created by Cindy on 2018/1/19.
//  Copyright © 2018年 Cindy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CTPVideoPlayerView : UIView

@property (nonatomic,strong) NSURL *videoUrl;

- (instancetype)initWithVideoUrl:(NSURL *)url;
- (void)seekToTime:(CGFloat)time;
- (void)play;
- (void)pause;

@end
