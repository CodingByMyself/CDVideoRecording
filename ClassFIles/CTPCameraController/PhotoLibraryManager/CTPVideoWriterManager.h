//
//  CTPVideoWriterManager.h
//  CDTestVideo
//
//  Created by Cindy on 2018/1/22.
//  Copyright © 2018年 Cindy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>



typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);




@interface CTPVideoWriterManager : NSObject

@property (strong, nonatomic) AVCaptureSession *captureSession;                          //负责输入和输出设备之间的数据传递

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;                          //视频输入
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;                          //声音输入
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;


@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
@property (strong, nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;        //照片输出流


@property (strong, nonatomic) NSURL *videoURL;                                           //视频文件地址




#pragma mark -
/**
 初始化一个视频录制写入的管理类

 @param sampleBufferDelegate 视频录制缓存代理
 @return 管理类实例对象
 */
- (instancetype)initWithBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>)sampleBufferDelegate;



#pragma mark -

/**
 *  设置视频输入
 */
- (void)setupVideo;

/**
 *  设置音频录入
 */
- (void)setupAudio;

/**
 *  设置图片输出
 */
- (void)setupCaptureStillImageOutput;




/**
 *  开启会话
 */
- (void)startSession;

/**
 *  停止会话
 */
- (void)stopSession;






/**
 *  切换前后摄像头
 */
- (void)rotateCamera;

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange;





#pragma mark - 拍照
// 拍照
- (void)takePhotoWithEffectiveScale:(CGFloat)effectiveScale complete:(void(^)(BOOL result,NSData *imageData))takeComplete;



#pragma mark 录制视频
/**
 *  设置写入视频属性
 */
- (void)setupWriterPropertysWithSize:(CGSize)size andTransform:(CGAffineTransform)transform;

- (void)stopVideoRecorder:(void(^)(BOOL can))canWrite;

/**
 *  截取指定时间的视频缩略图
 *
 *  @param timeBySecond 时间点，单位：s
 */
- (UIImage *)thumbnailImageRequestWithVideoUrl:(NSURL *)videoUrl andTime:(CGFloat)timeBySecond;


// 合成视频
- (void)cropWithVideoStart:(CGFloat)startTime end:(CGFloat)endTime maxLengthTime:(CGFloat)maxTime completion:(void (^)(NSURL *outputURL, Float64 videoDuration, BOOL isSuccess))completionHandle;















@end
