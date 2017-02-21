//
//  CXVideoCaptureViewController.h
//  OpenCV-iOS-demo
//
//  Created by 刘伟 on 12/01/2017.
//  Copyright © 2017 上海凌晋信息技术有限公司. All rights reserved.
//

#import "CXVideoCaptureViewController.h"
#import "UIView+Ext.h"

#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <iostream>

#import "Rectangle.h"
#import "RectangleCALayer.h"
#import "UIImage+utils.h"

//// Private interface
//@interface CXVideoCaptureViewController ()
//- (BOOL)createCaptureSessionForCamera:(NSInteger)camera qualityPreset:(NSString *)qualityPreset;
//- (void)destroyCaptureSession;
//- (void)processFrame:(cv::Mat&)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)orientation;
//@end


@interface CXVideoCaptureViewController()<AVCaptureFileOutputRecordingDelegate>
{
    int _camera; // 当前摄像头
    NSTimer *_calVideoDurationTimer;
}

/**
 顶部容器视图
 */
@property (strong, nonatomic) UIView *topContentView;
/**
 闪光灯
 */
@property (strong, nonatomic) UIButton *torchButton;
/**
 前后摄像头切换
 */
@property (strong, nonatomic) UIButton *cameraButton;
/**
 录制视频时长显示
 */
@property (strong, nonatomic) UILabel *recordDurationLabel;
/**
 底部容器视图
 */
@property (strong, nonatomic) UIView *bottomContentView;
/**
 拍照/录制按钮
 */
@property (strong, nonatomic) UIButton *takeButton;
/**
 切换为视屏录制模式
 */
@property (strong, nonatomic) UIButton *videoTabButton;
/**
 切换为拍照模式
 */
@property (strong, nonatomic) UIButton *photoTabButton;
/**
 切换为拍摄文档模式
 */
@property (strong, nonatomic) UIButton *documentTabButton;
/**
 取消按钮
 */
@property (strong, nonatomic) UIButton *cancelButton;
@end

@implementation CXVideoCaptureViewController

NSMutableArray * queue;

NSObject * queueLockObject = [[NSObject alloc] init];
NSObject * aggregateRectangleLockObject = [[NSObject alloc] init];

Rectangle * aggregateRectangle;
RectangleCALayer *rectangleCALayer;// = [[RectangleCALayer alloc] init];

//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//        _camera = 0;
//        _qualityPreset = AVCaptureSessionPresetHigh;
//    }
//    return self;
//}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _camera = 0;
    
    [self createCaptureSessionForCamera:_camera qualityPreset:_qualityPreset];
    
    [self reloadCameraConfiguration];
    
    [self setupControl];
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    aggregateRectangle = nil;
    queue = [[NSMutableArray alloc] initWithCapacity:5];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self destroyCaptureSession];
}

- (NSString *)videoPath {
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *moviePath = [basePath stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"%f.mov",[NSDate date].timeIntervalSince1970]];
    return moviePath;
}

- (void)startVideoCapture {
    [self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self videoPath]] recordingDelegate:self];
}


- (void)stopVideoCapture {
    if ([self.movieFileOutput isRecording]) {
        [self.movieFileOutput stopRecording];
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@"Recording is started ...");
    // Hide some control elements
    self.takeButton.tag = 1;
    [self.takeButton setImage:[UIImage imageNamed:@"record_ing"] forState:UIControlStateNormal];
    self.bottomContentView.hidden = YES;
    self.cameraButton.hidden = YES;
    self.cancelButton.hidden = YES;
    
    if (_calVideoDurationTimer == nil) {
        _calVideoDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(handleCalVideoDuration:) userInfo:nil repeats:YES];
    }
}

-(NSString *)stringFromInterval:(NSTimeInterval)timeInterval
{
#define SECONDS_PER_MINUTE (60)
#define MINUTES_PER_HOUR (60)
#define SECONDS_PER_HOUR (SECONDS_PER_MINUTE * MINUTES_PER_HOUR)
#define HOURS_PER_DAY (24)
    
    // convert the time to an integer, as we don't need double precision, and we do need to use the modulous operator
    int ti = round(timeInterval);
    
    return [NSString stringWithFormat:@"%.2d:%.2d:%.2d", (ti / SECONDS_PER_HOUR) % HOURS_PER_DAY, (ti / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR, ti % SECONDS_PER_MINUTE];
    
#undef SECONDS_PER_MINUTE
#undef MINUTES_PER_HOUR
#undef SECONDS_PER_HOUR
#undef HOURS_PER_DAY
}

- (void)handleCalVideoDuration:(NSTimer*)timer
{
    float totalSeconds = CMTimeGetSeconds(self.movieFileOutput.recordedDuration);
    self.recordDurationLabel.text = [self stringFromInterval:totalSeconds];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"Recording is stoped ...");
    
    if (_calVideoDurationTimer != nil) {
        [_calVideoDurationTimer invalidate];
        _calVideoDurationTimer = nil;
    }
    
    // Recover control elements' state those be hiddened before
    self.takeButton.tag = 0;
    [self.takeButton setImage:[UIImage imageNamed:@"record_idle"] forState:UIControlStateNormal];
    self.bottomContentView.hidden = NO;
    self.cameraButton.hidden = NO;
    self.cancelButton.hidden = NO;
    
    // Call back when finished capture
    self.cameraCaptureResult(self.cameraMediaType, outputFileURL);
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Set torch on or off (if supported)
- (void)setTorchOn:(BOOL)torch
{
    NSError *error = nil;
    if ([_videoDevice hasTorch]) {
        BOOL locked = [_videoDevice lockForConfiguration:&error];
        if (locked) {
            _videoDevice.torchMode = (torch)? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
            [_videoDevice unlockForConfiguration];
        }
    }
}

// Return YES if the torch is on
- (BOOL)torchOn
{
    return (_videoDevice.torchMode == AVCaptureTorchModeOn);
}

/**
 选择前置/后置摄像头

 @param camera 0:后置 1:前置
 @return 是否设置成功
 */
- (BOOL)setCamera:(int)camera
{
    if (camera != 0 && camera != 1)
    {
        return NO;
    }
    
    if (camera != _camera)
    {
        if (_captureSession) {
            
            NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
            
            if (camera < 0 && camera >= [devices count]) {
                NSLog(@"摄像头无法访问:%d",camera);
                return NO;
            }
            [_captureSession beginConfiguration];
            
            /*
            NSArray *inputs = _captureSession.inputs;
            for (AVCaptureDeviceInput *input in inputs ) {
                AVCaptureDevice *device = input.device;
                if ( [device hasMediaType:AVMediaTypeVideo] ) {
                    //AVCaptureDevicePosition position = device.position;
                    [_captureSession removeInput:input];
                    break;
                }
            }
             */
            
            // Remove current camera
            [_captureSession removeInput:_videoInput];
            _videoInput = nil;

            _videoDevice = [devices objectAtIndex:camera];
            _camera = camera;
            
            // Create device input
            NSError *error = nil;
            _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
            [_captureSession addInput:_videoInput];
            
            [_captureSession commitConfiguration];
        }
    }
    return YES;
}


// MARK: AVCaptureVideoDataOutputSampleBufferDelegate delegate methods

// AVCaptureVideoDataOutputSampleBufferDelegate delegate method called when a video frame is available
//
// This method is called on the video capture GCD queue. A cv::Mat is created from the frame data and
// passed on for processing with OpenCV.
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.cameraMediaType == kCameraMediaTypeDocument)
    {
        [self processDocumentBuffer:sampleBuffer];
    }
    else if(self.cameraMediaType == kCameraMediaTypePhoto)
    {
        NSLog(@"kCameraMediaTypePhoto");
    }
    else if(self.cameraMediaType == kCameraMediaTypeVideo)
    {
        NSLog(@"kCameraMediaTypeVideo");
    }
}

- (void) processDocumentBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    AVCaptureVideoOrientation videoOrientation = [[[_videoOutput connections] objectAtIndex:0] videoOrientation];
    
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        // For grayscale mode, the luminance channel of the YUV data is used
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC1, baseaddress, 0);
        
        [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else if (format == kCVPixelFormatType_32BGRA) {
        // For color mode a 4-channel cv::Mat is created from the BGRA data
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC4, baseaddress, 0);
        
        [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    else {
        NSLog(@"Unsupported video format");
    }
}


// MARK: Methods to override

// Override this method to process the video frame with OpenCV
//
// Note that this method is called on the video capture GCD queue. Use dispatch_sync or dispatch_async to update UI
// from the main queue.
//
// mat: The frame as an OpenCV::Mat object. The matrix will have 1 channel for grayscale frames and 4 channels for
//      BGRA frames. (Use -[VideoCaptureViewController setGrayscale:])
// rect: A CGRect describing the video frame dimensions
// orientation: Will generally by AVCaptureVideoOrientationLandscapeRight for the back camera and
//              AVCaptureVideoOrientationLandscapeRight for the front camera
//
- (void)processFrame:(cv::Mat &)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)orientation
{
    // Shrink video frame to 320X240
    cv::resize(mat, mat, cv::Size(), 0.25f, 0.25f, CV_INTER_LINEAR);
    rect.size.width /= 4.0f;
    rect.size.height /= 4.0f;
    
    //    float ratioW = 240.0 / rect.size.width;
    //    //float ratioH= 320.0 / rect.size.height;
    //    cv::resize(mat, mat, cv::Size(), ratioW, ratioW, CV_INTER_LINEAR);
    //    rect.size.width *= ratioW;
    //    rect.size.height *= ratioW;
    
    // Rotate video frame by 90deg to portrait by combining a transpose and a flip
    // Note that AVCaptureVideoDataOutput connection does NOT support hardware-accelerated
    // rotation and mirroring via videoOrientation and setVideoMirrored properties so we
    // need to do the rotation in software here.
    cv::transpose(mat, mat);
    CGFloat temp = rect.size.width;
    rect.size.width = rect.size.height;
    rect.size.height = temp;
    
    if (orientation == AVCaptureVideoOrientationLandscapeRight)
    {
        // flip around y axis for back camera
        cv::flip(mat, mat, 1);
    }
    else {
        // Front camera output needs to be mirrored to match preview layer so no flip is required here
    }
    
    orientation = AVCaptureVideoOrientationPortrait;
    
    long start = [[NSDate date] timeIntervalSince1970 ] * 1000;
    
    Rectangle * rectangle = [self getLargestRectangleInFrame:mat];
    
    [self processRectangleFromFrame:rectangle]; //inFrame:frameNumber];
    
    long end = [[NSDate date] timeIntervalSince1970 ] * 1000;
    
    long difference = end - start;
    
    //NSLog(@"%@", [NSString stringWithFormat:@"Millis to calculate: %ld", difference]);
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self displayDataForVideoRect:rect videoOrientation:orientation];
    });
}

- (void) displayDataForVideoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    
    @synchronized (self) {
        
        CGAffineTransform t = [self affineTransformForVideoFrame:rect orientation:videoOrientation];
        
        if ( aggregateRectangle ){
            
            CGPoint transformedTopLeft = CGPointApplyAffineTransform(CGPointMake(aggregateRectangle.topLeftX, aggregateRectangle.topLeftY), t);
            CGPoint transformedTopRight = CGPointApplyAffineTransform(CGPointMake(aggregateRectangle.topRightX, aggregateRectangle.topRightY), t);
            CGPoint transformedBottomLeft = CGPointApplyAffineTransform(CGPointMake(aggregateRectangle.bottomLeftX, aggregateRectangle.bottomLeftY), t);
            CGPoint transformedBottomRight = CGPointApplyAffineTransform(CGPointMake(aggregateRectangle.bottomRightX, aggregateRectangle.bottomRightY), t);
            
            aggregateRectangle.topLeftX = transformedTopLeft.x;
            aggregateRectangle.topRightX = transformedTopRight.x;
            aggregateRectangle.bottomLeftX = transformedBottomLeft.x;
            aggregateRectangle.bottomRightX = transformedBottomRight.x;
            
            aggregateRectangle.topLeftY = transformedTopLeft.y;
            aggregateRectangle.topRightY = transformedTopRight.y;
            aggregateRectangle.bottomLeftY = transformedBottomLeft.y;
            aggregateRectangle.bottomRightY = transformedBottomRight.y;
        }
        
        
        [rectangleCALayer setFrame:self.videoPreviewLayer.frame];
        [rectangleCALayer updateDetect:aggregateRectangle];
    }
}

- (void) processRectangleFromFrame:(Rectangle *)rectangle// inFrame:(long)frame
{
    if ( !rectangle ){
        // the rectangle is null, so remove the oldest frame from the queue
        [self removeOldestFrameFromRectangleQueue];
        [self updateAggregateRectangle:rectangle];
    }
    else{
        BOOL significantChange = [self checkForSignificantChange:rectangle withAggregate:aggregateRectangle];
        if ( significantChange ){
            // empty the queue, and make the new rectangle the aggregated rectangle for now
            [self emptyQueue];
            [self updateAggregateRectangle:rectangle];
        }
        else{
            // remove the oldest frame
            [self removeOldestFrameFromRectangleQueue];
            // then add the new frame, and average the 5 to build an aggregate rectangle
            [self addRectangleToQueue:rectangle];
            Rectangle * aggregate = [self buildAggregateRectangleFromQueue];
            [self updateAggregateRectangle:aggregate];
        }
    }
}

- (Rectangle *) buildAggregateRectangleFromQueue{
    @synchronized(queueLockObject){
        double topLeftX = 0;
        double topLeftY = 0;
        double topRightX = 0;
        double topRightY = 0;
        double bottomLeftX = 0;
        double bottomLeftY = 0;
        double bottomRightX = 0;
        double bottomRightY = 0;
        
        if ( !queue ){
            return nil;
        }
        
        for ( int i = 0; i < [queue count]; i++ ){
            Rectangle * temp = [queue objectAtIndex:i];
            topLeftX = topLeftX + temp.topLeftX;
            topLeftY = topLeftY + temp.topLeftY;
            topRightX = topRightX + temp.topRightX;
            topRightY = topRightY + temp.topRightY;
            bottomLeftX = bottomLeftX + temp.bottomLeftX;
            bottomLeftY = bottomLeftY + temp.bottomLeftY;
            bottomRightX = bottomRightX + temp.bottomRightX;
            bottomRightY = bottomRightY + temp.bottomRightY;
        }
        
        Rectangle * aggregate = [[Rectangle alloc] init];
        aggregate.topLeftX = round(topLeftX/[queue count]);
        aggregate.topLeftY = round(topLeftY/[queue count]);
        aggregate.topRightX = round(topRightX/[queue count]);
        aggregate.topRightY = round(topRightY/[queue count]);
        aggregate.bottomLeftX = round(bottomLeftX/[queue count]);
        aggregate.bottomLeftY = round(bottomLeftY/[queue count]);
        aggregate.bottomRightX = round(bottomRightX/[queue count]);
        aggregate.bottomRightY = round(bottomRightY/[queue count]);
        
        return aggregate;
    }
}

- (void) updateAggregateRectangle:(Rectangle *)rectangle{
    @synchronized(aggregateRectangleLockObject){
        aggregateRectangle = rectangle;
    }
}

- (void) emptyQueue{
    @synchronized(queueLockObject){
        if ( queue ){
            [queue removeAllObjects];
        }
    }
}

- (BOOL) checkForSignificantChange:(Rectangle *)rectangle withAggregate:(Rectangle *)aggregate {
    @synchronized(aggregateRectangleLockObject){
        if ( !aggregate ){
            return YES;
        }
        else{
            // compare each point
            int maxDiff = 12;
            
            int topLeftXDiff = abs(rectangle.topLeftX - aggregate.topLeftX);
            int topLeftYDiff = abs(rectangle.topLeftY - aggregate.topLeftY);
            int topRightXDiff = abs(rectangle.topRightX - aggregate.topRightX);
            int topRightYDiff = abs(rectangle.topRightY - aggregate.topRightY);
            
            int bottomLeftXDiff = abs(rectangle.bottomLeftX - aggregate.bottomLeftX);
            int bottomLeftYDiff = abs(rectangle.bottomLeftY - aggregate.bottomLeftY);
            int bottomRightXDiff = abs(rectangle.bottomRightX - aggregate.bottomRightX);
            int bottomRightYDiff = abs(rectangle.bottomRightY - aggregate.bottomRightY);
            
            if ( topLeftXDiff > maxDiff || topLeftYDiff > maxDiff || topRightXDiff > maxDiff || topRightYDiff > maxDiff || bottomLeftXDiff > maxDiff || bottomLeftYDiff > maxDiff || bottomRightXDiff > maxDiff || bottomRightYDiff > maxDiff ){
                
                return YES;
            }
            
            return NO;
        }
    }
}

- (void) removeOldestFrameFromRectangleQueue{
    @synchronized(queueLockObject){
        if ( queue ){
            int index = (int)[queue count] - 1;
            if ( index >= 0 ){
                [queue removeObjectAtIndex:index];
            }
        }
    }
}

- (void) addRectangleToQueue:(Rectangle *)rectangle{
    @synchronized(queueLockObject){
        if ( queue ){
            // per apple docs, If index is already occupied, the objects at index and beyond are shifted by adding 1 to their indices to make room.
            // put the rectangle at index 0 and let the NSArray scoot everything back one position
            [queue insertObject:rectangle atIndex:0];
        }
    }
}

- (Rectangle *) getLargestRectangleInFrame:(cv::Mat)mat{
    std::vector<std::vector<cv::Point>>squares;
    std::vector<cv::Point> largest_square;
    
    find_squares(mat, squares);
    find_largest_square(squares, largest_square);
    Rectangle * rectangle;
    if (largest_square.size() == 4 ){
        NSMutableArray * points = [[NSMutableArray alloc] initWithCapacity:4];
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(largest_square[0].x, largest_square[0].y)]];
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(largest_square[1].x, largest_square[1].y)]];
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(largest_square[2].x, largest_square[2].y)]];
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(largest_square[3].x, largest_square[3].y)]];
        
        // okay, sort it by the X, then split it
        NSArray * sortedArray = [points sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
            CGPoint firstPoint = [obj1 CGPointValue];
            CGPoint secondPoint = [obj2 CGPointValue];
            if (firstPoint.x > secondPoint.x) {
                return NSOrderedDescending;
            } else if (firstPoint.x < secondPoint.x) {
                return NSOrderedAscending;
            } else {
                return NSOrderedSame;
            }
        }];
        
        // we're sorted on X, so grab two of those bitches and figure out top and bottom
        NSMutableArray * left = [[NSMutableArray alloc] initWithCapacity:2];
        NSMutableArray * right = [[NSMutableArray alloc] initWithCapacity:2];
        [left addObject:sortedArray[0]];
        [left addObject:sortedArray[1]];
        
        [right addObject:sortedArray[2]];
        [right addObject:sortedArray[3]];
        
        // okay, now sort each of those arrays on the Y access
        NSArray * sortedLeft = [left sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
            CGPoint firstPoint = [obj1 CGPointValue];
            CGPoint secondPoint = [obj2 CGPointValue];
            if (firstPoint.y > secondPoint.y) {
                return NSOrderedDescending;
            } else if (firstPoint.y < secondPoint.y) {
                return NSOrderedAscending;
            } else {
                return NSOrderedSame;
            }
        }];
        
        NSArray * sortedRight = [right sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
            CGPoint firstPoint = [obj1 CGPointValue];
            CGPoint secondPoint = [obj2 CGPointValue];
            if (firstPoint.y > secondPoint.y) {
                return NSOrderedDescending;
            } else if (firstPoint.y < secondPoint.y) {
                return NSOrderedAscending;
            } else {
                return NSOrderedSame;
            }
        }];
        
        CGPoint topLeftOriginal = [[sortedLeft objectAtIndex:0] CGPointValue];
        
        CGPoint topRightOriginal = [[sortedRight objectAtIndex:0] CGPointValue];
        
        CGPoint bottomLeftOriginal = [[sortedLeft objectAtIndex:1] CGPointValue];
        
        CGPoint bottomRightOriginal = [[sortedRight objectAtIndex:1] CGPointValue];
        
        rectangle = [[Rectangle alloc] init];
        
        
        rectangle.bottomLeftX = bottomLeftOriginal.x;
        rectangle.bottomRightX = bottomRightOriginal.x;
        rectangle.topLeftX = topLeftOriginal.x;
        rectangle.topRightX = topRightOriginal.x;
        
        rectangle.bottomLeftY = bottomLeftOriginal.y;
        rectangle.bottomRightY = bottomRightOriginal.y;
        rectangle.topLeftY = topLeftOriginal.y;
        rectangle.topRightY = topRightOriginal.y;
    }
    
    return rectangle;
}

void find_squares(cv::Mat& image, std::vector<std::vector<cv::Point>>&squares) {
    
    // blur will enhance edge detection
    cv::Mat blurred(image);
    
    /*
     medianBlur函数使用中值滤波器来平滑（模糊）处理一张图片，从src输入，而结果从dst输出。且对于多通道图片，每一个通道都单独进行处理，并且支持就地操作（In-placeoperation）。
     第一个参数，InputArray类型的src，函数的输入参数，填1、3或者4通道的Mat类型的图像；当ksize为3或者5的时候，图像深度需为CV_8U，CV_16U，或CV_32F其中之一，而对于较大孔径尺寸的图片，它只能是CV_8U。
     第二个参数，OutputArray类型的dst，即目标图像，函数的输出参数，需要和源图片有一样的尺寸和类型。我们可以用Mat::Clone，以源图片为模板，来初始化得到如假包换的目标图。
     第三个参数，int类型的ksize，孔径的线性尺寸（aperture linear size），注意这个参数必须是大于1的奇数，比如：3，5，7，9 ...
     */
    medianBlur(image, blurred, 7);
    
    cv::Mat gray0(blurred.size(), CV_8U), gray;
    std::vector<std::vector<cv::Point>> contours;
    
    // find squares in every color plane of the image
    for (int c = 0; c < 3; c++)
    {
        int ch[] = {c, 0};
        mixChannels(&blurred, 1, &gray0, 1, ch, 1);
        
        // try several threshold levels
        const int threshold_level = 4;
        for (int l = 0; l < threshold_level; l++)
        {
            // Use Canny instead of zero threshold level!
            // Canny helps to catch squares with gradient shading
            if (l == 0){
                
                /*
                 采用Canny方法对图像进行边缘检测
                 第一个参数表示输入图像，必须为单通道灰度图。
                 第二个参数表示输出的边缘图像，为单通道黑白图。
                 第三个参数和第四个参数表示阈值，这二个阈值中当中的小阈值用来控制边缘连接，大的阈值用来控制强边缘的初始分割即如果一个像素的梯度大与上限值，则被认为是边缘像素，如果小于下限阈值，则被抛弃。如果该点的梯度在两者之间则当这个点与高于上限值的像素点连接时我们才保留，否则删除。
                 第五个参数表示Sobel 算子大小，默认为3即表示一个3*3的矩阵。
                 
                 */
                Canny(gray0, gray, 100, 100, 3); //
                //Canny(gray0, gray, 1, 3, 5); //
                // Dilate helps to remove potential holes between edge segments
                dilate(gray, gray, cv::Mat(), cv::Point(-1,-1));
            }
            else{
                gray = gray0 >= (l+1) * 255 / threshold_level;
                //cv::Size size = image.size();
                //cv::adaptiveThreshold(gray0, gray, threshold_level, CV_ADAPTIVE_THRESH_GAUSSIAN_C, CV_THRESH_BINARY, (size.width + size.height) / 200, l);
            }
            
            // Find contours and store them in a list
            //findContours(gray, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);
            
            /*
             第一个参数：image，单通道图像矩阵，可以是灰度图，但更常用的是二值图像，一般是经过Canny、拉普拉斯等边
             缘检测算子处理过的二值图像；
             第二个参数：contours，定义为“vector<vector<Point>> contours”，是一个向量，并且是一个双重向量，向量
             内每个元素保存了一组由连续的Point点构成的点的集合的向量，每一组Point点集就是一个轮廓。
             有多少轮廓，向量contours就有多少元素。
             第三个参数：int型的mode，定义轮廓的检索模式：
             取值一：CV_RETR_EXTERNAL只检测最外围轮廓，包含在外围轮廓内的内围轮廓被忽略
             取值二：CV_RETR_LIST   检测所有的轮廓，包括内围、外围轮廓，但是检测到的轮廓不建立等级关
             系，彼此之间独立，没有等级关系，这就意味着这个检索模式下不存在父轮廓或内嵌轮廓，
             所以hierarchy向量内所有元素的第3、第4个分量都会被置为-1，具体下文会讲到
             取值三：CV_RETR_CCOMP  检测所有的轮廓，但所有轮廓只建立两个等级关系，外围为顶层，若外围
             内的内围轮廓还包含了其他的轮廓信息，则内围内的所有轮廓均归属于顶层
             取值四：CV_RETR_TREE， 检测所有轮廓，所有轮廓建立一个等级树结构。外层轮廓包含内层轮廓，内
             层轮廓还可以继续包含内嵌轮廓。
             第五个参数：int型的method，定义轮廓的近似方法：
             取值一：CV_CHAIN_APPROX_NONE 保存物体边界上所有连续的轮廓点到contours向量内
             取值二：CV_CHAIN_APPROX_SIMPLE 仅保存轮廓的拐点信息，把所有轮廓拐点处的点保存入contours
             向量内，拐点与拐点之间直线段上的信息点不予保留
             取值三和四：CV_CHAIN_APPROX_TC89_L1，CV_CHAIN_APPROX_TC89_KCOS使用teh-Chinl chain 近
             似算法
             */
            findContours(gray, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);
            
            // Test contours
            std::vector<cv::Point> approx;
            for (size_t i = 0; i < contours.size(); i++)
            {
                // approximate contour with accuracy proportional
                // to the contour perimeter
                approxPolyDP(cv::Mat(contours[i]), approx, arcLength(cv::Mat(contours[i]), true)*0.02, true);
                
                // Note: absolute value of an area is used because
                // area may be positive or negative - in accordance with the
                // contour orientation
                //if (approx.size() == 4 && fabs(contourArea(cv::Mat(approx))) > 100 && isContourConvex(cv::Mat(approx)))
                if (approx.size() == 4 && fabs(contourArea(cv::Mat(approx))) > 500 ){
                    //if ( approx.size() == 4 ){
                    double maxCosine = 0;
                    
                    for (int j = 2; j < 5; j++){
                        double cosine = fabs(angle(approx[j%4], approx[j-2], approx[j-1]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    
                    if (maxCosine < 0.3)
                        squares.push_back(approx);
                }
            }
        }
    }
}

// helper function:
// finds a cosine of angle between vectors
// from pt0->pt1 and from pt0->pt2
double angle( cv::Point pt1, cv::Point pt2, cv::Point pt0 ) {
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}


void find_largest_square(const std::vector<std::vector<cv::Point> >& squares, std::vector<cv::Point>& biggest_square)
{
    if (!squares.size()){
        // no squares detected
        return;
    }
    
    /*int max_width = 0;
     int max_height = 0;
     int max_square_idx = 0;
     
     for (size_t i = 0; i < squares.size(); i++)
     {
     // Convert a set of 4 unordered Points into a meaningful cv::Rect structure.
     cv::Rect rectangle = boundingRect(cv::Mat(squares[i]));
     
     //        cout << "find_largest_square: #" << i << " rectangle x:" << rectangle.x << " y:" << rectangle.y << " " << rectangle.width << "x" << rectangle.height << endl;
     
     // Store the index position of the biggest square found
     if ((rectangle.width >= max_width) && (rectangle.height >= max_height))
     {
     max_width = rectangle.width;
     max_height = rectangle.height;
     max_square_idx = (int) i;
     }
     }
     
     biggest_square = squares[max_square_idx];
     */
    
    double maxArea = 0;
    int largestIndex = -1;
    
    for ( int i = 0; i < squares.size(); i++){
        std::vector<cv::Point> square = squares[i];
        double area = contourArea(cv::Mat(square));
        if ( area >= maxArea){
            largestIndex = i;
            maxArea = area;
        }
    }
    if ( largestIndex >= 0 && largestIndex < squares.size() ){
        biggest_square = squares[largestIndex];
    }
    return;
}


// MARK: Geometry methods

// Create an affine transform for converting CGPoints and CGRects from the video frame coordinate space to the
// preview layer coordinate space. Usage:
//
// CGPoint viewPoint = CGPointApplyAffineTransform(videoPoint, transform);
// CGRect viewRect = CGRectApplyAffineTransform(videoRect, transform);
//
// Use CGAffineTransformInvert to create an inverse transform for converting from the view cooridinate space to
// the video frame coordinate space.
//
// videoFrame: a rect describing the dimensions of the video frame
// video orientation: the video orientation
//
// Returns an affine transform
//
- (CGAffineTransform)affineTransformForVideoFrame:(CGRect)videoFrame orientation:(AVCaptureVideoOrientation)videoOrientation
{
    CGSize viewSize = self.view.bounds.size;
    NSString * const videoGravity = _videoPreviewLayer.videoGravity;
    CGFloat widthScale = 1.0f;
    CGFloat heightScale = 1.0f;
    
    // Move origin to center so rotation and scale are applied correctly
    CGAffineTransform t = CGAffineTransformMakeTranslation(-videoFrame.size.width / 2.0f, -videoFrame.size.height / 2.0f);
    
    switch (videoOrientation) {
        case AVCaptureVideoOrientationPortrait:
            widthScale = viewSize.width / videoFrame.size.width;
            heightScale = viewSize.height / videoFrame.size.height;
            break;
            
        case AVCaptureVideoOrientationPortraitUpsideDown:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(M_PI));
            widthScale = viewSize.width / videoFrame.size.width;
            heightScale = viewSize.height / videoFrame.size.height;
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(M_PI_2));
            widthScale = viewSize.width / videoFrame.size.height;
            heightScale = viewSize.height / videoFrame.size.width;
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(-M_PI_2));
            widthScale = viewSize.width / videoFrame.size.height;
            heightScale = viewSize.height / videoFrame.size.width;
            break;
    }
    
    // Adjust scaling to match video gravity mode of video preview
    if (videoGravity == AVLayerVideoGravityResizeAspect) {
        heightScale = MIN(heightScale, widthScale);
        widthScale = heightScale;
    }
    else if (videoGravity == AVLayerVideoGravityResizeAspectFill) {
        heightScale = MAX(heightScale, widthScale);
        widthScale = heightScale;
    }
    
    // Apply the scaling
    t = CGAffineTransformConcat(t, CGAffineTransformMakeScale(widthScale, heightScale));
    
    // Move origin back from center
    t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(viewSize.width / 2.0f, viewSize.height / 2.0f));
                                
    return t;
}

/**
 Sets up the video capture session for the specified camera, quality and grayscale mode

 @param camera -1 for default, 0 for back camera, 1 for front camera
 @param qualityPreset [AVCaptureSession sessionPreset] value
 @return Created Success or not
 */
- (BOOL)createCaptureSessionForCamera:(NSInteger)camera qualityPreset:(NSString *)qualityPreset
{
    // Get capture devices from current iPhone
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    if ([devices count] == 0) {
        NSLog(@"ANTBETA: No any Camera be Found.");
        return NO;
    }
    
    if (_camera < 0 && _camera >= [devices count]) {
        NSLog(@"ANTBETA: The camera[%d] Can not be found from current device.", _camera);
        return NO;
    }
    
    _videoDevice = [devices objectAtIndex:_camera];
    
    // Create a video input with the video device.
    NSError *error = nil;
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
    if (error) {
        NSLog(@"ANTBETA: An error occured when create an AVCaptureDeviceInput with '_videoDevice': %@",[error description]);
        return NO;
    }
    
    // Create a CaptureSession, It coordinates the flow of data between audio and video inputs and outputs.
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Connect up inputs and outputs
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    
    // Create the preview layer
    _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreviewLayer setFrame:self.view.bounds];
    _videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer insertSublayer:_videoPreviewLayer atIndex:0];
    
    [_captureSession startRunning];
    
    return YES;
}

// Tear down the video capture session
- (void)destroyCaptureSession
{
    [_captureSession beginConfiguration];
    for (AVCaptureInput *item in [_captureSession inputs]) {
        [_captureSession removeInput:item];
    }
    [_captureSession commitConfiguration];
    
    [_captureSession stopRunning];
    
//    [_videoPreviewLayer removeFromSuperlayer];
//    
//    _videoPreviewLayer = nil;
    
    _videoInput = nil;
    _audioInput = nil;
    
    _videoOutput = nil;
    _audioDataOutput = nil;
    
    _videoDevice = nil;
    _audioDevice = nil;
    
    _movieFileOutput = nil;
    _stillImageOutput = nil;
    
    _captureSession = nil;
    
    [rectangleCALayer removeFromSuperlayer];
    rectangleCALayer = nil;
}

#pragma mark - UI Element

- (void) setupControl
{
    [self.view addSubview:self.topContentView];
    self.topContentView.frame = CGRectMake(0, 0, SCREEN_WIDTH, 50);
    
    [self.topContentView addSubview:self.torchButton];
    self.torchButton.frame = CGRectMake(0, 0, VIEW_HEIGHT(self.topContentView), VIEW_HEIGHT(self.topContentView));
    
    [self.topContentView addSubview:self.cameraButton];
    self.cameraButton.frame = CGRectMake(0, 0, VIEW_HEIGHT(self.topContentView), VIEW_HEIGHT(self.topContentView));
    [self.cameraButton modifyX:SCREEN_WIDTH - VIEW_WIDTH(self.cameraButton)];
    
    [self.topContentView addSubview:self.recordDurationLabel];
    self.recordDurationLabel.frame = CGRectMake(VIEW_WIDTH(self.torchButton), 0, (SCREEN_WIDTH - VIEW_WIDTH(self.torchButton) - VIEW_WIDTH(self.cameraButton)), VIEW_HEIGHT(self.topContentView));
    
    self.bottomContentView.frame = CGRectMake(0, SCREEN_HEIGHT - 120, SCREEN_WIDTH, 120);
    [self.view addSubview:self.bottomContentView];
    
    [self.view addSubview:self.takeButton];
    [self.takeButton modifySize:CGSizeMake(57, 57)];
    [self.takeButton modifyCenterX:self.bottomContentView.center.x];
    [self.takeButton modifyCenterY:self.bottomContentView.center.y + 10];
    [self.takeButton modifyY:VIEW_TOP(self.takeButton) + 10];
    
    [self.view addSubview:self.cancelButton];
    [self.cancelButton modifyX:10];
    [self.cancelButton modifySize:CGSizeMake(50, 40)];
    [self.cancelButton modifyCenterY:self.takeButton.center.y];

    
    [self.bottomContentView addSubview:self.videoTabButton];
    [self.bottomContentView addSubview:self.photoTabButton];
    [self.bottomContentView addSubview:self.documentTabButton];
    
    [self setupTabWithAnimated:NO];
    
    [self setSwipe];
    [self setClick];
}

- (void) setSwipe
{
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeRight:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeLeft:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    
    self.view.userInteractionEnabled = YES;
    [self.view addGestureRecognizer:swipeRight];
    [self.view addGestureRecognizer:swipeLeft];
}

- (void) setClick
{
    [self.cancelButton addTarget:self action:@selector(onControlElementClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.takeButton addTarget:self action:@selector(onControlElementClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.torchButton addTarget:self action:@selector(onControlElementClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.cameraButton addTarget:self action:@selector(onControlElementClick:) forControlEvents:UIControlEventTouchUpInside];
    
}


//_videoInput = nil; -
//_audioInput = nil;
//
//_videoOutput = nil;
//_audioDataOutput = nil;
//
//_videoDevice = nil; -
//_audioDevice = nil;
//
//_movieFileOutput = nil;
//_stillImageOutput = nil;


// 配置拍照参数
- (void) configurationForPhoto
{
    if (_captureSession)
    {
        [_captureSession beginConfiguration];
        
        if (_videoOutput)
        {
            [_captureSession removeOutput:_videoOutput];
            _videoOutput = nil;
        }
        if (_audioInput)
        {
            [_captureSession removeInput:_audioInput];
            _audioInput = nil;
            _audioDevice = nil;
        }
        if (_audioDataOutput)
        {
            [_captureSession removeOutput:_audioDataOutput];
            _audioDataOutput = nil;
        }
        if (_movieFileOutput)
        {
            [_captureSession removeOutput:_movieFileOutput];
            _movieFileOutput = nil;
        }
        if (_stillImageOutput)
        {
            [_captureSession removeOutput:_stillImageOutput];
            _stillImageOutput = nil;
        }
        
        _captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
        
        _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        
        if ([_captureSession canAddOutput:_stillImageOutput]) {
            [_captureSession addOutput:_stillImageOutput];
        }
        
        [_captureSession commitConfiguration];
    }
}

// To configure specific video's settings
- (void) configurationForVideo
{
    if (_captureSession)
    {
        [_captureSession beginConfiguration];
        
        if (_videoOutput)
        {
            [_captureSession removeOutput:_videoOutput];
            _videoOutput = nil;
        }
        if (_audioInput)
        {
            [_captureSession removeInput:_audioInput];
            _audioInput = nil;
            _audioDevice = nil;
        }
        if (_audioDataOutput)
        {
            [_captureSession removeOutput:_audioDataOutput];
            _audioDataOutput = nil;
        }
        if (_movieFileOutput)
        {
            [_captureSession removeOutput:_movieFileOutput];
            _movieFileOutput = nil;
        }
        if (_stillImageOutput)
        {
            [_captureSession removeOutput:_stillImageOutput];
            _stillImageOutput = nil;
        }
        
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        
        // Get audio device
        _audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        
        // Create an audio device with the audio device.
        NSError *error = nil;
        _audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioDevice error:&error];
        if (error) {
            NSLog(@"ANTBETA: An error occured when create an AVCaptureDeviceInput with '_audioDevice': %@",[error description]);
            return;
        }
        
        // The easiest option to write video to file is through an AVCaptureMovieFileOutput object. Adding it as an output to a capture session will let you write audio and video to a QuickTime file with a minimum amount of configuration:
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        _movieFileOutput.maxRecordedDuration = CMTimeMakeWithSeconds(30, 30);
        
        if ([_captureSession canAddInput:_audioInput]) {
            [_captureSession addInput:_audioInput];
        }
        if ([_captureSession canAddOutput:_movieFileOutput]) {
            [_captureSession addOutput:_movieFileOutput];
        }
        
        [_captureSession commitConfiguration];
    }
    
}

// 配置拍摄文档录制参数
- (void) configurationForDocument
{
    if (_captureSession)
    {
        [_captureSession beginConfiguration];
        
        if (_camera == 1)
        { // 1是前置摄像头，需要换成后置摄像头
            NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
            if ([devices count] == 0) {
                NSLog(@"ANTBETA: No any Camera be Found.");
                [_captureSession commitConfiguration];
                return;
            }
            // Remove current camera
            [_captureSession removeInput:_videoInput];
            _videoInput = nil;
            
            _videoDevice = [devices objectAtIndex:0];
            _camera = 0;
            
            // Create device input
            NSError *error = nil;
            _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
            [_captureSession addInput:_videoInput];
        }
        if (_videoOutput)
        {
            [_captureSession removeOutput:_videoOutput];
            _videoOutput = nil;
        }
        if (_audioInput)
        {
            [_captureSession removeInput:_audioInput];
            _audioInput = nil;
            _audioDevice = nil;
        }
        if (_audioDataOutput)
        {
            [_captureSession removeOutput:_audioDataOutput];
            _audioDataOutput = nil;
        }
        if (_movieFileOutput)
        {
            [_captureSession removeOutput:_movieFileOutput];
            _movieFileOutput = nil;
        }
        if (_stillImageOutput)
        {
            [_captureSession removeOutput:_stillImageOutput];
            _stillImageOutput = nil;
        }
        
        _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
        
        // Create and configure device output
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        dispatch_queue_t captureQueue = dispatch_queue_create("com.antbeta.AVCameraCaptureQueue", DISPATCH_QUEUE_SERIAL);
        [_videoOutput setSampleBufferDelegate:self queue:captureQueue];
        _videoOutput.alwaysDiscardsLateVideoFrames = YES;
        _videoOutput.minFrameDuration = CMTimeMake(1, 30);
        
        // For color mode, BGRA format is used
        OSType format = kCVPixelFormatType_32BGRA;
        _videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:format]
                                                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        
        // Connect up inputs and outputs
        if ([_captureSession canAddOutput:_videoOutput]) {
            [_captureSession addOutput:_videoOutput];
        }
        
        if ([_captureSession canAddOutput:_stillImageOutput]) {
            [_captureSession addOutput:_stillImageOutput];
        }
        
        [_captureSession commitConfiguration];
    }
}

- (void) reloadCameraConfiguration
{
    switch (self.cameraMediaType) {
        case kCameraMediaTypeVideo:// 录制视频
            [self configurationForVideo];
            if (rectangleCALayer) {
                [rectangleCALayer removeFromSuperlayer];
                rectangleCALayer = nil;
            }
            break;
        case kCameraMediaTypePhoto:// 拍照
            [self configurationForPhoto];
            if (rectangleCALayer) {
                [rectangleCALayer removeFromSuperlayer];
                rectangleCALayer = nil;
            }
            break;
        case kCameraMediaTypeDocument:// 拍摄文档
            [self configurationForDocument];
            if (!rectangleCALayer) {
                rectangleCALayer = [[RectangleCALayer alloc] init];
            }
            [_videoPreviewLayer addSublayer:rectangleCALayer];
            break;
        default:
            break;
    }
}

- (void) onControlElementClick:(id) sender
{
    // 点击取消按钮
    if (sender == self.cancelButton) {
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
    // 点击闪光灯按钮
    if (sender == self.torchButton) {
        [self setTorchOn:![self torchOn]];
    }
    // 点击相机切换按钮
    if (sender == self.cameraButton) {
        if ( _camera == 0)
        {
            [self setCamera:1];
        }else{
            [self setCamera:0];
        }
    }
    // 点击拍照／录制按钮
    if (sender == self.takeButton) {
        switch (self.cameraMediaType) {
            case kCameraMediaTypeVideo:// 录制视频
                if (self.takeButton.tag == 0) {
                    // 开始录制
                    [self startVideoCapture];
                }else{
                    // 结束录制
                    [self stopVideoCapture];
                }
                break;
            case kCameraMediaTypePhoto:// 拍照
                [self onCaptureImageButtonClick];
                break;
            case kCameraMediaTypeDocument:// 拍摄文档
                [self onCaptureDocumentButtonClick];
                break;
            default:
                break;
        }
    }
}

- (void) onCaptureImageButtonClick
{
    __weak typeof(self) weakSelf = self;
    [self captureImageWithCompletionHander:^(NSString *imageFilePath) {
        weakSelf.cameraCaptureResult(self.cameraMediaType, imageFilePath);
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void) onCaptureDocumentButtonClick
{
    __weak typeof(self) weakSelf = self;
    [self captureDocumentWithCompletionHander:^(NSString *imageFilePath) {
        weakSelf.cameraCaptureResult(self.cameraMediaType, imageFilePath);
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void) setupTabWithAnimated:(BOOL)animated
{
    
//    [UIView animateWithDuration:1 animations:^{
//        
//    } completion:^(BOOL finished) {
//        [snapShot removeFromSuperview];
//    }];
    
    
    switch (self.cameraMediaType) {
        case kCameraMediaTypeVideo:
            if (animated) {
                [UIView animateWithDuration:0.4 animations:^{
                    [self setVideoTabSelected];
                } completion:^(BOOL finished) {
                    
                }];
            }
            else
            {
                [self setVideoTabSelected];
            }
            break;
        case kCameraMediaTypePhoto:
            if (animated) {
                [UIView animateWithDuration:0.4 animations:^{
                    [self setPhotoTabSelected];
                } completion:^(BOOL finished) {
                    
                }];
            }
            else
            {
                [self setPhotoTabSelected];
            }
            break;
        case kCameraMediaTypeDocument:
            if (animated) {
                [UIView animateWithDuration:0.4 animations:^{
                    [self setDocumentTabSelected];
                } completion:^(BOOL finished) {
                    
                }];
            }
            else
            {
                [self setDocumentTabSelected];
            }
            break;
        default:
            break;
    }
}

-(void) setPhotoTabSelected
{
    self.photoTabButton.frame = CGRectMake(0, 6, 50, 30);
    [self.photoTabButton fitToHorizontalCenterWithView:self.bottomContentView];
    
    [self.videoTabButton modifyY:VIEW_TOP(self.photoTabButton)];
    [self.videoTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.photoTabButton), VIEW_HEIGHT(self.photoTabButton))];
    [self.videoTabButton modifyRight:VIEW_LEFT(self.photoTabButton)];
    
    [self.documentTabButton modifyY:VIEW_TOP(self.photoTabButton)];
    [self.documentTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.photoTabButton), VIEW_HEIGHT(self.photoTabButton))];
    [self.documentTabButton modifyX:VIEW_RIGHT(self.photoTabButton)];
    
    [self.videoTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.photoTabButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.documentTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self.takeButton setImage:[UIImage imageNamed:@"takephoto"] forState:UIControlStateNormal];
    self.topContentView.alpha = 1.0;
    self.bottomContentView.alpha = 1.0;
    
    self.cameraButton.hidden = false;
}

-(void) setVideoTabSelected
{
    self.videoTabButton.frame = CGRectMake(0, 6, 50, 30);
    self.videoTabButton.frame = CGRectMake(0, 6, 50, 30);
    [self.videoTabButton fitToHorizontalCenterWithView:self.bottomContentView];
    
    [self.photoTabButton modifyY:VIEW_TOP(self.videoTabButton)];
    [self.photoTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.videoTabButton), VIEW_HEIGHT(self.videoTabButton))];
    [self.photoTabButton modifyX:VIEW_RIGHT(self.videoTabButton)];
    
    [self.documentTabButton modifyY:VIEW_TOP(self.videoTabButton)];
    [self.documentTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.videoTabButton), VIEW_HEIGHT(self.videoTabButton))];
    [self.documentTabButton modifyX:VIEW_RIGHT(self.photoTabButton)];
    
    [self.videoTabButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.photoTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.documentTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self.takeButton setImage:[UIImage imageNamed:@"record_idle"] forState:UIControlStateNormal];
    self.topContentView.alpha = 0.5;
    self.bottomContentView.alpha = 0.5;
    
    self.cameraButton.hidden = false;
}

-(void) setDocumentTabSelected
{
    self.documentTabButton.frame = CGRectMake(0, 6, 50, 30);
    [self.documentTabButton fitToHorizontalCenterWithView:self.bottomContentView];
    
    [self.photoTabButton modifyY:VIEW_TOP(self.documentTabButton)];
    [self.photoTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.documentTabButton), VIEW_HEIGHT(self.documentTabButton))];
    [self.photoTabButton modifyRight:VIEW_LEFT(self.documentTabButton)];
    
    [self.videoTabButton modifyY:VIEW_TOP(self.documentTabButton)];
    [self.videoTabButton modifySize:CGSizeMake(VIEW_WIDTH(self.documentTabButton), VIEW_HEIGHT(self.documentTabButton))];
    [self.videoTabButton modifyRight:VIEW_LEFT(self.photoTabButton)];
    
    [self.videoTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.photoTabButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.documentTabButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    
    [self.takeButton setImage:[UIImage imageNamed:@"takephoto"] forState:UIControlStateNormal];
    self.topContentView.alpha = 1.0;
    self.bottomContentView.alpha = 1.0;
    
    self.cameraButton.hidden = true;
}



- (void)test
{
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage createImageWithColor:[UIColor grayColor]]];
    imageView.frame = self.view.frame;
    [self.view insertSubview:imageView belowSubview:self.topContentView];
    
    [UIView animateWithDuration:0.8 animations:^{
        imageView.alpha = 0;
    } completion:^(BOOL finished) {
        [imageView removeFromSuperview];
    }];

}
-(void)handleSwipeRight:(UISwipeGestureRecognizer *)gesture
{
    if (gesture.direction == UISwipeGestureRecognizerDirectionRight) {
        //NSLog(@"right %f, %f, %f",self.photoTabButton.center.x, self.videoTabButton.center.x, self.bottomContentView.center.x);
        if (self.photoTabButton.center.x == self.bottomContentView.center.x) {
            self.cameraMediaType = kCameraMediaTypeVideo;
            [self test];
            [self setupTabWithAnimated:YES];
            [self reloadCameraConfiguration];
        }else if (self.documentTabButton.center.x == self.bottomContentView.center.x) {
            self.cameraMediaType = kCameraMediaTypePhoto;
            [self test];
            [self setupTabWithAnimated:YES];
            [self reloadCameraConfiguration];
        }
    }
}

-(void)handleSwipeLeft:(UISwipeGestureRecognizer *)gesture
{
    if (gesture.direction == UISwipeGestureRecognizerDirectionLeft)
    {
        if (self.videoTabButton.center.x == self.bottomContentView.center.x) {
            self.cameraMediaType = kCameraMediaTypePhoto;
            [self test];
            [self setupTabWithAnimated:YES];
            [self reloadCameraConfiguration];
        }
        else if (self.photoTabButton.center.x == self.bottomContentView.center.x) {
            self.cameraMediaType = kCameraMediaTypeDocument;
            [self test];
            [self setupTabWithAnimated:YES];
            [self reloadCameraConfiguration];
        }
    }
}

/**
 顶部容器视图
 */
- (UIView *) topContentView
{
    if(!_topContentView)
    {
        _topContentView = [[UIView alloc] init];
        [_topContentView setBackgroundColor:[UIColor blackColor]];
    }
    return _topContentView;
}

/**
 闪光灯
 */
- (UIButton *) torchButton
{
    if (!_torchButton) {
        _torchButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_torchButton setImage:[UIImage imageNamed:@"record_flash_off"] forState:UIControlStateNormal];
    }
    return _torchButton;
}
/**
 前后摄像头切换
 */
- (UIButton *) cameraButton
{
    if (!_cameraButton) {
        _cameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_cameraButton setImage:[UIImage imageNamed:@"record_camera"] forState:UIControlStateNormal];
    }
    return _cameraButton;
}
/**
 录制视频时长显示
 */
- (UILabel *) recordDurationLabel
{
    if (!_recordDurationLabel) {
        _recordDurationLabel = [[UILabel alloc] init];
        _recordDurationLabel.textAlignment = NSTextAlignmentCenter;
        _recordDurationLabel.text = @"00:00:00";
        _recordDurationLabel.textColor = [UIColor whiteColor];
    }
    return _recordDurationLabel;
}
/**
 底部容器视图
 */
- (UIView *) bottomContentView
{
    if (!_bottomContentView) {
        _bottomContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 120)];
        [_bottomContentView setBackgroundColor:[UIColor blackColor]];
    }
    return _bottomContentView;
}
/**
 拍照/录制按钮
 */
- (UIButton *) takeButton
{
    if (!_takeButton) {
        _takeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_takeButton setImage:[UIImage imageNamed:@"record_idle"] forState:UIControlStateNormal];
    }
    return _takeButton;
}

/**
 切换为视屏录制模式
 */
- (UIButton *) videoTabButton
{
    if (!_videoTabButton) {
        _videoTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_videoTabButton setTitle:@"视频" forState:UIControlStateNormal];
        _videoTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    return _videoTabButton;
}

/**
 切换为拍照模式
 */
- (UIButton *) photoTabButton
{
    if (!_photoTabButton) {
        _photoTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_photoTabButton setTitle:@"照片" forState:UIControlStateNormal];
        _photoTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    return _photoTabButton;
}
/**
 切换为拍摄文档模式
 */
- (UIButton *) documentTabButton
{
    if (!_documentTabButton) {
        _documentTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_documentTabButton setTitle:@"文档" forState:UIControlStateNormal];
        _documentTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    return _documentTabButton;
}
/**
 取消按钮
 */
- (UIButton *) cancelButton
{
    if (!_cancelButton) {
        _cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        _cancelButton.titleLabel.font = [UIFont systemFontOfSize:17];
        [_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    return _cancelButton;
}

- (void)captureImageWithCompletionHander:(void(^)(NSString *imageFilePath))completionHandler
{
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) break;
    }
    
    __weak typeof(self) weakSelf = self;
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         
         if (error)
         {
             //dispatch_resume(_captureQueue);
             return;
         }
         
         __block NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"CX_IMAGE_%i.jpeg",(int)[NSDate date].timeIntervalSince1970]];
         
         @autoreleasepool
         {
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
             [imageData writeToFile:filePath atomically:NO];
             
             NSLog(@"=== OK");
             
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                completionHandler(filePath);
                            });
         }
     }];
}

- (void)captureDocumentWithCompletionHander:(void(^)(NSString *imageFilePath))completionHandler
{
    
    //dispatch_suspend(_captureQueue);
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) break;
    }
    
    __weak typeof(self) weakSelf = self;
    
    Rectangle* rectangle = [rectangleCALayer getCurrentRectangle];
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         
         if (error)
         {
             //dispatch_resume(_captureQueue);
             return;
         }
         
         __block NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"CX_PDF_%i.jpeg",(int)[NSDate date].timeIntervalSince1970]];
         
         @autoreleasepool
         {
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
             UIImage* image = [[UIImage alloc] initWithData:imageData];
             
             image = [image fixOrientation:image];
             
             Rectangle *newRectangle = [self rotationRectangle:rectangle];
             
             image = [weakSelf correctPerspectiveForImage:image withFeatures:newRectangle];
             
             //image = [weakSelf confirmedImage:image withFeatures:rectangle];
             
             NSData *jpgData = UIImageJPEGRepresentation(image, 1.0f);
             [jpgData writeToFile:filePath atomically:NO];
             
             NSLog(@"=== OK");
             
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                completionHandler(filePath);
                            });
         }
     }];
}

- (UIImage *)confirmedImage:(UIImage*)sourceImage withFeatures:(Rectangle *)rectangle
{
    
    CGSize imageSize = sourceImage.size;
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    
    float a = imageSize.width / screenSize.width;
    float b = imageSize.height / screenSize.height;
    //float c = MAX(a, b);
    
    cv::Mat img = [sourceImage CVMat];
    
    std::vector<cv::Point2f> corners(4);
    corners[0] = cv::Point2f(rectangle.topLeftX * a, rectangle.topLeftY * b );
    corners[1] = cv::Point2f(rectangle.topRightX * a, rectangle.topRightY * b );
    corners[2] = cv::Point2f(rectangle.bottomLeftX * a, rectangle.bottomLeftY * b );
    corners[3] = cv::Point2f(rectangle.bottomRightX * a, rectangle.bottomRightY * b );
    
    float leftX = MIN(rectangle.topLeftX, rectangle.bottomLeftX);
    float topY = MIN(rectangle.topLeftY, rectangle.topRightY);
    float rightX = MAX(rectangle.topRightX, rectangle.bottomRightX);
    float bottomY = MAX(rectangle.bottomLeftY, rectangle.bottomRightY);
    
    std::vector<cv::Point2f> corners_trans(4);
    corners_trans[0] = cv::Point2f(leftX,topY);
    corners_trans[1] = cv::Point2f(rightX,topY);
    corners_trans[2] = cv::Point2f(leftX,bottomY);
    corners_trans[3] = cv::Point2f(rightX,bottomY);
    
    //    // Assemble a rotated rectangle out of that info
    //    cv::RotatedRect box = minAreaRect(cv::Mat(corners));
    //    std::cout << "Rotated box set to (" << box.boundingRect().x << "," << box.boundingRect().y << ") " << box.size.width << "x" << box.size.height << std::endl;
    //
    ////    cv::Point2f pts[4];
    ////    box.points(pts);
    //
    //    corners_trans[0] = cv::Point(0, 0);
    //    corners_trans[1] = cv::Point(box.boundingRect().width - 1, 0);
    //    corners_trans[2] = cv::Point(0, box.boundingRect().height - 1);
    //    corners_trans[3] = cv::Point(box.boundingRect().width - 1, box.boundingRect().height - 1);
    
    //自由变换 透视变换矩阵3*3
    cv::Mat warp_matrix( 3, 3, CV_32FC1 );
    // 求解变换公式的函数
    cv::Mat warpMatrix = getPerspectiveTransform(corners, corners_trans);
    //cv::Mat rotated;
    
    //cv::RotatedRect box = minAreaRect(cv::Mat(corners_trans));
    cv::Mat outt;
    cv::Size size(std::abs(rightX - leftX), std::abs(bottomY - topY));
    warpPerspective(img, outt, warpMatrix,size, 1, 0, 0);
    
    //cv::warpPerspective(img, quad, warpMatrix, quad.size());
    //warpPerspective(img, rotated, warpMatrix, rotated.size(), cv::INTER_LINEAR, cv::BORDER_CONSTANT);
    
    return [UIImage imageWithCVMat:outt];
    
    /*
     
     // 这里顺利打印出了四个点
     cv::Mat draw = img.clone();
     
     // draw the polygon
     cv::circle(draw,corners[0],5,cv::Scalar(0,0,255),2.5);
     cv::circle(draw,corners[1],5,cv::Scalar(0,0,255),2.5);
     cv::circle(draw,corners[2],5,cv::Scalar(0,0,255),2.5);
     cv::circle(draw,corners[3],5,cv::Scalar(0,0,255),2.5);
     
     return [UIImage imageWithCVMat:draw];
     */
    
}

cv::Point2f RotatePoint(const cv::Point2f& p, float rad)
{
    const float x = std::cos(rad) * p.x - std::sin(rad) * p.y;
    const float y = std::sin(rad) * p.x + std::cos(rad) * p.y;
    
    const cv::Point2f rot_p(x, y);
    return rot_p;
}

cv::Point2f RotatePoint(const cv::Point2f& cen_pt, const cv::Point2f& p, float rad)
{
    const cv::Point2f trans_pt = p - cen_pt;
    const cv::Point2f rot_pt   = RotatePoint(trans_pt, rad);
    const cv::Point2f fin_pt   = rot_pt + cen_pt;
    
    return fin_pt;
}

CGFloat flipHorizontalPointX(float pointX, CGFloat screenWidth) {
    return screenWidth - pointX;
}

-(Rectangle *)rotationRectangle:(Rectangle *)rectangle
{
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat screenWidth = screenSize.width;
    CGFloat screenHeight = screenSize.height;
    
    cv::Point2f center = cv::Point2f((screenWidth / 2), (screenHeight / 2));
    
    cv::Point2f topLeft = RotatePoint(center, cv::Point2f(rectangle.topLeftX, rectangle.topLeftY), M_PI);
    cv::Point2f topRight = RotatePoint(center, cv::Point2f(rectangle.topRightX, rectangle.topRightY), M_PI);
    cv::Point2f bottomLeft = RotatePoint(center, cv::Point2f(rectangle.bottomLeftX, rectangle.bottomLeftY), M_PI);
    cv::Point2f bottomRight = RotatePoint(center, cv::Point2f(rectangle.bottomRightX, rectangle.bottomRightY), M_PI);
    
    Rectangle *newRectangle = [[Rectangle alloc] init];
    newRectangle.topLeftX = flipHorizontalPointX(topLeft.x, screenWidth);
    newRectangle.topLeftY = topLeft.y;
    newRectangle.topRightX = flipHorizontalPointX(topRight.x, screenWidth);
    newRectangle.topRightY = topRight.y;
    newRectangle.bottomLeftX = flipHorizontalPointX(bottomLeft.x, screenWidth);
    newRectangle.bottomLeftY = bottomLeft.y;
    newRectangle.bottomRightX = flipHorizontalPointX(bottomRight.x, screenWidth);
    newRectangle.bottomRightY = bottomRight.y;
    return newRectangle;
}

- (UIImage *)correctPerspectiveForImage:(UIImage *)image withFeatures:(Rectangle *)rectangle
{
    // 定义左上角，右上角，左下角，右下角
    CGPoint tlp, trp, blp, brp;
    
    CGSize imageSize = image.size;
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    float screenRatio = screenSize.width / screenSize.height;
    imageSize.height = imageSize.width / screenRatio;
    
    float a = imageSize.width / screenSize.width;
    float b = imageSize.height / screenSize.height;
    //float c = MAX(a, b);
    
    tlp = CGPointMake(rectangle.topLeftX * a, rectangle.topLeftY * b);
    trp = CGPointMake(rectangle.topRightX * a, rectangle.topRightY * b);
    blp = CGPointMake(rectangle.bottomLeftX * a, rectangle.bottomLeftY * b);
    brp = CGPointMake(rectangle.bottomRightX * a, rectangle.bottomRightY * b);
    
    NSLog(@"LT:%@ RT:%@ LB:%@ RB:%@", NSStringFromCGPoint(tlp),NSStringFromCGPoint(trp),NSStringFromCGPoint(blp),NSStringFromCGPoint(brp));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, image.size.width, image.size.height, 8, 4 * image.size.width, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    [[UIColor blackColor] setFill];
    CGContextFillRect(context, rect);
    
    CGColorRef fillColor = [[UIColor whiteColor] CGColor];
    CGContextSetFillColor(context, CGColorGetComponents(fillColor));
    
    CGContextMoveToPoint(context, tlp.x, tlp.y);
    CGContextAddLineToPoint(context, trp.x, trp.y);
    CGContextAddLineToPoint(context, brp.x, brp.y);
    CGContextAddLineToPoint(context, blp.x, blp.y);
    
    CGContextClosePath(context);
    CGContextClip(context);
    
    CGContextDrawImage(context, rect, image.CGImage);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *newImage = [UIImage imageWithCGImage:imageMasked];
    CGImageRelease(imageMasked);
    
    /* TODO 这里需要优化 需要抠出需要的图片
     调研一下 OpenCV提取轮廓
     float leftX = MIN(rectangle.topLeftX * a, rectangle.bottomLeftX * b);
     float topY = MIN(rectangle.topLeftY * a, rectangle.topRightY * b);
     float rightX = MAX(rectangle.topRightX * a, rectangle.bottomRightX * b);
     float bottomY = MAX(rectangle.bottomLeftY * a, rectangle.bottomRightY * b);
     
     CGImageRef imagRef = CGImageCreateWithImageInRect([image CGImage], CGRectMake(leftX, topY, (rightX - leftX), (bottomY - topY)));
     UIImage* finalImage = [UIImage imageWithCGImage: imagRef];
     CGImageRelease(imagRef);
     */
    
    return newImage;
}

@end
