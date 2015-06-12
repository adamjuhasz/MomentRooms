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
    id _delegate;
    CETableViewBindingHelper *helper;
}

@end

@implementation MomentsViewer

- (id)init
{
    self = [super init];
    if (self) {
        _momentViewModels = [[CEObservableMutableArray alloc] init];
        roomsTable = [[UITableView alloc] initWithFrame:self.bounds];
        roomsTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        roomsTable.backgroundColor = [UIColor clearColor];
        [roomsTable setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        roomsTable.alwaysBounceVertical = YES;
        [self addSubview:roomsTable];
        nib = [UINib nibWithNibName:@"MomentTableViewCell" bundle:nil];
        
        [[RACObserve(self, myRoom)
          filter:^BOOL(MomentRoom *value) {
              if (value) {
                  return YES;
              } else {
                  return NO;
              }
          }]
         subscribeNext:^(MomentRoom *room) {
             helper = [CETableViewBindingHelper bindingHelperForTableView:roomsTable
                                                             sourceSignal:RACObserve(room, moments)
                                                         selectionCommand:nil
                                                             templateCell:nib];
             roomsTable.rowHeight = self.bounds.size.width;
         }];
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    roomsTable.frame = self.bounds;
    roomsTable.rowHeight = self.bounds.size.width;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    roomsTable.frame = self.bounds;
    roomsTable.rowHeight = self.bounds.size.width;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
}

- (void)setTableDelegate:(id<UITableViewDelegate>)tableDelegate
{
    helper.delegate = tableDelegate;
}

- (id<UITableViewDelegate>)tableDelegate
{
    return helper.delegate;
}

@end
