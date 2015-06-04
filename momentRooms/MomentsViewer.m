//
//  ViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "MomentsViewer.h"
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

@interface MomentsViewer ()
{
    RACSignal *momentsSingle;
    UITableView *roomsTable;
    UINib *nib;
}

@end

@implementation MomentsViewer

- (id)init
{
    self = [super init];
    if (self) {
        _momentViewModels = [[CEObservableMutableArray alloc] init];
        roomsTable = [[UITableView alloc] initWithFrame:self.bounds];
        roomsTable.backgroundColor = [UIColor clearColor];
        [self addSubview:roomsTable];
        nib = [UINib nibWithNibName:@"MomentTableViewCell" bundle:nil];
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    roomsTable.frame = self.bounds;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    roomsTable.frame = self.bounds;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
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

@end
