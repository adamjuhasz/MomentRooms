//
//  RoomPlate.h
//  roomNav
//
//  Created by Adam Juhasz on 5/29/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>

@protocol RoomDelegate <NSObject>
@required
-(void)minimizeRoom;

@end

@interface RoomPlate : UIView

@property UIColor *contrastColor;
@property CGFloat percentGrown;
@property MomentRoom *room;

@property id <RoomDelegate> delegate;

- (void)showMoments;
- (void)hideMoments;

@end
