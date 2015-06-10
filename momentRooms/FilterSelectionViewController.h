//
//  FilterSelectionViewController.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/27/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>
#import <Moment/Moment.h>
#import "UIViewController+UIViewController_PushPop.h"

@interface FilterSelectionViewController : UIViewController

@property MomentRoom *room;
@property UIImage *editableImage;
@property Moment *aNewMoment;
@property UIViewController *delegate;

@end
