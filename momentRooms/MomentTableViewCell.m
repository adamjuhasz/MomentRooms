//
//  MomentTableViewCell.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/2/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "MomentTableViewCell.h"
#import <Moment/MomentView.h>
#import "MomentViewModel.h"

@interface MomentTableViewCell ()

@property (weak, nonatomic) IBOutlet MomentView *monetDisplay;

@end

@implementation MomentTableViewCell

- (void)bindViewModel:(id)viewModel
{
    Moment *momentModel = (Moment*)viewModel;
    
    self.monetDisplay.moment = momentModel;
}

@end
