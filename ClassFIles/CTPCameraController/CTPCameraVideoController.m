//
//  CTPCameraVideoController.m
//  CDTestVideo
//
//  Created by Cindy on 2017/10/9.
//  Copyright © 2017年 Cindy. All rights reserved.
//

#import "CTPCameraVideoController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "CTPVideoWriterManager.h"
#import "CTPCameraButton.h"
#import "CTPPhotoLibraryManager.h"
#import "Masonry.h"
#import <Photos/Photos.h>
#import <CoreMotion/CoreMotion.h>


#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

#define TIMER_INTERVAL 0.01f                                        //定时器记录视频间隔
#define VIDEO_RECORDER_MAX_TIME 10.0f                               //视频最大时长 (单位/秒)
#define VIDEO_RECORDER_MIN_TIME 1.0f                                //最短视频时长 (单位/秒)
#define START_VIDEO_ANIMATION_DURATION 0.2f                         //录制视频前的动画时间



@interface CTPCameraVideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate>
{
    CGFloat timeLength;             //时间长度
}

@property (nonatomic, strong) CTPVideoWriterManager *videoWriterManager;
@property (nonatomic, assign) BOOL canWrite;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;      //预览图层

@property (nonatomic, strong) NSTimer *timer;                                            //记录录制时间

@property (strong, nonatomic) UIView *viewContainer;
@property (strong, nonatomic) UIButton *buttonRotateCamera; // 转换摄像头
//@property (weak, nonatomic) IBOutlet UIButton *takeButton;                               //拍摄按钮
@property (strong, nonatomic) UIButton *buttonClose;
@property (strong, nonatomic) UILabel *labelTip;
@property (strong, nonatomic) CTPCameraButton *buttonTakeCamera;                              //拍摄按钮

@property (strong, nonatomic) UIImageView *imageViewFocus;                        //聚焦视图
@property (assign, nonatomic) Boolean isFocusing;                                        //镜头正在聚焦
@property (assign, nonatomic) Boolean isShooting;                                        //正在拍摄
@property (assign, nonatomic) Boolean isRotatingCamera;                                  //正在旋转摄像头

//捏合缩放摄像头
@property (nonatomic,assign) CGFloat beginGestureScale;                                  //记录开始的缩放比例
@property (nonatomic,assign) CGFloat effectiveScale;                                     //最后的缩放比例

// 拍照摄像后的预览模块
@property (strong, nonatomic) UIButton *buttonCancel;
@property (strong, nonatomic) UIButton *buttonConfirm;
@property (strong, nonatomic) UIView *photoPreviewContainerView;                         //相片预览ContainerView
@property (strong, nonatomic) UIImageView *photoPreviewImageView;                        //相片预览ImageView
@property (strong, nonatomic) UIView *videoPreviewContainerView;                         //视频预览View
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (assign, nonatomic) CGFloat currentVideoTimeLength;                             //当前小视频总时长

@property (assign, nonatomic) UIDeviceOrientation shootingOrientation;                 //拍摄中的手机方向
@property (strong, nonatomic) CMMotionManager *motionManager;

@end

@implementation CTPCameraVideoController

#pragma mark - 工厂方法

+ (instancetype)defaultCameraController
{
    CTPCameraVideoController *cameraController = [[CTPCameraVideoController alloc] init];
    
    
    
    
    return cameraController;
}

#pragma mark - 控制器方法

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 隐藏状态栏
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    
    _isFocusing = NO;
    _isShooting = NO;
    _isRotatingCamera = NO;
    _canWrite = NO;
    _beginGestureScale = 1.0f;
    _effectiveScale = 1.0f;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        [self requestAuthorizationForVideo];
    }
    
    //判断用户是否允许访问麦克风权限
    authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied)
    {
        [self requestAuthorizationForVideo];
    }
    [self requestAuthorizationForPhotoLibrary];
    
    [self initAVCaptureSession];
    
    [self configDefaultUIDisplay];
    
    [self addTapGenstureRecognizerForCamera];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.videoWriterManager startSession];
    
    [self setFocusCursorWithPoint:self.viewContainer.center];
    
    [self tipLabelAnimation];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    // 显示状态栏
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.videoWriterManager stopSession];
    
    [self stopUpdateAccelerometer];
}

- (void)dealloc
{
    NSLog(@"dealloc");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - 控件方法

/**
 *  关闭当前界面
 */
- (void)closeButtonClickedEvent:(id)sender
{
    [self dismissViewControllerAnimated:NO completion:nil];
}

/**
 *  切换前后摄像头
 */
- (void)rotateCameraButtonClickedEvent:(id)sender
{
    _isRotatingCamera = YES;
    [self.videoWriterManager rotateCamera];
    _isRotatingCamera = NO;
}

- (void)cancelButtonClickedEvent:(id)sender
{
    [[NSFileManager defaultManager] removeItemAtURL:self.videoWriterManager.videoURL error:nil];
    
    [self removePlayerItemNotification];
    
    [self startAnimationGroup];
}

/**
 *  确认按钮并返回代理
 */
- (void)confirmButtonClickedEvent:(id)sender
{
    __weak typeof(self) weakSelf = self;
    if (self.photoPreviewImageView) {
        UIImage *finalImage = [weakSelf cutImageWithView:weakSelf.photoPreviewImageView];
        
        [CTPPhotoLibraryManager savePhotoWithImage:finalImage andAssetCollectionName:weakSelf.assetCollectionName withCompletion:^(UIImage *image, NSError *error) {
            
            if (weakSelf.takePhotosCompletionBlock) {
                if (error) {
                    NSLog(@"保存照片失败!");
                    weakSelf.takePhotosCompletionBlock(nil, error);
                } else {
                    NSLog(@"保存照片成功!");
                    weakSelf.takePhotosCompletionBlock(image, nil);
                }
            }
            
        }];
        
        weakSelf.buttonConfirm.userInteractionEnabled = NO;
        
    } else {
        
        [weakSelf.videoWriterManager cropWithVideoStart:0 end:weakSelf.currentVideoTimeLength maxLengthTime:VIDEO_RECORDER_MAX_TIME completion:^(NSURL *outputURL, Float64 videoDuration, BOOL isSuccess) {
            
            if (isSuccess) {
                [CTPPhotoLibraryManager saveVideoWithVideoUrl:outputURL andAssetCollectionName:nil withCompletion:^(NSURL *videoUrl, NSError *error) {

                    if (weakSelf.shootCompletionBlock) {
                        if (error) {
                            NSLog(@"保存视频失败!");
                            weakSelf.shootCompletionBlock(nil, 0, nil, error);
                        } else {
                            NSLog(@"保存视频成功!");

                            // 获取视频的第一帧图片
                            UIImage *image = [weakSelf.videoWriterManager thumbnailImageRequestWithVideoUrl:videoUrl andTime:0.01f];

                            UIImage *finalImage = nil;
                            if (weakSelf.shootingOrientation == UIDeviceOrientationLandscapeRight) {
                                finalImage = [weakSelf rotateImage:image withOrientation:UIImageOrientationDown];
                            } else if (weakSelf.shootingOrientation == UIDeviceOrientationLandscapeLeft) {
                                finalImage = [weakSelf rotateImage:image withOrientation:UIImageOrientationUp];
                            } else if (weakSelf.shootingOrientation == UIDeviceOrientationPortraitUpsideDown) {
                                finalImage = [weakSelf rotateImage:image withOrientation:UIImageOrientationLeft];
                            } else {
                                finalImage = [weakSelf rotateImage:image withOrientation:UIImageOrientationRight];
                            }

                            weakSelf.shootCompletionBlock(videoUrl, videoDuration, finalImage, nil);

                            NSError *error = nil;
                            [[NSFileManager defaultManager] removeItemAtURL:weakSelf.videoWriterManager.videoURL error:&error];
                            NSLog(@"删除缓存在本地的视频文件：%@",error);
                            weakSelf.videoWriterManager.videoURL = nil;
                            finalImage = nil;
                            image = nil;
                        }
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.buttonConfirm.userInteractionEnabled = NO;
                    });
                }];
            } else {
                NSLog(@"保存视频失败!");
                [[NSFileManager defaultManager] removeItemAtURL:weakSelf.videoWriterManager.videoURL error:nil];
                weakSelf.videoWriterManager.videoURL = nil;
                [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
            }
            
        }];
        
    }
}

#pragma mark - 懒加载
- (CMMotionManager *)motionManager
{
    if (!_motionManager)
    {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

- (CTPVideoWriterManager *)videoWriterManager
{
    if (_videoWriterManager == nil) {
        _videoWriterManager = [[CTPVideoWriterManager alloc] initWithBufferDelegate:self];
    }
    return _videoWriterManager;
}

#pragma mark -
- (UIView *)viewContainer
{
    if (_viewContainer == nil) {
        _viewContainer = [[UIView alloc] init];
        _viewContainer.backgroundColor = [UIColor blackColor];
        [self.view addSubview:_viewContainer];
        [_viewContainer mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
    }
    return _viewContainer;
}

- (CTPCameraButton *)buttonTakeCamera
{
    // 设置拍照按钮
    if (_buttonTakeCamera == nil) {
        CTPCameraButton *cameraButton = [CTPCameraButton defaultCameraButton];
        _buttonTakeCamera = cameraButton;
        
        [self.view addSubview:cameraButton];
        CGFloat cameraBtnX = (kScreenWidth - cameraButton.bounds.size.width) / 2;
        CGFloat cameraBtnY = kScreenHeight - cameraButton.bounds.size.height - 60;    //距离底部60
        cameraButton.frame = CGRectMake(cameraBtnX, cameraBtnY, cameraButton.bounds.size.width, cameraButton.bounds.size.height);
        [self.view bringSubviewToFront:cameraButton];
        
        // 设置拍照按钮点击事件
        __weak typeof(self) weakSelf = self;
        // 配置拍照方法
        [cameraButton configureTapCameraButtonEventWithBlock:^(UITapGestureRecognizer *tapGestureRecognizer) {
            [weakSelf takePhotos:tapGestureRecognizer];
        }];
        // 配置拍摄方法
        [cameraButton configureLongPressCameraButtonEventWithBlock:^(UILongPressGestureRecognizer *longPressGestureRecognizer) {
            [weakSelf longPressCameraButtonFunc:longPressGestureRecognizer];
        }];
    }
    return _buttonTakeCamera;
}

- (UIButton *)buttonRotateCamera
{
    if (_buttonRotateCamera == nil) {
        _buttonRotateCamera = [[UIButton alloc] init];
        [_buttonRotateCamera setImage:[UIImage imageNamed:@"icon_change"] forState:UIControlStateNormal];
        [_buttonRotateCamera addTarget:self action:@selector(rotateCameraButtonClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_buttonRotateCamera];
        [_buttonRotateCamera mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.buttonTakeCamera);
            make.right.equalTo(self.view);
            make.height.equalTo(@(40.0));
            make.width.equalTo(@80.0);
        }];
    }
    return _buttonRotateCamera;
}

- (UIButton *)buttonClose
{
    if (_buttonClose == nil) {
        _buttonClose = [[UIButton alloc] init];
        [_buttonClose setTitle:@"取消" forState:UIControlStateNormal];
        _buttonClose.titleLabel.font = [UIFont systemFontOfSize:15.0];
        [_buttonClose addTarget:self action:@selector(closeButtonClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
        [_buttonClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.view addSubview:_buttonClose];
        [_buttonClose mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.buttonTakeCamera);
            make.left.equalTo(self.view);
            make.height.equalTo(@(40.0));
            make.width.equalTo(@80.0);
        }];
    }
    return _buttonClose;
}

- (UILabel *)labelTip
{
    if (_labelTip == nil) {
        _labelTip = [[UILabel alloc] init];
        _labelTip.textColor = [UIColor whiteColor];
        _labelTip.textAlignment = NSTextAlignmentCenter;
        _labelTip.font = [UIFont systemFontOfSize:15.0];
        _labelTip.text = @"点击拍照，长按摄像";
        [self.view addSubview:_labelTip];
        [_labelTip mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.buttonTakeCamera.mas_top).offset(-20.0);
            make.left.equalTo(self.view);
            make.right.equalTo(self.view);
            make.height.equalTo(@20.0);
        }];
    }
    return _labelTip;
}

- (UIImageView *)imageViewFocus
{
    if (_imageViewFocus == nil) {
        _imageViewFocus = [[UIImageView alloc] init];
        [_imageViewFocus setImage:[UIImage imageNamed:@"sight_video_focus"]];
        _imageViewFocus.bounds = CGRectMake(0, 0, 60.0, 60.0);
        _imageViewFocus.center = self.view.center;
        [self.view addSubview:_imageViewFocus];
    }
    return _imageViewFocus;
}

#pragma mark 拍照摄像后的预览页面
- (UIButton *)buttonCancel
{
    if (_buttonCancel == nil) {
        _buttonCancel = [[UIButton alloc] init];
        _buttonCancel.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_buttonCancel setImage:[UIImage imageNamed:@"icon_return_n"] forState:UIControlStateNormal];
        [_buttonCancel addTarget:self action:@selector(cancelButtonClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
        [_buttonCancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.view addSubview:_buttonCancel];
        [_buttonCancel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.buttonTakeCamera);
            make.left.equalTo(self.view);
            make.height.equalTo(@(76.0));
            make.width.equalTo(@(kScreenWidth/2.0));
        }];
    }
    return _buttonCancel;
}

- (UIButton *)buttonConfirm
{
    if (_buttonConfirm == nil) {
        _buttonConfirm = [[UIButton alloc] init];
        _buttonConfirm.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_buttonConfirm setImage:[UIImage imageNamed:@"icon_finish_p"] forState:UIControlStateNormal];
        [_buttonConfirm addTarget:self action:@selector(confirmButtonClickedEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_buttonConfirm];
        [_buttonConfirm mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerY.equalTo(self.buttonTakeCamera);
            make.right.equalTo(self.view);
            make.height.equalTo(@(76.0));
            make.width.equalTo(@(kScreenWidth/2.0));
        }];
    }
    return _buttonConfirm;
}

#pragma mark - 私有方法

/**
 *  初始化AVCapture会话
 */
- (void)initAVCaptureSession
{
    //1、添加 "视频" 与 "音频" 输入流到session
    [self.videoWriterManager setupVideo];
    
    [self.videoWriterManager setupAudio];
    
    //2、添加图片，movie输出流到session
    [self.videoWriterManager setupCaptureStillImageOutput];
    
    //3、创建视频预览层，用于实时展示摄像头状态
    [self setupCaptureVideoPreviewLayer];
    
    //设置静音状态也可播放声音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
}

/**
 *  设置预览layer
 */
- (void)setupCaptureVideoPreviewLayer
{
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.videoWriterManager.captureSession];
    
    CALayer *layer = self.viewContainer.layer;
    [self.view layoutIfNeeded];
//    _captureVideoPreviewLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    _captureVideoPreviewLayer.frame = self.viewContainer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;           //填充模式
    
    [layer addSublayer:_captureVideoPreviewLayer];
}

/**
 *  开始拍照录像动画组合
 */
- (void)startAnimationGroup
{
    [self configDefaultUIDisplay];
    
    [self setFocusCursorWithPoint:self.viewContainer.center];
    
    [self tipLabelAnimation];
}

/**
 *  配置默认UI信息
 */
- (void)configDefaultUIDisplay
{
    if (self.photoPreviewImageView)
    {
        [self.photoPreviewImageView removeFromSuperview];
        [self.photoPreviewContainerView removeFromSuperview];
        self.photoPreviewImageView = nil;
        self.photoPreviewContainerView = nil;
    }
    if (self.videoPreviewContainerView)
    {
        [self.player pause];
        self.player = nil;
        self.playerItem = nil;
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
        self.buttonTakeCamera.progressPercentage = 0.0f;
        [self.videoPreviewContainerView removeFromSuperview];
        self.videoPreviewContainerView = nil;
        [[NSFileManager defaultManager] removeItemAtURL:self.videoWriterManager.videoURL error:nil];
        self.videoWriterManager.videoURL = nil;
    }
    
    [self.view bringSubviewToFront:self.buttonRotateCamera];
    [self.view bringSubviewToFront:self.buttonClose];
    [self.buttonRotateCamera setHidden:NO];
    [self.buttonClose setHidden:NO];
    
    [self.view bringSubviewToFront:self.labelTip];
    [self.labelTip setAlpha:0];
    
    [self.buttonCancel setHidden:YES];
    [self.buttonConfirm setHidden:YES];
    
    // 设置拍照按钮
    if (_buttonTakeCamera == nil)
    {
        CTPCameraButton *cameraButton = [CTPCameraButton defaultCameraButton];
        _buttonTakeCamera = cameraButton;
        
        [self.view addSubview:cameraButton];
        CGFloat cameraBtnX = (kScreenWidth - cameraButton.bounds.size.width) / 2;
        CGFloat cameraBtnY = kScreenHeight - cameraButton.bounds.size.height - 60;    //距离底部60
        cameraButton.frame = CGRectMake(cameraBtnX, cameraBtnY, cameraButton.bounds.size.width, cameraButton.bounds.size.height);
        [self.view bringSubviewToFront:cameraButton];
        
        // 设置拍照按钮点击事件
        __weak typeof(self) weakSelf = self;
        // 配置拍照方法
        [cameraButton configureTapCameraButtonEventWithBlock:^(UITapGestureRecognizer *tapGestureRecognizer) {
            [weakSelf takePhotos:tapGestureRecognizer];
        }];
        // 配置拍摄方法
        [cameraButton configureLongPressCameraButtonEventWithBlock:^(UILongPressGestureRecognizer *longPressGestureRecognizer) {
            [weakSelf longPressCameraButtonFunc:longPressGestureRecognizer];
        }];
    }
    [self.buttonTakeCamera setHidden:NO];
    [self.view bringSubviewToFront:self.buttonTakeCamera];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    // 对焦imageView
    [self.view bringSubviewToFront:self.imageViewFocus];
    [self.imageViewFocus setAlpha:0];
    
    // 监听屏幕方向
    [self startUpdateAccelerometer];
}

/**
 *  提示语动画
 */
- (void)tipLabelAnimation
{
    [self.view bringSubviewToFront:self.labelTip];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:1.0f delay:0.5f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        [weakSelf.labelTip setAlpha:1];
        
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:1.0f delay:3.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            
            [weakSelf.labelTip setAlpha:0];
            
        } completion:nil];
        
    }];
}


#pragma mark - 拍照功能
/**
 *  拍照方法
 */
- (void)takePhotos:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self.videoWriterManager takePhotoWithEffectiveScale:self.effectiveScale complete:^(BOOL result, NSData *imageData) {
        if (result) {
            UIImage *image = [UIImage imageWithData:imageData];
            [self previewPhotoWithImage:image];
        }
    }];
}

/**
 *  预览图片
 */
- (void)previewPhotoWithImage:(UIImage *)image
{
    [self stopUpdateAccelerometer];
    
    [self.buttonTakeCamera setHidden:YES];
    [self.buttonClose setHidden:YES];
    [self.buttonRotateCamera setHidden:YES];
    
    UIImage *finalImage = nil;
    if (self.shootingOrientation == UIDeviceOrientationLandscapeRight)
    {
        finalImage = [self rotateImage:image withOrientation:UIImageOrientationDown];
    }
    else if (self.shootingOrientation == UIDeviceOrientationLandscapeLeft)
    {
        finalImage = [self rotateImage:image withOrientation:UIImageOrientationUp];
    }
    else if (self.shootingOrientation == UIDeviceOrientationPortraitUpsideDown)
    {
        finalImage = [self rotateImage:image withOrientation:UIImageOrientationLeft];
    }
    else
    {
        finalImage = [self rotateImage:image withOrientation:UIImageOrientationRight];
    }
    
    self.photoPreviewImageView = [[UIImageView alloc] init];
    float videoRatio = finalImage.size.width / finalImage.size.height;
    if (self.shootingOrientation == UIDeviceOrientationLandscapeRight || self.shootingOrientation == UIDeviceOrientationLandscapeLeft)
    {
        CGFloat height = kScreenWidth * videoRatio;
        CGFloat y = (kScreenHeight - height) / 2;
        [self.photoPreviewImageView setFrame:CGRectMake(0, y, kScreenWidth, height)];
    }
    else
    {
        [self.photoPreviewImageView setFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
    }
    self.photoPreviewImageView.image = finalImage;
    
    self.photoPreviewContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
    self.photoPreviewContainerView.backgroundColor = [UIColor blackColor];
    [self.photoPreviewContainerView addSubview:self.photoPreviewImageView];
    [self.view addSubview:self.photoPreviewContainerView];
    [self.view bringSubviewToFront:self.photoPreviewImageView];
    [self.view bringSubviewToFront:self.buttonCancel];
    [self.view bringSubviewToFront:self.buttonConfirm];
    [self.buttonCancel setHidden:NO];
    [self.buttonConfirm setHidden:NO];
}

- (UIImage *)cutImageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

#pragma mark - 视频录制

/**
 *  录制视频方法
 */
- (void)longPressCameraButtonFunc:(UILongPressGestureRecognizer *)sender
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied)
    {
        return;
    }
    
    //判断用户是否允许访问麦克风权限
    authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied)
    {
        return;
    }
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            [self startVideoRecorder];
            break;
        case UIGestureRecognizerStateCancelled:
            [self stopVideoRecorder];
            break;
        case UIGestureRecognizerStateEnded:
            [self stopVideoRecorder];
            break;
        case UIGestureRecognizerStateFailed:
            [self stopVideoRecorder];
            break;
        default:
            break;
    }
    
}

/**
 *  开始录制视频
 */
- (void)startVideoRecorder
{
    _isShooting = YES;
    
    [self stopUpdateAccelerometer];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    [self.buttonTakeCamera startShootAnimationWithDuration:START_VIDEO_ANIMATION_DURATION];
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(START_VIDEO_ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        CGAffineTransform  transform;
        if (self.shootingOrientation == UIDeviceOrientationLandscapeRight) {
            transform = CGAffineTransformMakeRotation(M_PI);
        } else if (self.shootingOrientation == UIDeviceOrientationLandscapeLeft) {
            transform = CGAffineTransformMakeRotation(0);
        } else if (self.shootingOrientation == UIDeviceOrientationPortraitUpsideDown) {
            transform = CGAffineTransformMakeRotation(M_PI + (M_PI / 2.0));
        } else {
            transform = CGAffineTransformMakeRotation(M_PI / 2.0);
        }
        [self.videoWriterManager setupWriterPropertysWithSize:CGSizeMake(kScreenWidth, kScreenHeight) andTransform:transform];
        weakSelf.canWrite = NO;
        
        [weakSelf timerFired];
        
    });
}



/**
 *  结束录制视频
 */
- (void)stopVideoRecorder
{
    if (_isShooting)
    {
        _isShooting = NO;
        self.buttonTakeCamera.progressPercentage = 0.0f;
        [self.buttonTakeCamera stopShootAnimation];
        [self timerStop];
        
        __weak __typeof(self)weakSelf = self;
        
        [self.videoWriterManager stopVideoRecorder:^(BOOL can) {
            weakSelf.canWrite = can;
        }];
        
        if (timeLength < VIDEO_RECORDER_MIN_TIME) {
            return;
        }
        
        [self.buttonTakeCamera setHidden:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [weakSelf previewVideoAfterShoot];
            
        });
    }
    else
    {
        // nothing
    }
}

/**
 *  开启定时器
 */
- (void)timerFired
{
    timeLength = 0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(timerRecord) userInfo:nil repeats:YES];
}

/**
 *  绿色转圈百分比计算
 */
- (void)timerRecord
{
    if (!_isShooting)
    {
        [self timerStop];
        return ;
    }
    
    // 时间大于VIDEO_RECORDER_MAX_TIME则停止录制
    if (timeLength > VIDEO_RECORDER_MAX_TIME)
    {
        [self stopVideoRecorder];
    }
    
    timeLength += TIMER_INTERVAL;
    
    //    NSLog(@"%lf", timeLength / VIDEO_RECORDER_MAX_TIME);
    
    self.buttonTakeCamera.progressPercentage = timeLength / VIDEO_RECORDER_MAX_TIME;
    
}

/**
 *  停止定时器
 */
- (void)timerStop
{
    if ([self.timer isValid])
    {
        [self.timer invalidate];
        self.timer = nil;
    }
}

/**
 *  预览录制的视频
 */
- (void)previewVideoAfterShoot
{
    if (self.videoWriterManager.videoURL == nil || self.videoPreviewContainerView != nil) {
        return;
    }
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:self.videoWriterManager.videoURL];
    
    //获取视频总时长
    Float64 duration = CMTimeGetSeconds(asset.duration);
    
    self.currentVideoTimeLength = duration;
    
    // 初始化AVPlayer
    self.videoPreviewContainerView = [[UIView alloc] init];
//    self.videoPreviewContainerView.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    self.videoPreviewContainerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.videoPreviewContainerView];
    [self.videoPreviewContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.videoPreviewContainerView.superview);
    }];
    [self.view layoutIfNeeded]; // 立即执行约束条件
    
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    self.player = [[AVPlayer alloc] initWithPlayerItem:_playerItem];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
//    self.playerLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    self.playerLayer.frame = self.videoPreviewContainerView.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.videoPreviewContainerView.layer addSublayer:self.playerLayer];
    
    // 其余UI布局设置
    [self.view bringSubviewToFront:self.videoPreviewContainerView];
    [self.view bringSubviewToFront:self.buttonCancel];
    [self.view bringSubviewToFront:self.buttonConfirm];
    [self.buttonTakeCamera setHidden:YES];
    [self.buttonClose setHidden:YES];
    [self.buttonRotateCamera setHidden:YES];
    [self.buttonCancel setHidden:NO];
    [self.buttonConfirm setHidden:NO];
    
    // 重复播放预览视频
    [self addNotificationWithPlayerItem];
    
    // 开始播放
    [self.player play];
}

/**
 *  图片旋转
 */
- (UIImage *)rotateImage:(UIImage *)image withOrientation:(UIImageOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation)
    {
        case UIImageOrientationLeft:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    //做CTM变换
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    
    CGContextScaleCTM(context, scaleX, scaleY);
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    
    return newPic;
}

#pragma mark - 预览视频通知
/**
 *  添加播放器通知
 */
-(void)addNotificationWithPlayerItem
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playVideoFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
}

-(void)removePlayerItemNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 *  播放完成通知
 *
 *  @param notification 通知对象
 */
-(void)playVideoFinished:(NSNotification *)notification
{
    //    NSLog(@"视频播放完成.");
    
    // 播放完成后重复播放
    // 跳到最新的时间点开始播放
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player play];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (_isRotatingCamera) {
        return;
    }
    
    @autoreleasepool {
        //视频
        if (connection == [self.videoWriterManager.videoOutput connectionWithMediaType:AVMediaTypeVideo])
        {
            @synchronized(self) {
                if (_isShooting) {
                    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
                }
            }
        }
        
        //音频
        if (connection == [self.videoWriterManager.audioOutput connectionWithMediaType:AVMediaTypeAudio]) {
            @synchronized(self) {
                if (_isShooting) {
                    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
                }
            }
        }
    }
}


/**
 *  开始写入数据
 */
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
    if (sampleBuffer == NULL)
    {
        NSLog(@"empty sampleBuffer");
        return;
    }
    
    //    CFRetain(sampleBuffer);
    //    dispatch_async(self.videoQueue, ^{
    @autoreleasepool {
        if (!self.canWrite && mediaType == AVMediaTypeVideo) {
            [self.videoWriterManager.assetWriter startWriting];
            [self.videoWriterManager.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            self.canWrite = YES;
        }
        
        //写入视频数据
        if (mediaType == AVMediaTypeVideo) {
            if (self.videoWriterManager.assetWriterVideoInput.readyForMoreMediaData) {
                BOOL success = [self.videoWriterManager.assetWriterVideoInput appendSampleBuffer:sampleBuffer];
                if (!success) {
                    @synchronized (self) {
                        [self stopVideoRecorder];
                    }
                }
            }
        }
        
        //写入音频数据
        if (mediaType == AVMediaTypeAudio) {
            if (self.videoWriterManager.assetWriterAudioInput.readyForMoreMediaData) {
                BOOL success = [self.videoWriterManager.assetWriterAudioInput appendSampleBuffer:sampleBuffer];
                if (!success) {
                    @synchronized (self) {
                        [self stopVideoRecorder];
                    }
                }
            }
        }
        
        //            CFRelease(sampleBuffer);
    }
    //    });
}

#pragma mark - 摄像头聚焦，与缩放

/**
 *  添加点按手势
 */
- (void)addTapGenstureRecognizerForCamera
{
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    
    pinchGesture.delegate = self;
    
    [self.viewContainer addGestureRecognizer:pinchGesture];
}

/**
 *  点击屏幕，聚焦事件
 */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // 不聚焦的情况：聚焦中，旋转摄像头中，查看录制的视频中，查看照片中
    if (_isFocusing || touches.count == 0 || _isRotatingCamera || _videoPreviewContainerView || _photoPreviewImageView) {
        return;
    }
    
    UITouch *touch = nil;
    
    for (UITouch *t in touches) {
        touch = t;
        break;
    }
    
    CGPoint point = [touch locationInView:self.viewContainer];;
    
    if (point.y > CGRectGetMaxY(self.labelTip.frame)) {
        return;
    }
    
    [self setFocusCursorWithPoint:point];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point
{
    self.isFocusing = YES;
    
    self.imageViewFocus.center = point;
    self.imageViewFocus.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.imageViewFocus.alpha = 1;
    
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint = [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithPoint:cameraPoint];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:1.0 animations:^{
        
        weakSelf.imageViewFocus.transform = CGAffineTransformIdentity;
        
    } completion:^(BOOL finished) {
        
        weakSelf.imageViewFocus.alpha = 0;
        weakSelf.isFocusing = NO;
        
    }];
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithPoint:(CGPoint)point
{
    [self.videoWriterManager changeDeviceProperty:^(AVCaptureDevice *captureDevice)
     {
         // 聚焦
         if ([captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
             [captureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
         }
         if ([captureDevice isFocusPointOfInterestSupported]) {
             [captureDevice setFocusPointOfInterest:point];
         }
         // 曝光
         if ([captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
             [captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
         }
         if ([captureDevice isExposurePointOfInterestSupported]) {
             [captureDevice setExposurePointOfInterest:point];
         }
     }];
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
    if (_isShooting) {
        return;
    }
    
    BOOL allTouchesAreOnTheCaptureVideoPreviewLayer = YES;
    
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for ( i = 0; i < numTouches; ++i) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.viewContainer];
        CGPoint convertedLocation = [self.captureVideoPreviewLayer convertPoint:location fromLayer:self.captureVideoPreviewLayer.superlayer];
        if (![self.captureVideoPreviewLayer containsPoint:convertedLocation]) {
            allTouchesAreOnTheCaptureVideoPreviewLayer = NO;
            break;
        }
    }
    
    if (allTouchesAreOnTheCaptureVideoPreviewLayer) {
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < 1.0f) {
            self.effectiveScale = 1.0f;
        }
        
        //        NSLog(@"%f-------------->%f------------recognizerScale%f", self.effectiveScale, self.beginGestureScale, recognizer.scale);
        
        CGFloat imageMaxScaleAndCropFactor = [[self.videoWriterManager.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        
        //        NSLog(@"%f", imageMaxScaleAndCropFactor);
        if (self.effectiveScale > imageMaxScaleAndCropFactor) {
            self.effectiveScale = imageMaxScaleAndCropFactor;
        }
        
        [self setCaptureVideoPreviewLayerTransformWithScale:self.effectiveScale];
    }
}

- (void)setCaptureVideoPreviewLayerTransformWithScale:(CGFloat)scale
{
    self.effectiveScale = scale;
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25f];      //时长最好低于 START_VIDEO_ANIMATION_DURATION
    [self.captureVideoPreviewLayer setAffineTransform:CGAffineTransformMakeScale(scale, scale)];
    [CATransaction commit];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.beginGestureScale = self.effectiveScale;
    }
    
    return YES;
}

#pragma mark - 重力感应相关

/**
 *  开始监听屏幕方向
 */
- (void)startUpdateAccelerometer
{
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        //回调会一直调用,建议获取到就调用下面的停止方法，需要再重新开始，当然如果需求是实时不间断的话可以等离开页面之后再stop
        [self.motionManager setAccelerometerUpdateInterval:1.0];
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
             double x = accelerometerData.acceleration.x;
             double y = accelerometerData.acceleration.y;
             if (fabs(y) >= fabs(x)) {
                 if (y >= 0) {
                     // Down
                     NSLog(@"Down");
                     _shootingOrientation = UIDeviceOrientationPortraitUpsideDown;
                 } else {
                     // Portrait
                     NSLog(@"Portrait");
                     _shootingOrientation = UIDeviceOrientationPortrait;
                 }
             } else {
                 if (x >= 0) {
                     // Right
                     NSLog(@"Right");
                     _shootingOrientation = UIDeviceOrientationLandscapeRight;
                 } else {
                     // Left
                     NSLog(@"Left");
                     _shootingOrientation = UIDeviceOrientationLandscapeLeft;
                 }
             }
         }];
    }
}

/**
 *  停止监听屏幕方向
 */
- (void)stopUpdateAccelerometer
{
    if ([self.motionManager isAccelerometerActive] == YES)
    {
        [self.motionManager stopAccelerometerUpdates];
        _motionManager = nil;
    }
}

#pragma mark - 判断是否有权限

/**
 *  请求权限
 */
- (void)requestAuthorizationForVideo
{
    __weak typeof(self) weakSelf = self;
    
    // 请求相机权限
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        if (appName == nil)
        {
            appName = @"APP";
        }
        NSString *message = [NSString stringWithFormat:@"允许%@访问你的相机？", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    // 请求麦克风权限
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        if (appName == nil)
        {
            appName = @"APP";
        }
        NSString *message = [NSString stringWithFormat:@"允许%@访问你的麦克风？", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    
}

- (void)requestAuthorizationForPhotoLibrary
{
    __weak typeof(self) weakSelf = self;
    
    // 请求照片权限
    [CTPPhotoLibraryManager requestALAssetsLibraryAuthorizationWithCompletion:^(Boolean isAuth) {
        
        if (!isAuth)
        {
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            
            NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
            if (appName == nil)
            {
                appName = @"APP";
            }
            NSString *message = [NSString stringWithFormat:@"允许%@访问你的相册？", appName];
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"警告" message:message preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }];
            
            UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if ([[UIApplication sharedApplication] canOpenURL:url])
                {
                    [[UIApplication sharedApplication] openURL:url];
                    [weakSelf dismissViewControllerAnimated:YES completion:nil];
                }
            }];
            
            [alertController addAction:okAction];
            [alertController addAction:setAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
            
        }
    }];
}


@end
