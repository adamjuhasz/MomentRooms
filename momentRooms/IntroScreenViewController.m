//
//  IntroScreenViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/2/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "IntroScreenViewController.h"
#import "MomentsCloud.h"
#import <pop/POP.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "UIViewController+UIViewController_PushPop.h"
#import "RoomPlate.h"
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "PhotoSelectionViewController.h"
#import <Moment/ListOfMomentFilters.h>

@interface IntroScreenViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, RoomDelegate>
{
    NSMutableArray *verticalPanning;
    CGPoint centerLocation;
    UIScrollView *scroller;
    VBFPopFlatButton *addButton;
    
    int height;
    
    RoomPlate *selectedRoom;
    NSArray *cachedRooms;
}
@end

@implementation IntroScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    verticalPanning = [NSMutableArray array];
    
    height = self.view.bounds.size.height - self.view.bounds.size.width - 1;
    scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-height, self.view.bounds.size.width, height)];
    scroller.scrollEnabled = YES;
    scroller.clipsToBounds = NO;
    //scroller.delegate = self;
    
    [self.view addSubview:scroller];
    
    addButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 60, self.view.bounds.size.height - 60, 33, 33) buttonType:buttonAddType buttonStyle:buttonRoundedStyle animateToInitialState:NO];
    addButton.roundBackgroundColor = [UIColor redColor];
    addButton.hidden = YES;
    [addButton addTarget:self action:@selector(newMoment) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:addButton];
    
    MomentsCloud *singleCloud = [MomentsCloud sharedCloud];
    [[RACObserve(singleCloud, subscribedRooms) filter:^BOOL(NSArray *rooms) {
        if (rooms.count > 0 && selectedRoom == nil) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(NSArray *rooms) {
        cachedRooms = [rooms copy];
        int i=0;
        for (i=0; i<rooms.count; i++) {
            MomentRoom *theRoomModel = rooms[i];
            RoomPlate *aRoom = [[RoomPlate alloc] initWithFrame:CGRectMake((height*9/16+1)*i, 0, height*9/16, height)];
            aRoom.backgroundColor = theRoomModel.backgroundColor;
            aRoom.room = theRoomModel;
            aRoom.delegate = self;
            [scroller addSubview:aRoom];
            
            UIPanGestureRecognizer *panner = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panning:)];
            [aRoom addGestureRecognizer:panner];
            [verticalPanning addObject:panner];
            panner.delegate = self;
        }
        scroller.contentSize = CGSizeMake(height*9/16*i, height);
    }];

}

- (void)panning:(UIPanGestureRecognizer*)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateCancelled:
            NSLog(@"cancelled");
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            NSLog(@"gesture ended");
            //first check velocity
            CGPoint velocity = [recognizer velocityInView:self.view];
            if (fabs(velocity.y) > 20) {
                //negative velocuty is moving towards top of screen
                if (velocity.y < 0) {
                    recognizer.enabled = NO;
                    [self lockInRoom:(RoomPlate*)recognizer.view];
                    
                } else {
                    recognizer.view.center = centerLocation;
                    recognizer.view.bounds = CGRectMake(0, 0, height*9/16, height);
                }
            } else {
                recognizer.view.center = centerLocation;
                recognizer.view.bounds = CGRectMake(0, 0, height*9/16, height);
            }
        }
            break;
            
        case UIGestureRecognizerStateFailed:
            NSLog(@"failed");
            break;
            
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [recognizer translationInView:self.view];
            recognizer.view.center = CGPointMake(centerLocation.x + translation.x, centerLocation.y + translation.y);
            CGPoint centerOfRoomView = [self.view convertPoint:recognizer.view.center fromView:scroller];
            double originaDistance = hypot((self.view.center.x - centerLocation.x), (self.view.center.y - centerLocation.y));
            double currentDistance = hypot((self.view.center.x - centerOfRoomView.x), (self.view.center.y - centerOfRoomView.y));
            double translationDistance = hypot((recognizer.view.center.x - centerLocation.x), (recognizer.view.center.y - centerLocation.y));
            if (centerLocation.y - recognizer.view.center.y < 0) {
                translationDistance *= -1;
            }
            double verticalTransaltionDistance = (centerLocation.y - recognizer.view.center.y);
            CGFloat percent = (translationDistance / originaDistance);
            percent = MIN(percent, 1.0);
            CGFloat scaleH = (self.view.bounds.size.height - height) * percent + height;
            CGFloat scaleW = (self.view.bounds.size.width - height*9/16) * percent + height*9/16;
            recognizer.view.bounds = CGRectMake(0, 0, scaleW, scaleH);
            //NSLog(@"%f %f %@", percent, translationDistance, NSStringFromCGPoint(translation));
        }
            break;
            
        default:
            NSLog(@"other");
            break;
    }
    
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint velocity = [gestureRecognizer velocityInView:self.view];
    if (fabs(velocity.y) > fabs(velocity.x)) {
        UIView *selectedView = gestureRecognizer.view;
        /*
         CGRect frame = [scroller convertRect:selectedView.frame toView:self.view];
         [selectedView removeFromSuperview];
         selectedView.frame = frame;
         [self.view addSubview:selectedView];
         */
        [scroller bringSubviewToFront:selectedView];
        centerLocation = gestureRecognizer.view.center;
        return YES;
    }
    return NO;
}

- (void)lockInRoom:(RoomPlate*)room
{
    selectedRoom = room;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [self setNeedsStatusBarAppearanceUpdate];
    
    [room removeFromSuperview];
    [self.view insertSubview:selectedRoom belowSubview:addButton];
    
    room.bounds = self.view.bounds;
    room.center = self.view.center;
    
    [room showMoments];
    
    addButton.roundBackgroundColor = selectedRoom.room.backgroundColor;
    addButton.tintColor = selectedRoom.contrastColor;
    addButton.hidden = NO;
    
    NSLog(@"%@", room.gestureRecognizers);
}

- (void)minimizeRoom
{
    NSInteger location = [cachedRooms indexOfObject:selectedRoom.room];
    CGRect currentFrameInScroller = [scroller convertRect:selectedRoom.frame fromView:self.view];
    [selectedRoom removeFromSuperview];
    
    [selectedRoom hideMoments];

    CGRect scrollerFrame = CGRectMake((height*9/16+1)*location, 0, height*9/16, height);
    selectedRoom.bounds = CGRectMake(0, 0, currentFrameInScroller.size.width, currentFrameInScroller.size.height);
    selectedRoom.center = CGPointMake(CGRectGetMidX(currentFrameInScroller), CGRectGetMidY(currentFrameInScroller));
    //selectedRoom.bounds = CGRectMake(0, 0, scrollerFrame.size.width, scrollerFrame.size.height);
    //selectedRoom.center = CGPointMake(CGRectGetMidX(scrollerFrame), CGRectGetMidY(scrollerFrame));
    [scroller addSubview:selectedRoom];
    
    POPSpringAnimation *boundAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewBounds];
    //CGRect startBound = CGRectMake(0, 0, currentFrameInScroller.size.width, currentFrameInScroller.size.height);
    //boundAnimation.fromValue = [NSValue valueWithCGRect:startBound];
    boundAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, scrollerFrame.size.width, scrollerFrame.size.height)];
    boundAnimation.springSpeed = 15;
    [selectedRoom pop_addAnimation:boundAnimation forKey:@"bounds"];
    
    POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
    centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(scrollerFrame), CGRectGetMidY(scrollerFrame))];
    centerAnimation.springSpeed = 15;
    [selectedRoom pop_addAnimation:centerAnimation forKey:@"center"];
    
    for (UIGestureRecognizer *recognizer in selectedRoom.gestureRecognizers) {
        recognizer.enabled = YES;
    }
    
    addButton.hidden = YES;
    selectedRoom = nil;
}

- (void)newMoment
{
    PhotoSelectionViewController *photoSelector = [[PhotoSelectionViewController alloc] init];
    [self pushController:photoSelector withSuccess:nil];
    
    [[RACObserve(photoSelector, selectedImage) filter:^BOOL(UIImage *selectedImage) {
        if (selectedImage) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(UIImage *fullsizeImage) {
        [self popController:photoSelector withSuccess:nil];
        
        Moment *newMoment = [[Moment alloc] init];
        newMoment.image = fullsizeImage;
        newMoment.dateCreated = [NSDate date];
        newMoment.timeLifetime = selectedRoom.room.roomLifetime;
        
        NSArray *filterList = ArrayOfAllMomentFilters;
        newMoment.filterName = filterList[arc4random_uniform((unsigned int)(filterList.count))];
        [newMoment.filter randomizeSettings];
        
        [[MomentsCloud sharedCloud] addMoment:newMoment ToRoom:selectedRoom.room];
    }];
}

@end
