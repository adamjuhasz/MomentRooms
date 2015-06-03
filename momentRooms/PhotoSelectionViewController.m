//
//  PhotoSelectionViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/26/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "PhotoSelectionViewController.h"
#import "CameraControl.h"
#import <PhotoManager/PhotoManagerViewController.h>
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "FilterSelectionViewController.h"

@interface PhotoSelectionViewController () <PhotoManagerCollectionDelegate>

@end

@implementation PhotoSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    
    CameraControl *cameraPreview = [[CameraControl alloc] init];
    [cameraPreview willMoveToParentViewController:self];
    [self addChildViewController:cameraPreview];
    cameraPreview.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width);
    [self.view addSubview:cameraPreview.view];
    [cameraPreview didMoveToParentViewController:self];
    
    PhotoManagerViewController *libraryChooser = [[PhotoManagerViewController alloc] init];
    libraryChooser.delegate = self;
    [libraryChooser willMoveToParentViewController:self];
    [self addChildViewController:libraryChooser];
    libraryChooser.view.frame = CGRectMake(0, self.view.bounds.size.width, self.view.bounds.size.width, self.view.bounds.size.height - self.view.bounds.size.width);
    [self.view addSubview:libraryChooser.view];
    [libraryChooser didMoveToParentViewController:self];
    
    VBFPopFlatButton *flatButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(10, 10, 33, 33) buttonType:buttonBackType buttonStyle:buttonPlainStyle animateToInitialState:YES];
    [flatButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flatButton];
    
    [RACObserve(cameraPreview, thumbnail) subscribeNext:^(UIImage *thumbnail) {
        self.thumbnailOfSelectedImage = thumbnail;
    }];
    
    [RACObserve(cameraPreview, fullsizeImag) subscribeNext:^(UIImage *fullsize) {
        self.selectedImage = fullsize;
    }];
}

- (void)goBack
{
    
}

- (void)userDidChooseThumbnail:(UIImage*)thumbnail
{
    self.thumbnailOfSelectedImage = thumbnail;
}

- (void)userDidChooseFullImage:(UIImage*)image atLocation:(CLLocation*)location
{
    self.selectedImage = image;
}

@end
