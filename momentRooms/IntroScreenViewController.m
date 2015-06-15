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
#import "LocalRoomPlate.h"
#import <Tweaks/FBTweak.h>
#import <Tweaks/FBTweakInline.h>

@interface IntroScreenViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, RoomDelegate, RecentMomentsDelegate, FBTweakObserver>
{
    NSMutableArray *verticalPanning;
    CGPoint centerLocation;
    UIScrollView *scroller;
    VBFPopFlatButton *addButton;
    
    int height;
    
    RoomPlate *selectedRoom;
    NSMutableArray *cachedRooms;
    NSMutableArray *cachedRoomPlates;
}

@property CGFloat inset;
@property CGFloat tracking;

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
    
    height = self.view.bounds.size.height - CGRectGetMaxY(momentViewer.frame);
    scroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(momentViewer.frame), self.view.bounds.size.width, height)];
    scroller.scrollEnabled = YES;
    scroller.clipsToBounds = NO;
    //scroller.delegate = self;
    
    [self.view addSubview:scroller];
    
    addButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 60, self.view.bounds.size.height - 60, 33, 33) buttonType:buttonAddType buttonStyle:buttonRoundedStyle animateToInitialState:NO];
    addButton.roundBackgroundColor = [UIColor redColor];
    [addButton addTarget:self action:@selector(newMoment) forControlEvents:UIControlEventTouchUpInside];
    //[self.view addSubview:addButton];
    
    FBTweak *insetTweak = [[FBTweak alloc] initWithIdentifier:@"main.rooms.inset"];
    insetTweak.name = @"inset";
    insetTweak.defaultValue = @(3.0);
    insetTweak.minimumValue = @(0.0);
    insetTweak.maximumValue = @(20.0);
    insetTweak.stepValue = @(1.0);
    [insetTweak addObserver:self];
    
    FBTweak *trackingTweak = [[FBTweak alloc] initWithIdentifier:@"main.rooms.tracking"];
    trackingTweak.name = @"tracking";
    trackingTweak.defaultValue = @([insetTweak.defaultValue floatValue] * -1);
    trackingTweak.minimumValue = @([insetTweak.maximumValue floatValue] * -1);
    trackingTweak.maximumValue = @(0);
    trackingTweak.stepValue = insetTweak.stepValue;
    [trackingTweak addObserver:self];
    
    FBTweakStore *store = [FBTweakStore sharedInstance];
    
    FBTweakCategory *introCategory = [[FBTweakCategory alloc] initWithName:@"Main Screen"];
    [store addTweakCategory:introCategory];
    
    FBTweakCollection *roomsCollection = [[FBTweakCollection alloc] initWithName:@"Rooms"];
    [introCategory addTweakCollection:roomsCollection];
    
    [roomsCollection addTweak:insetTweak];
    [roomsCollection addTweak:trackingTweak];
    
    self.inset = [insetTweak.defaultValue floatValue];
    self.tracking = [trackingTweak.defaultValue floatValue];
    
    [self rac_liftSelector:@selector(generatePlates:) withSignals:[[RACObserve(singleCloud, subscribedRooms) throttle:0.5] filter:^BOOL(NSArray *rooms) {
        if (rooms != nil && rooms.count > 0 && selectedRoom == nil) {
            return YES;
        } else {
            return NO;
        }
    }], nil];
    
    [self rac_liftSelector:@selector(generatePlates:) withSignals:RACObserve(self, inset), nil];
    [self rac_liftSelector:@selector(generatePlates:) withSignals:RACObserve(self, tracking), nil];
}

- (void)tweakDidChange:(FBTweak *)tweak
{
    if ([tweak.identifier isEqualToString:@"main.rooms.inset"]) {
        self.inset = [tweak.currentValue floatValue];
        
        /*
        FBTweakStore *store = [FBTweakStore sharedInstance];
        FBTweakCategory *mainScreen = [store tweakCategoryWithName:@"Main Screen"];
        FBTweakCollection *rooms = [mainScreen tweakCollectionWithName:@"Rooms"];
        FBTweak *tracking = [rooms tweakWithIdentifier:@"main.rooms.tracking"];
        tracking.currentValue = @([tweak.currentValue floatValue] * -1);
        */
    }
    if ([tweak.identifier isEqualToString:@"main.rooms.tracking"]) {
        self.tracking = [tweak.currentValue floatValue];
    }
}

- (void)generatePlates:(id)changer
{
    cachedRooms = [[[MomentsCloud sharedCloud] subscribedRooms] mutableCopy];
    
    [verticalPanning removeAllObjects];
    for (UIView *aView in cachedRoomPlates) {
        [aView removeFromSuperview];
    }
    [cachedRoomPlates removeAllObjects];
    
    int i=0;
    int constantRooms=0;
    
    CreateARoomPlate *createARoom = [[CreateARoomPlate alloc] initWithFrame:CGRectMake(0, 0, [self sizeOfMininimzedRoom].width, [self sizeOfMininimzedRoom].height)];
    CreateNewMomentRoom *createNewMomentRoom = [[CreateNewMomentRoom alloc] init];
    [cachedRooms insertObject:createARoom atIndex:i];
    [self setupPlate:createARoom withRoom:createNewMomentRoom intoPosition:i];
    constantRooms++;
    i++;
    
    /*
     LocalRoomPlate *localPlate = [[LocalRoomPlate alloc] initWithFrame:CGRectMake(0, 0, height*9/16, height)];
     LocalRoom *localRoom = [[LocalRoom alloc] init];
     [cachedRooms insertObject:localRoom atIndex:i];
     [self setupPlate:localPlate withRoom:localRoom intoPosition:i];
     constantRooms++;
     i++;
     */
    
    for (; i<cachedRooms.count; i++) {
        MomentRoom *theRoomModel = cachedRooms[i];
        RoomPlate *aRoom = [[RoomPlate alloc] initWithFrame:CGRectMake(0, 0, height*9/16, height)];
        [self setupPlate:aRoom withRoom:theRoomModel intoPosition:i];
    }
    
    scroller.contentSize = CGSizeMake(CGRectGetMaxX([[cachedRoomPlates lastObject] frame]) + self.inset, height);
}

- (CGSize)sizeOfMininimzedRoom
{
    return CGSizeMake(height*9/16, height);
}

- (CGRect)frameOfMinimzedRoomAt:(NSInteger)i
{
    CGSize minimizedRoomSize = [self sizeOfMininimzedRoom];
    CGRect frameOfPlate = CGRectMake(minimizedRoomSize.width*i, 0, minimizedRoomSize.width, minimizedRoomSize.height);
    frameOfPlate = CGRectInset(frameOfPlate, self.inset, self.inset);
    frameOfPlate.origin.x += i*self.tracking;
    return frameOfPlate;
}

- (void)setupPlate:(RoomPlate*)plate withRoom:(MomentRoom*)room intoPosition:(NSInteger)i
{
    plate.frame = [self frameOfMinimzedRoomAt:i];
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
    [self maximizeRoom:(RoomPlate*)recognizer.view];
    [[MomentsCloud sharedCloud] tagEvent:@"Maximize Room" withInformation:[NSDictionary dictionaryWithObjectsAndKeys:@"tap", @"source", nil]];
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
                    [[MomentsCloud sharedCloud] tagEvent:@"Maximize Room" withInformation:[NSDictionary dictionaryWithObjectsAndKeys:@"gesture", @"source", nil]];
                    [self maximizeRoom:(RoomPlate*)recognizer.view];
                } else {
                    [self minimizeAPlate:(RoomPlate*)recognizer.view toLocation:[cachedRoomPlates indexOfObject:recognizer.view] withVelocity:velocity];
                }
            } else {
                [self minimizeAPlate:(RoomPlate*)recognizer.view toLocation:[cachedRoomPlates indexOfObject:recognizer.view] withVelocity:velocity];
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
            [self maximizeRoom:plate];
            break;
        }
    }
}

- (void)maximizeRoom:(RoomPlate*)room
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
    [self.view addSubview:selectedRoom];
    
    [room willMaximizeRoom];
    
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

    [room didMaximizeRoom];
    
    if (selectedRoom.room.allowsPosting) {
        addButton.roundBackgroundColor = selectedRoom.room.backgroundColor;
        addButton.tintColor = selectedRoom.contrastColor;
        [self.view insertSubview:addButton aboveSubview:selectedRoom];
    }
}

- (void)minimizeRoom
{
    NSInteger location = [cachedRooms indexOfObject:selectedRoom.room];
    if (location == NSNotFound) {
        location = 0;
    }
    CGRect currentFrameInScroller = [scroller convertRect:selectedRoom.frame fromView:self.view];
    [selectedRoom removeFromSuperview];
    
    selectedRoom.bounds = CGRectMake(0, 0, currentFrameInScroller.size.width, currentFrameInScroller.size.height);
    selectedRoom.center = CGPointMake(CGRectGetMidX(currentFrameInScroller), CGRectGetMidY(currentFrameInScroller));
    [scroller addSubview:selectedRoom];
    
    [self minimizeAPlate:selectedRoom toLocation:location withVelocity:CGPointMake(0, 0)];
    
    for (UIGestureRecognizer *recognizer in selectedRoom.gestureRecognizers) {
        recognizer.enabled = YES;
    }
    
    [addButton removeFromSuperview];
    selectedRoom = nil;
    
    [[MomentsCloud sharedCloud] tagEvent:@"Minimize Room" withInformation:nil];
}

-(void)minimizeAPlate:(RoomPlate*)plate toLocation:(NSInteger)location withVelocity:(CGPoint)veloctity;
{
    [plate willMinimizeRoom];
    
    CGRect scrollerFrame = [self frameOfMinimzedRoomAt:location];
    
    POPSpringAnimation *boundAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewBounds];
    boundAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, CGRectGetWidth(scrollerFrame), CGRectGetHeight(scrollerFrame))];
    boundAnimation.springSpeed = 15;
    [plate pop_addAnimation:boundAnimation forKey:@"bounds"];
    
    POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
    centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(scrollerFrame), CGRectGetMidY(scrollerFrame))];
    centerAnimation.springSpeed = 15;
    centerAnimation.velocity = [NSValue valueWithCGPoint:veloctity];
    [plate pop_addAnimation:centerAnimation forKey:@"center"];

    [plate didMinimizeRoom];
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
