//
//  ViewController.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>
#import <ReactiveTableViewBinding/CEObservableMutableArray.h>

@interface RoomViewController : UIViewController

@property MomentRoom *myRoom;
@property (nonatomic, strong) CEObservableMutableArray *momentViewModels;

@end

