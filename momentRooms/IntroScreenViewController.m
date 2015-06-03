//
//  IntroScreenViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/2/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "IntroScreenViewController.h"
#import "RoomViewController.h"
#import "MomentsCloud.h"
#import <pop/POP.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "UIViewController+UIViewController_PushPop.h"

@interface IntroScreenViewController ()

@end

@implementation IntroScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    RoomViewController *selectedRoomDiplay = [[RoomViewController alloc] init];
    
    MomentsCloud *singleCloud = [MomentsCloud sharedCloud];
    [[RACObserve(singleCloud, subscribedRooms) filter:^BOOL(NSArray *rooms) {
        if (rooms.count > 0 && selectedRoomDiplay.parentViewController == nil) {
            return YES;
        } else {
            return NO;
        }
    }] subscribeNext:^(NSArray *rooms) {
        NSUInteger randomRoomNumber = arc4random_uniform((unsigned int)rooms.count);
        MomentRoom *selectedRoom = [rooms objectAtIndex:randomRoomNumber];
        NSArray *moments = [[MomentsCloud sharedCloud] cachedMomentsForRoom:selectedRoom];
        selectedRoomDiplay.myRoom = selectedRoom;
        NSLog(@"There are %d moments in \"%@\"", moments.count, selectedRoom.roomName);
        [self pushController:selectedRoomDiplay withSuccess:nil];
    }];
    
    
}

@end
