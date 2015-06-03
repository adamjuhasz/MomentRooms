//
//  CameraControl.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/26/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "CameraControl.h"
#import <AVFoundation/AVFoundation.h>
#import <FastttCamera/FastttCamera.h>

@interface CameraControl () <FastttCameraDelegate>

@property AVCaptureSession *captureSession;
@property AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property FastttCamera *fastCamera;
@property UIButton *shutterButton;
@end

@implementation CameraControl

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _fastCamera = [FastttCamera new];
    self.fastCamera.interfaceRotatesWithOrientation = NO;
    [self fastttAddChildViewController:self.fastCamera];
    self.fastCamera.delegate = self;
    
    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.shutterButton setImage:[UIImage imageNamed:@"shutter"] forState:UIControlStateNormal];
    [self.shutterButton addTarget:_fastCamera action:@selector(takePicture) forControlEvents:UIControlEventTouchUpInside];
    [self.shutterButton addTarget:self action:@selector(flashCamera) forControlEvents:UIControlEventTouchUpInside];
    self.shutterButton.bounds = CGRectMake(0, 0, 60, 60);
    [self.view addSubview:self.shutterButton];
}

- (void)viewWillLayoutSubviews
{
    self.fastCamera.view.frame = self.view.bounds;
    self.shutterButton.center = CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height- (20 + self.shutterButton.bounds.size.height/2.0));
}

- (void)startCamera
{
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) {
        return;
    }
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    /* captureOutput:didOutputSampleBuffer:fromConnection delegate method !*/
    //[captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    self.captureSession = [[AVCaptureSession alloc] init];
    NSString* preset = 0;
    if (!preset) {
        preset = AVCaptureSessionPresetMedium;
    }
    self.captureSession.sessionPreset = preset;
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    //handle prevLayer
    if (!self.captureVideoPreviewLayer) {
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    //if you want to adjust the previewlayer frame, here!
    self.captureVideoPreviewLayer.frame = self.view.bounds;
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer: self.captureVideoPreviewLayer];
    [self.captureSession startRunning];
}

- (void)flashCamera
{
    UIView *white = [[UIView alloc] initWithFrame:self.view.bounds];
    white.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:white];
}

- (void)cameraController:(id<FastttCameraInterface>)cameraController didFinishCapturingImage:(FastttCapturedImage *)capturedImage;
{
    UIImageView *image = [[UIImageView alloc] initWithFrame:self.view.bounds];
    image.image = capturedImage.rotatedPreviewImage;
    [self.view addSubview:image];
    self.thumbnail = capturedImage.rotatedPreviewImage;
}

- (void)cameraController:(id<FastttCameraInterface>)cameraController didFinishNormalizingCapturedImage:(FastttCapturedImage *)capturedImage;
{
    NSLog(@"%@", capturedImage.scaledImage);
    self.fullsizeImag = capturedImage.scaledImage;
}

@end
