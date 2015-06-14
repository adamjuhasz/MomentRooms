//
//  MomentViewWithRoom.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "MomentViewWithRoom.h"
#import "MomentsCloud.h"

@interface MomentViewWithRoom ()
{
    MomentRoom *myRoom;
}
@end

@implementation MomentViewWithRoom

- (void)commonInit
{
    [super commonInit];
    self.roomIndicator = [UIButton buttonWithType:UIButtonTypeCustom];
    self.roomIndicator.bounds = CGRectMake(0, 0, 44, 44);
    [self setCenterOfRoomIndicator];
    self.roomIndicator.layer.cornerRadius = self.roomIndicator.bounds.size.width/2.0;
    self.roomIndicator.clipsToBounds = YES;
    [self addSubview:self.roomIndicator];
    [self.roomIndicator addTarget:self action:@selector(roomIndicatorClicked) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setCenterOfRoomIndicator
{
    self.roomIndicator.center = CGPointMake(self.bounds.size.width - (10 + self.roomIndicator.bounds.size.width/2.0), self.bounds.size.height - (10 + self.roomIndicator.bounds.size.height/2.0));
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self setCenterOfRoomIndicator];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setCenterOfRoomIndicator];
}

- (void)updatedMomentTo:(Moment *)aMoment
{
    [super updatedMomentTo:aMoment];
    myRoom = [[MomentsCloud sharedCloud] getCachedRoomWithID:aMoment.roomId];
    if (myRoom == nil)
        return;
    
    self.roomIndicator.backgroundColor = myRoom.backgroundColor;
    NSString *text = [NSString stringWithFormat:@"%c", [myRoom.roomName characterAtIndex:0]];
    [self.roomIndicator setTitle:text forState:UIControlStateNormal];
}

- (void)roomIndicatorClicked
{
    if (myRoom) {
        [self.delegate openRoom:myRoom];
        [[MomentsCloud sharedCloud] tagEvent:@"Maximize Room" withInformation:[NSDictionary dictionaryWithObjectsAndKeys:@"roomTap", @"source", nil]];
    }
}

@end
