//
//  FilterSelectionViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/27/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "FilterSelectionViewController.h"
#import "FXPhotoEditView.h"
#import <moment/momentview.h>
#import <moment/EditableMomentView.h>

@interface FilterSelectionViewController ()
{
    UIView *navigationBar;
    EditableMomentView *editingView;
    UIScrollView *filterScrollview;
    NSMutableArray *filteringMomentViews;
    
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
    
    editingView = [[EditableMomentView alloc] initWithFrame:CGRectMake(0, 64, self.view.bounds.size.width, self.view.bounds.size.width)];
    Moment *demo = [[Moment alloc] init];
    demo.filterName = @"none";
    editingView.moment = demo;
    [self.view insertSubview:editingView belowSubview:navigationBar];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    filterScrollview = [[UIScrollView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height-96, self.view.bounds.size.width, 96)];
    filterScrollview.clipsToBounds = YES;
    //[self generateFilterViews];
    [self.view addSubview:filterScrollview];
    
    [RACObserve(self, editableImage) subscribeNext:^(UIImage *newImage) {
        if (newImage) {
            editingView.moment.image = newImage;
            for (MomentView *aMomentView in filteringMomentViews) {
                aMomentView.moment.image = newImage;
            }
        }
    }];
    
    [RACObserve(editingView, croppedImage) subscribeNext:^(UIImage *croppedImage) {
        if (croppedImage) {
            NSLog(@"new cropped: %@", croppedImage);
            for (MomentView *aMomentView in filteringMomentViews) {
                aMomentView.moment.image = croppedImage;
                aMomentView.moment.filter.filterValue = 0.0;
            }
        }
    }];
    
}

- (void)viewWillLayoutSubviews
{
    editingView.frame = CGRectMake(0, 64, self.view.bounds.size.width, self.view.bounds.size.width);
    filterScrollview.frame = CGRectMake(0, self.view.bounds.size.height-96, self.view.bounds.size.width, 96);
    [super viewWillLayoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
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
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateTimers) userInfo:nil repeats:YES];
}

- (void)generateFilterViews
{
    NSArray *filterList = @[@"faded", @"none", @"leak", @"blockOut", @"swapBlock", @"split"];
    CGRect filterBounds = CGRectMake(0, 0, filterScrollview.bounds.size.height, filterScrollview.bounds.size.height);
    
    int i=0;
    for (; i<filterList.count; i++) {
        CGRect frame = CGRectOffset(filterBounds, i*(filterBounds.size.width+5), 0);
        MomentView *newMomentView = [[MomentView alloc] initWithFrame:frame];
        Moment *demo = [[Moment alloc] init];
        NSString *filterName = [filterList objectAtIndex:i];
        demo.filterName = filterName;
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

- (void)userTappedAFilter:(UITapGestureRecognizer*)tapper
{
    
}

- (void)userIsHoldingDownOnAFilter:(UILongPressGestureRecognizer*)recognizer
{
    
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
