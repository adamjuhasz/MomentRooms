//
//  ViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "RoomViewController.h"
#import <Moment/Moment.h>
#import "MomentsCloud.h"
#import "PhotoSelectionViewController.h"
#import <pop/POP.h>
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "FilterSelectionViewController.h"
#import <Moment/MomentView.h>
#import "MomentViewModel.h"
#import <ReactiveTableViewBinding/CETableViewBindingHelper.h>
#import <Moment/ListOfMomentFilters.h>

@interface RoomViewController ()
{
    RACSignal *momentsSingle;
    UITableView *roomsTable;
    UINib *nib;
}

@end

@implementation RoomViewController

- (id)init
{
    self = [super init];
    if (self) {
        _momentViewModels = [[CEObservableMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    roomsTable = [[UITableView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:roomsTable];
    nib = [UINib nibWithNibName:@"MomentTableViewCell" bundle:nil];
    
    CGRect buttonFrame = CGRectMake(0, 0, 33, 33);
    buttonFrame.origin = CGPointMake(self.view.bounds.size.width - (buttonFrame.size.width + 20), self.view.bounds.size.height - (buttonFrame.size.height + 20));
    VBFPopFlatButton *flatButton = [[VBFPopFlatButton alloc] initWithFrame:buttonFrame buttonType:buttonAddType buttonStyle:buttonRoundedStyle animateToInitialState:NO];
    [self.view addSubview:flatButton];
    [flatButton addTarget:self action:@selector(getPhoto) forControlEvents:UIControlEventTouchUpInside];
    flatButton.roundBackgroundColor = [UIColor redColor];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[RACObserve(self, myRoom)
      filter:^BOOL(MomentRoom *value) {
          if (value) {
              return YES;
          } else {
              return NO;
          }
      }]
     subscribeNext:^(MomentRoom *room) {
         [CETableViewBindingHelper bindingHelperForTableView:roomsTable
                                                sourceSignal:RACObserve(room, moments)
                                            selectionCommand:nil
                                                templateCell:nib];
     }];
}

- (MomentViewModel*)newModelFrom:(Moment*)moment
{
    MomentViewModel *model = [[MomentViewModel alloc] init];
    model.moment = moment;
    return model;
}

- (void)getPhoto
{
    PhotoSelectionViewController *photoSelector = [[PhotoSelectionViewController alloc] init];
    [self pushController:photoSelector];
    
    [[RACObserve(photoSelector, thumbnailOfSelectedImage) filter:^BOOL(UIImage *image) {
        if (image) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(UIImage *thumbnail) {
        if (thumbnail) {
            FilterSelectionViewController *filterSelection = [[FilterSelectionViewController alloc] init];
            if (filterSelection.editableImage == nil)
            filterSelection.editableImage = thumbnail;
            //[self pushController:filterSelection];
        }
    }];
    
    [[RACObserve(photoSelector, selectedImage) filter:^BOOL(UIImage *image) {
        if (image) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(UIImage *fullSize) {
        //filterSelection.editableImage = thumbnail;
        Moment *newMoment = [[Moment alloc] init];
        newMoment.image = fullSize;
        newMoment.dateCreated = [NSDate date];
        newMoment.timeLifetime = self.myRoom.roomLifetime;
        
        NSArray *filterList = ArrayOfAllMomentFilters;
        newMoment.filterName = filterList[arc4random_uniform((unsigned int)(filterList.count))];
        [newMoment.filter randomizeSettings];
        
        [[MomentsCloud sharedCloud] addMoment:newMoment ToRoom:self.myRoom];
        [self popController:photoSelector withSuccess:nil];
    }];
}

- (void)pushController:(UIViewController*)newController
{
    [newController willMoveToParentViewController:self];
    [self addChildViewController:newController];
    newController.view.center = CGPointMake(self.view.center.y, self.view.center.y + newController.view.bounds.size.height);
    [self.view addSubview:newController.view];
    
    POPBasicAnimation *slideInAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewCenter];
    slideInAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(self.view.center.x, self.view.center.y)];
    slideInAnimation.fromValue = [NSValue valueWithCGPoint:CGPointMake(self.view.center.x, self.view.center.y + newController.view.bounds.size.height)];
    //slideInAnimation.duration = 1.0;
    [newController.view pop_addAnimation:slideInAnimation forKey:@"center"];
    
    [newController didMoveToParentViewController:self];
}

- (void)popController:(UIViewController *)controller withDirection:(UIRectEdge)direction withSuccess:(void (^)(void))success
{
    NSInteger index = [self.childViewControllers indexOfObjectIdenticalTo:controller];
    if (index == NSNotFound) {
        if (success)
            success();
        return;
    }
    
    CGRect exitFrame = CGRectMake(self.view.bounds.size.width, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    switch (direction) {
        case UIRectEdgeLeft:
            exitFrame = CGRectMake(-1*self.view.bounds.size.width, 0, self.view.bounds.size.width, self.view.bounds.size.height);
            break;
            
        default:
            break;
    }
    
    POPBasicAnimation *animation = [controller.view pop_animationForKey:@"frame"];
    if (animation == nil) {
        animation =  [POPBasicAnimation animationWithPropertyNamed:kPOPViewFrame];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        animation.duration = 0.2;
        [controller.view pop_addAnimation:animation forKey:@"frame"];
    }
    animation.toValue = [NSValue valueWithCGRect:exitFrame];
    animation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        [self removeController:controller];
        if(success) {
            success();
        }
    };
}

- (void)popController:(UIViewController*)controller withSuccess:(void (^)(void))success
{
    [self popController:controller withDirection:UIRectEdgeRight withSuccess:success];
}

- (void)removeController:(UIViewController*)controller
{
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
}

@end
