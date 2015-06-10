//
//  IntroScreenViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/2/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "IntroScreenViewController.h"
#import "MomentsCloud.h"
#import <Moment/MomentView.h>
#import <pop/POP.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "UIViewController+UIViewController_PushPop.h"
#import "RoomPlate.h"
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "PhotoSelectionViewController.h"
#import <Moment/ListOfMomentFilters.h>
#import "CreateARoomPlate.h"
#import "UIImage+ANImageBitmapRep.h"
#import "RecentMomentsView.h"
#import "FilterSelectionViewController.h"

@interface IntroScreenViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, RoomDelegate, RecentMomentsDelegate>
{
    NSMutableArray *verticalPanning;
    CGPoint centerLocation;
    UIScrollView *scroller;
    VBFPopFlatButton *addButton;
    
    int height;
    
    RoomPlate *selectedRoom;
    NSArray *cachedRooms;
    NSMutableArray *cachedRoomPlates;
}
@end

@implementation IntroScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    MomentsCloud *singleCloud = [MomentsCloud sharedCloud];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    verticalPanning = [NSMutableArray array];
    cachedRoomPlates = [NSMutableArray array];
    
    RecentMomentsView *momentViewer = [[RecentMomentsView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width)];
    momentViewer.delegate = self;
    [self.view addSubview:momentViewer];
    
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
    
    
    [[RACObserve(singleCloud, subscribedRooms) filter:^BOOL(NSArray *rooms) {
        if (rooms != nil && rooms.count > 0 && selectedRoom == nil) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(NSArray *rooms) {
        cachedRooms = [rooms copy];
        [verticalPanning removeAllObjects];
        for (UIView *aView in cachedRoomPlates) {
            [aView removeFromSuperview];
        }
        [cachedRoomPlates removeAllObjects];
        
        int i=0;
        CreateARoomPlate *createARoom = [[CreateARoomPlate alloc] initWithFrame:CGRectMake((height*9/16+1)*i, 0, height*9/16, height)];
        MomentRoom *createARoomTemplate = [[MomentRoom alloc] init];
        createARoomTemplate.backgroundColor = [UIColor grayColor];
        [self setupPlate:createARoom withRoom:createARoomTemplate intoPosition:0];
 
        for (i=1; i<rooms.count+1; i++) {
            MomentRoom *theRoomModel = rooms[i-1];
            RoomPlate *aRoom = [[RoomPlate alloc] initWithFrame:CGRectMake((height*9/16+1)*i, 0, height*9/16, height)];
            [self setupPlate:aRoom withRoom:theRoomModel intoPosition:i];
        }
        scroller.contentSize = CGSizeMake(height*9/16*i, height);
    }];

}

- (void)setupPlate:(RoomPlate*)plate withRoom:(MomentRoom*)room intoPosition:(NSInteger)i
{
    plate.frame = CGRectMake((height*9/16+1)*i, 0, height*9/16, height);
    plate.room = room;
    plate.delegate = self;
    [scroller addSubview:plate];
    [cachedRoomPlates addObject:plate];
    
    UIPanGestureRecognizer *panner = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panning:)];
    [plate addGestureRecognizer:panner];
    [verticalPanning addObject:panner];
    panner.delegate = self;
    
    UITapGestureRecognizer *tapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapping:)];
    [plate addGestureRecognizer:tapper];
}

- (void)tapping:(UITapGestureRecognizer*)recognizer
{
    [self lockInRoom:(RoomPlate*)recognizer.view];
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

- (void)openRoom:(MomentRoom *)theRoom
{
    for (RoomPlate *plate in cachedRoomPlates) {
        if (plate.room.roomid == nil || [plate.room.roomid isEqualToString:@""]) {
            continue;
        }
        if ([plate.room.roomid isEqualToString:theRoom.roomid]) {
            [self lockInRoom:plate];
            break;
        }
    }
}

- (void)lockInRoom:(RoomPlate*)room
{
    selectedRoom = room;
    [[MomentsCloud sharedCloud] getCachedMomentsForRoom:room.room WithCompletionBlock:nil];
    
    CGRect frameInController = [self.view convertRect:selectedRoom.frame fromView:scroller];
    
    UIPanGestureRecognizer *panner;
    for (UIGestureRecognizer *recognizer in selectedRoom.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            panner = (UIPanGestureRecognizer*)recognizer;
        }
        recognizer.enabled = NO;
    }
    
    [room removeFromSuperview];
    room.bounds = CGRectMake(0, 0, frameInController.size.width, frameInController.size.height);
    room.center = CGPointMake(CGRectGetMidX(frameInController), CGRectGetMidY(frameInController));
    [self.view insertSubview:selectedRoom belowSubview:addButton];
    
    POPSpringAnimation *boundAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewBounds];
    boundAnimation.toValue = [NSValue valueWithCGRect:self.view.bounds];
    boundAnimation.springSpeed = 15;
    if (panner) {
        CGRect velocity = CGRectZero;
        CGPoint velocityInView = [panner velocityInView:self.view];
        velocity.size.width = velocityInView.x,
        velocity.size.height = velocityInView.y;
        boundAnimation.velocity = [NSValue valueWithCGRect:velocity];
    }
    [selectedRoom pop_addAnimation:boundAnimation forKey:@"bounds"];
    
    POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
    centerAnimation.toValue = [NSValue valueWithCGPoint:self.view.center];
    centerAnimation.springSpeed = 15;
    if (panner) {
        centerAnimation.velocity = [NSValue valueWithCGPoint:[panner velocityInView:self.view]];
    }
    [selectedRoom pop_addAnimation:centerAnimation forKey:@"center"];

    
    [room showMoments];
    
    addButton.roundBackgroundColor = selectedRoom.room.backgroundColor;
    addButton.tintColor = selectedRoom.contrastColor;
    addButton.hidden = NO;
}

- (void)minimizeRoom
{
    NSInteger location = [cachedRooms indexOfObject:selectedRoom.room];
    if (location == NSNotFound) {
        location = 0;
    } else {
        location++;
    }
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
    photoSelector.delegate = self;
    [self pushController:photoSelector withSuccess:nil];
    
    FilterSelectionViewController *filterSelector = [[FilterSelectionViewController alloc] init];
    filterSelector.delegate = self;
    filterSelector.room = selectedRoom.room;
    
    [[RACObserve(photoSelector, thumbnailOfSelectedImage) filter:^BOOL(id value) {
        return (value != nil);
    }] subscribeNext:^(UIImage *thumbnail) {
        [self pushController:filterSelector withSuccess:nil];
    } completed:^{
        NSLog(@"RAC: Completed RACObserve on photoSelector");
    }];
    
    [[RACObserve(photoSelector, selectedImage) filter:^BOOL(UIImage *selectedImage) {
        return (selectedImage != nil);
    }] subscribeNext:^(UIImage *fullsizeImage) {
        filterSelector.editableImage = fullsizeImage;
    }];
    
    [[RACObserve(filterSelector, aNewMoment) filter:^BOOL(Moment *aNewMoment) {
        return (aNewMoment != nil);
    }] subscribeNext:^(Moment *theNewMoment) {
        [[MomentsCloud sharedCloud] addMoment:theNewMoment ToRoom:selectedRoom.room];
        [self popAllControllers];
    } completed:^{
        NSLog(@"RAC: Completed RACObserve on filterSelector");
    }];
}

@end
