//
//  FilterSelectionViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/27/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "FilterSelectionViewController.h"
#import <moment/momentview.h>
#import <moment/EditableMomentView.h>
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "UIImage+ANImageBitmapRep.h"
#import <Moment/ListOfMomentFilters.h>

@interface FilterSelectionViewController ()
{
    UIView *navigationBar;
    EditableMomentView *editingView;
    UIScrollView *filterScrollview;
    NSMutableArray *filteringMomentViews;
    NSTimer *animationTimer;
}
@end

@implementation FilterSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    filteringMomentViews = [NSMutableArray array];
    
    navigationBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 64)];
    navigationBar.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:navigationBar];
    
    VBFPopFlatButton *backButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(10, 25, 33, 33) buttonType:buttonBackType buttonStyle:buttonPlainStyle animateToInitialState:YES];
    [backButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [navigationBar addSubview:backButton];
    
    VBFPopFlatButton *makeButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width-(10+33), 25, 33, 33) buttonType:buttonForwardType buttonStyle:buttonPlainStyle animateToInitialState:YES];
    [makeButton addTarget:self action:@selector(makeMoment) forControlEvents:UIControlEventTouchUpInside];
    [navigationBar addSubview:makeButton];
    
    editingView = [[EditableMomentView alloc] initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, self.view.bounds.size.width)];
    Moment *demo = [[Moment alloc] init];
    demo.filterName = @"none";
    editingView.moment = demo;
    [self.view insertSubview:editingView belowSubview:navigationBar];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    RAC(editingView.moment, image) = RACObserve(self, editableImage);
    [self rac_liftSelector:@selector(setThumbnailTo:) withSignals:RACObserve(editingView, croppedImage), nil];
    [self rac_liftSelector:@selector(setThumbnailTo:) withSignals:RACObserve(self, editableImage), nil];
}

- (void)setThumbnailTo:(UIImage*)image
{
    if (image == nil || CGSizeEqualToSize(image.size, CGSizeZero)) {
        return;
    }
    
    UIImage *thumbnail = [image imageFillingFrame:CGSizeMake(200, 200)];
    for (MomentView *aMomentView in filteringMomentViews) {
        aMomentView.moment.image = thumbnail;
        aMomentView.moment.filter.filterValue = 0.0;
    }
}

- (void)viewWillLayoutSubviews
{
    editingView.frame = CGRectMake(0, 64, self.view.bounds.size.width, self.view.bounds.size.width);
    filterScrollview.frame = CGRectMake(0, self.view.bounds.size.height-96, self.view.bounds.size.width, 96);
    [super viewWillLayoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.room) {
        navigationBar.backgroundColor = self.room.backgroundColor;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.editableImage) {
        editingView.moment.image = self.editableImage;
    }
    
    filterScrollview = [[UIScrollView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-96, self.view.bounds.size.width, 96)];
    filterScrollview.clipsToBounds = YES;
    [self generateFilterViews];
    [self.view addSubview:filterScrollview];
    
    animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateTimers) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [animationTimer invalidate];
    animationTimer = nil;
}

- (void)goBack
{
    [self.delegate popController:self withSuccess:nil];
}

- (void)makeMoment
{
    Moment *aNewMoment = [[Moment alloc] init];
    aNewMoment.filterName = editingView.moment.filterName;
    aNewMoment.filterSettings = editingView.moment.filterSettings;
    if (editingView.croppedImage) {
        aNewMoment.image = [editingView.croppedImage imageFillingFrame:CGSizeMake(736, 736)];
    } else {
        aNewMoment.image = [editingView.moment.image imageFillingFrame:CGSizeMake(736, 736)];
    }
    aNewMoment.dateCreated = [NSDate date];
    aNewMoment.text = @"";
    self.aNewMoment = aNewMoment;
}

- (void)generateFilterViews
{
    NSArray *filterList = ArrayOfAllMomentFilters;
    CGRect filterBounds = CGRectMake(0, 0, filterScrollview.bounds.size.height, filterScrollview.bounds.size.height);
    
    int i=0;
    for (; i<filterList.count; i++) {
        CGRect frame = CGRectOffset(filterBounds, i*(filterBounds.size.width+5), 0);
        MomentView *newMomentView = [[MomentView alloc] initWithFrame:frame];
        newMomentView.touchEnabled = NO;
        Moment *demo = [[Moment alloc] init];
        NSString *filterName = [filterList objectAtIndex:i];
        demo.filterName = filterName;
        //[demo.filter randomizeSettings];
        if (self.editableImage) {
            demo.image = self.editableImage;
        }
        newMomentView.moment = demo;
        [filterScrollview addSubview:newMomentView];
        [filteringMomentViews addObject:newMomentView];
        
        UITapGestureRecognizer *selector = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(userTappedAFilter:)];
        [newMomentView addGestureRecognizer:selector];
        
        UILongPressGestureRecognizer *holdee = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(userIsHoldingDownOnAFilter:)];
        [newMomentView addGestureRecognizer:holdee];
    }
    
    filterScrollview.contentSize = CGSizeMake(filterBounds.size.width * i + 5 * MAX((i-1),0), filterScrollview.bounds.size.height);
}

- (void)userTappedAFilter:(UIGestureRecognizer*)recognizer
{
    MomentView *selectedMomentView = (MomentView*)recognizer.view;
    CGRect filterBounds = CGRectMake(0, 0, filterScrollview.bounds.size.height, filterScrollview.bounds.size.height);
    CGPoint selectedCenter = selectedMomentView.center;
    selectedMomentView.bounds = filterBounds;
    selectedMomentView.center = selectedCenter;
    
    CGRect unusedBounds = CGRectInset(filterBounds, 10, 10);
    
    for (MomentView *aMomentView in filteringMomentViews) {
        if (aMomentView != selectedMomentView) {
            CGPoint center = aMomentView.center;
            aMomentView.bounds = unusedBounds;
            aMomentView.center = center;
        }
    }
    
    editingView.moment.filterName = selectedMomentView.moment.filterName;
    editingView.moment.filterSettings = selectedMomentView.moment.filterSettings;
}

- (void)userIsHoldingDownOnAFilter:(UILongPressGestureRecognizer*)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            MomentView *selectedMomentView = (MomentView*)recognizer.view;
            editingView.editedMoment.filterName = selectedMomentView.moment.filterName;
            editingView.editedMoment.filterSettings = selectedMomentView.moment.filterSettings;
            [editingView startLoopingMoment];
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            [editingView stopLoopingMoment];
            break;
            
        default:
            break;
    }
}
     
- (void)updateTimers
{
    for (MomentView *aMomentView in filteringMomentViews) {
        if (aMomentView.moment.filter.filterValue >= 1.0) {
            aMomentView.moment.filter.filterValue = 0.0;
        } else {
            aMomentView.moment.filter.filterValue += 0.1;
        }
    }
}

@end
