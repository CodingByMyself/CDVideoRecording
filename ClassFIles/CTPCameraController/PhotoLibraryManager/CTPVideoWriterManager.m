//
//  CTPVideoWriterManager.m
//  CDTestVideo
//
//  Created by Cindy on 2018/1/22.
//  Copyright © 2018年 Cindy. All rights reserved.
//

#import "CTPVideoWriterManager.h"
#import <UIKit/UIKit.h>


#define VIDEO_FILEPATH  @"video"


@interface CTPVideoWriterManager ()

@property (nonatomic, weak) id <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate> sampleBufferDelegate;
@property (nonatomic, strong) dispatch_queue_t videoQueue;


@property (nonatomic, strong) NSDictionary *videoCompressionSettings;
@property (nonatomic, strong) NSDictionary *audioCompressionSettings;

@end


@implementation CTPVideoWriterManager

/**
 初始化一个视频录制写入的管理类
 
 @param sampleBufferDelegate 视频录制缓存代理
 @return 管理类实例对象
 */
- (instancetype)initWithBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>)sampleBufferDelegate
{
    self = [super init];
    if (self) {
        self.sampleBufferDelegate = sampleBufferDelegate;
    }
    return self;
}


#pragma mark - Public  Setup  Method
/**
 *  设置视频输入
 */
- (void)setupVideo
{
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!captureDevice)
    {
        NSLog(@"取得后置摄像头时出现问题.");
        
        return;
    }
    
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error)
    {
        NSLog(@"取得设备输入videoInput对象时出错，错误原因：%@", error);
        
        return;
    }
    
    //3、将设备输出添加到会话中
    if ([self.captureSession canAddInput:self.videoInput])
    {
        [self.captureSession addInput:self.videoInput];
    }
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES; //立即丢弃旧帧，节省内存，默认YES
    [self.videoOutput setSampleBufferDelegate:self.sampleBufferDelegate queue:self.videoQueue];
    if ([self.captureSession canAddOutput:self.videoOutput])
    {
        [self.captureSession addOutput:self.videoOutput];
    }
}

/**
 *  设置音频录入
 */
- (void)setupAudio
{
    NSError *error = nil;
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if (error)
    {
        NSLog(@"取得设备输入audioInput对象时出错，错误原因：%@", error);
        
        return;
    }
    if ([self.captureSession canAddInput:self.audioInput])
    {
        [self.captureSession addInput:self.audioInput];
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self.sampleBufferDelegate queue:self.videoQueue];
    if([self.captureSession canAddOutput:self.audioOutput])
    {
        [self.captureSession addOutput:self.audioOutput];
    }
}

/**
 *  设置图片输出
 */
- (void)setupCaptureStillImageOutput
{
    self.captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [_captureStillImageOutput setOutputSettings:outputSettings];
    
    if ([self.captureSession canAddOutput:_captureStillImageOutput]) {
        [self.captureSession addOutput:_captureStillImageOutput];
    }
}


#pragma mark
/**
 *  开启会话
 */
- (void)startSession
{
    if (![self.captureSession isRunning])
    {
        [self.captureSession startRunning];
    }
}

/**
 *  停止会话
 */
- (void)stopSession
{
    if ([self.captureSession isRunning])
    {
        [self.captureSession stopRunning];
    }
}


#pragma mark
/**
 *  切换前后摄像头
 */
- (void)rotateCamera
{
    //    _isRotatingCamera = YES;
    
    AVCaptureDevice *currentDevice = [self.videoInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront)
    {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.videoInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput])
    {
        [self.captureSession addInput:toChangeDeviceInput];
        self.videoInput = toChangeDeviceInput;
    }
    
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    //    _isRotatingCamera = NO;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange
{
    AVCaptureDevice *captureDevice = [self.videoInput device];
    NSError *error;
    
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error])
    {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }
    else
    {
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}



#pragma mark - 拍照
- (void)takePhotoWithEffectiveScale:(CGFloat)effectiveScale complete:(void(^)(BOOL result,NSData *imageData))takeComplete
{
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection = [self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (captureConnection == nil) {
        NSLog(@"当前设备不支持拍照功能！");
        return;
    }
    
    [captureConnection setVideoScaleAndCropFactor:effectiveScale];
    
    //根据连接取得设备输出的数据
    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer)
        {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
//            UIImage *image = [UIImage imageWithData:imageData];
//            [self previewPhotoWithImage:image];
            takeComplete ? takeComplete(YES,imageData) : nil;
        } else {
            takeComplete ? takeComplete(NO,nil) : nil;
        }
    }];
}

#pragma mark 录制视频
/**
 *  设置写入视频属性
 */
- (void)setupWriterPropertysWithSize:(CGSize)size andTransform:(CGAffineTransform)transform
{
    self.videoURL = [NSURL fileURLWithPath:[self createVideoFilePath]];
    
    if (self.videoURL == nil) {
        return;
    }
    
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.videoURL fileType:AVFileTypeMPEG4 error:nil];
    //写入视频大小
    NSInteger numPixels = size.width * size.height;
    //每像素比特
    CGFloat bitsPerPixel = 12.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
//                                             AVVideoExpectedSourceFrameRateKey : @(8.0),
                                             AVVideoMaxKeyFrameIntervalKey : @(3.0),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    
    //视频属性
    self.videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                       AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                       AVVideoWidthKey : @(size.height*2.0),
                                       AVVideoHeightKey : @(size.width*2.0),
                                       AVVideoCompressionPropertiesKey : compressionProperties };
    
    _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoCompressionSettings];
    //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
    _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
    
    _assetWriterVideoInput.transform = transform;
    
    // 音频设置
    self.audioCompressionSettings = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                       AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                       AVNumberOfChannelsKey : @(1),
                                       AVSampleRateKey : @(22050) };
    
    _assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:self.audioCompressionSettings];
    _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    
    if ([_assetWriter canAddInput:_assetWriterVideoInput])
    {
        [_assetWriter addInput:_assetWriterVideoInput];
    }
    else
    {
        NSLog(@"AssetWriter videoInput append Failed");
    }
    
    if ([_assetWriter canAddInput:_assetWriterAudioInput])
    {
        [_assetWriter addInput:_assetWriterAudioInput];
    }
    else
    {
        NSLog(@"AssetWriter audioInput Append Failed");
    }
    
//    _canWrite = NO;
}


- (void)stopVideoRecorder:(void(^)(BOOL can))canWrite
{
    __weak __typeof(self)weakSelf = self;
    if(_assetWriter && _assetWriter.status == AVAssetWriterStatusWriting)
    {
        //        dispatch_async(self.videoQueue, ^{
        [_assetWriter finishWritingWithCompletionHandler:^{
//            canWrite = NO;
            canWrite ? canWrite(YES) : nil;
            weakSelf.assetWriter = nil;
            weakSelf.assetWriterAudioInput = nil;
            weakSelf.assetWriterVideoInput = nil;
        }];
        //        });
    }
}


/**
 *  截取指定时间的视频缩略图
 *
 *  @param timeBySecond 时间点，单位：s
 */
- (UIImage *)thumbnailImageRequestWithVideoUrl:(NSURL *)videoUrl andTime:(CGFloat)timeBySecond
{
    if (videoUrl == nil) {
        return nil;
    }
    UIImage *firstImageThum = nil;
    
    // 获取视频第一帧
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:videoUrl options:opts];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = [UIScreen mainScreen].bounds.size;
    NSError *error = nil;
    CGImageRef img = [generator copyCGImageAtTime:CMTimeMake(timeBySecond, 10) actualTime:NULL error:&error];
    
    if (error == nil) {
        firstImageThum = [UIImage imageWithCGImage:img];
    }
    CGImageRelease(img);
    
    return firstImageThum;
}

// 合成视频
- (void)cropWithVideoStart:(CGFloat)startTime end:(CGFloat)endTime maxLengthTime:(CGFloat)maxTime completion:(void (^)(NSURL *outputURL, Float64 videoDuration, BOOL isSuccess))completionHandle
{
    __block AVURLAsset *asset =[[AVURLAsset alloc] initWithURL:self.videoURL options:nil];
    
    //获取视频总时长
    Float64 duration = CMTimeGetSeconds(asset.duration);
    
    if (duration > maxTime && maxTime > 1)
    {
        duration = maxTime;
    }
    
    startTime = 0;
    endTime = duration;
    
    NSString *outputFilePath = [self createVideoFilePath];
    NSURL *outputFileUrl = [NSURL fileURLWithPath:outputFilePath];
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        compatiblePresets = nil;
        __block AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetPassthrough];
        
        NSURL *outputURL = outputFileUrl;
        
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.shouldOptimizeForNetworkUse = YES;
        
        CMTime start = CMTimeMakeWithSeconds(startTime, asset.duration.timescale);
        CMTime duration = CMTimeMakeWithSeconds(endTime - startTime,asset.duration.timescale);
        CMTimeRange range = CMTimeRangeMake(start, duration);
        exportSession.timeRange = range;
        
        asset = nil;
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed:
                {
                    NSLog(@"合成失败：%@", [[exportSession error] description]);
                    completionHandle(outputURL, endTime, NO);
                }
                    break;
                case AVAssetExportSessionStatusCancelled:
                {
                    completionHandle(outputURL, endTime, NO);
                }
                    break;
                case AVAssetExportSessionStatusCompleted:
                {
                    completionHandle(outputURL, endTime, YES);
                }
                    break;
                default:
                {
                    completionHandle(outputURL, endTime, NO);
                } break;
            }
            [exportSession cancelExport];
            exportSession = nil;
        }];
    }
}




#pragma mark - Private Method
/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras)
    {
        if ([camera position] == position)
        {
            return camera;
        }
    }
    return nil;
}


- (NSString *)createVideoFilePath
{
    // 创建视频文件的存储路径
    NSString *filePath = [self createVideoFolderPath];
    if (filePath == nil)
    {
        return nil;
    }
    
    NSString *videoType = @".mp4";
    NSString *videoDestDateString = [self createFileNamePrefix];
    NSString *videoFileName = [videoDestDateString stringByAppendingString:videoType];
    
    NSUInteger idx = 1;
    /*We only allow 10000 same file name*/
    NSString *finalPath = [NSString stringWithFormat:@"%@/%@", filePath, videoFileName];
    
    while (idx % 10000 && [[NSFileManager defaultManager] fileExistsAtPath:finalPath])
    {
        finalPath = [NSString stringWithFormat:@"%@/%@_(%lu)%@", filePath, videoDestDateString, (unsigned long)idx++, videoType];
    }
    
    return finalPath;
}

- (NSString *)createVideoFolderPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homePath = NSHomeDirectory();
    
    NSString *tmpFilePath;
    
    if (homePath.length > 0)
    {
        NSString *documentPath = [homePath stringByAppendingString:@"/Documents"];
        if ([fileManager fileExistsAtPath:documentPath isDirectory:NULL] == YES)
        {
            BOOL success = NO;
            
            NSArray *paths = [fileManager contentsOfDirectoryAtPath:documentPath error:nil];
            
            //offline file folder
            tmpFilePath = [documentPath stringByAppendingString:[NSString stringWithFormat:@"/%@", VIDEO_FILEPATH]];
            if ([paths containsObject:VIDEO_FILEPATH] == NO)
            {
                success = [fileManager createDirectoryAtPath:tmpFilePath withIntermediateDirectories:YES attributes:nil error:nil];
                if (!success)
                {
                    tmpFilePath = nil;
                }
            }
            return tmpFilePath;
        }
    }
    
    return false;
}

/**
 *  创建文件名
 *
 *  @prama type 文件名类型
 */
- (NSString *)createFileNamePrefix
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    
    NSString *destDateString = [dateFormatter stringFromDate:[NSDate date]];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    
    return destDateString;
}






#pragma mark - 懒加载
- (AVCaptureSession *)captureSession
{
    if (_captureSession == nil)
    {
        _captureSession = [[AVCaptureSession alloc] init];
        
        if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh])
        {
            _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        }
    }
    
    return _captureSession;
}

- (dispatch_queue_t)videoQueue
{
    if (!_videoQueue)
    {
        _videoQueue = dispatch_get_main_queue();
    }
    
    return _videoQueue;
}


@end
