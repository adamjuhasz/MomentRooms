//
//  MomentViewWithRoom.h
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MomentView.h"
#import <Moment/MomentRoom.h>

@protocol MomentViewWithRoomDelegte <NSObject>
@required
- (void)openRoom:(MomentRoom*)theRoom;

@end

@interface MomentViewWithRoom : MomentView

@property UIButton *roomIndicator;
@property (weak) id <MomentViewWithRoomDelegte> delegate;

@end
