//
//  CreateARoomPlate.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/4/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "CreateARoomPlate.h"
#import "MomentsCloud.h"
#import "ANImageBitmapRep/ANImageBitmapRep.h"
#import "VBFPopFlatButton+BigHit.h"
#import "PhotoSelectionViewController.h"
#import "AppDelegate.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <NYXImagesKit/NYXImagesKit.h>

@interface CreateARoomPlate () <UITextFieldDelegate>
{
    UIImageView *gradient;
    ANImageBitmapRep *bitmapRep;
    RACSignal *createActiveSignal;
    UIButton *chooseButton;
}
@end
@implementation CreateARoomPlate

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        shareButton.currentButtonType = buttonAddType;
        text.layer.borderColor = self.contrastColor.CGColor;
        text.layer.borderWidth=0.0;
        text.userInteractionEnabled = YES;
        text.placeholder = @"New room name";
        text.delegate = self;
        
        UIImage *gradientImage = [UIImage imageNamed:@"gradient.png"];
        bitmapRep = [[ANImageBitmapRep alloc] initWithImage:gradientImage];
        gradient = [[UIImageView alloc] initWithImage:gradientImage];
        gradient.layer.borderColor = [[UIColor blackColor] CGColor];
        gradient.layer.borderWidth = 1.0;
        gradient.hidden = YES;
        [self addSubview:gradient];
        
        UIPanGestureRecognizer *panning = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(isPanning:)];
        [gradient addGestureRecognizer:panning];
        gradient.userInteractionEnabled = YES;
        
        chooseButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
        chooseButton.center = CGPointMake(self.bounds.size.width/2.0, 150);
        [chooseButton setTitle:@"Choose background photo" forState:UIControlStateNormal];
        [chooseButton addTarget:self action:@selector(selectAPhoto) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:chooseButton];
        
        __weak CreateARoomPlate *weakSelf = self;
        [RACObserve(weakSelf, contrastColor) subscribeNext:^(UIColor *contrast) {
            text.layer.borderColor = contrast.CGColor;
        }];
        
        RACSignal *validRoomName = [text.rac_textSignal
                                          map:^id(NSString *roomname) {
                                              return @(roomname.length > 2);
                                          }];
        
        createActiveSignal = [RACSignal combineLatest:@[validRoomName]
                                                          reduce:^id(NSNumber *isValid) {
                                                              return @([isValid boolValue]);
                                                          }];
        
        [createActiveSignal subscribeNext:^(NSNumber *isValid) {
            //allow saving
            if ([isValid boolValue] == YES) {
                [shareButton animateToType:buttonAddType];
                shareButton.enabled = YES;
            } else {
                [shareButton animateToType:buttonDefaultType];
                shareButton.enabled = YES;
            }
        }];
        shareButton.currentButtonType = buttonDefaultType;
        
        [self hideMoments];
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    text.bounds = CGRectMake(0, 0, bounds.size.width - 80, 40);
    text.center = CGPointMake(bounds.size.width/2.0, 20+text.bounds.size.height/2.0);

    gradient.bounds = CGRectMake(0, 0, bounds.size.width-80, 44);
    gradient.center = CGPointMake(bounds.size.width/2.0, 150+gradient.bounds.size.height/2.0);
    [bitmapRep setSize:BMPointMake(gradient.bounds.size.width, gradient.bounds.size.height)];
    
    chooseButton.center = CGPointMake(self.bounds.size.width/2.0, 300);
}

- (void)showMoments
{
    minimizeButton.hidden = NO;
    shareButton.hidden = NO;
    lifetimeSlider.hidden = NO;
    labels.hidden = NO;
    gradient.hidden = NO;
    text.hidden = NO;
    
    text.layer.borderWidth=1.0;
    
    [text becomeFirstResponder];
    chooseButton.hidden = NO;
}

- (void)hideMoments
{
    text.text = @"";
    text.layer.borderWidth=0.0;
    minimizeButton.hidden = YES;
    shareButton.hidden = YES;
    lifetimeSlider.hidden = YES;
    labels.hidden = YES;
    gradient.hidden = YES;
    text.hidden = YES;
    chooseButton.hidden = YES;
}

- (void)share
{
    //save
    MomentRoom *newRoom = [[MomentRoom alloc] init];
    newRoom.roomName = text.text;
    switch ((int)lifetimeSlider.value) {
        default:
        case 0:
            newRoom.roomLifetime = 60*60;
            break;
        case 1:
            newRoom.roomLifetime = 2*60*60;
            break;
        case 2:
            newRoom.roomLifetime = 4*60*60;
            break;
        case 3:
            newRoom.roomLifetime = 24*60*60;
            break;
        case 4:
            newRoom.roomLifetime = 2*24*60*60;
            break;
        case 5:
            newRoom.roomLifetime = 4*24*60*60;
            break;
        case 6:
            newRoom.roomLifetime = 7*24*60*60;
            break;
        case 7:
            newRoom.roomLifetime = 2*7*24*60*60;
            break;
    }
    newRoom.backgroundColor = self.room.backgroundColor;
    newRoom.backgroundImage = self.room.backgroundImage;
    [[MomentsCloud sharedCloud] createRoom:newRoom];
    [self.delegate minimizeRoom];
}

- (void)isPanning:(UIPanGestureRecognizer*)panner
{
    CGPoint point = [panner locationInView:gradient];
    CGFloat verticalDilation = point.y;
    point.x = floor(point.x);
    point.y = floor(point.y);
    if (CGRectContainsPoint(gradient.bounds, point)) {
        BMPoint size = bitmapRep.bitmapSize;
        NSLog(@"%@ inside {%ld, %ld}", NSStringFromCGPoint(point), size.x, size.y);
        BMPixel pixel = [bitmapRep getPixelAtPoint:BMPointFromPoint(point)];
        self.room.backgroundColor = UIColorFromBMPixel(pixel);
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [text resignFirstResponder];
    return YES;
}

- (void)selectAPhoto
{
    [text resignFirstResponder];
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    IntroScreenViewController *mainController = appDelegate.mainViewController;
    
    PhotoSelectionViewController *photoSelector = [[PhotoSelectionViewController alloc] init];
    photoSelector.delegate = mainController;
    
    [appDelegate.mainViewController pushController:photoSelector withSuccess:nil];
    RACDisposable *observer = [[RACObserve(photoSelector, selectedImage) filter:^BOOL(id value) {
        return (value != nil);
    }] subscribeNext:^(UIImage *fullsizeImage) {
        [mainController popAllControllers];
        self.room.backgroundImage = [fullsizeImage grayscale];
    }];
}

@end
