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
    
    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.shutterButton setImage:[UIImage imageNamed:@"shutter"] forState:UIControlStateNormal];
    [self.shutterButton addTarget:self action:@selector(flashCamera) forControlEvents:UIControlEventTouchUpInside];
    self.shutterButton.bounds = CGRectMake(0, 0, 60, 60);
    [self.view addSubview:self.shutterButton];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(startCamera) userInfo:nil repeats:NO];
}

- (void)viewWillLayoutSubviews
{
    self.fastCamera.view.frame = self.view.bounds;
    self.shutterButton.center = CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height- (20 + self.shutterButton.bounds.size.height/2.0));
}

- (void)startCamera
{
    self.fastCamera = [FastttCamera new];
    self.fastCamera.interfaceRotatesWithOrientation = NO;
    [self fastttAddChildViewController:self.fastCamera];
    self.fastCamera.delegate = self;
    self.fastCamera.view.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.shutterButton];
    [self.shutterButton addTarget:_fastCamera action:@selector(takePicture) forControlEvents:UIControlEventTouchUpInside];
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
    self.fullsizeImag = capturedImage.fullImage;
}

@end
