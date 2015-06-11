//
//  RoomPlate.h
//  roomNav
//
//  Created by Adam Juhasz on 5/29/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>
#import "MomentsViewer.h"
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import <TGPControls/TGPDiscreteSlider.h>
#import <TGPControls/TGPCamelLabels.h>

@protocol RoomDelegate <NSObject>
@required
-(void)minimizeRoom;

@end

@interface RoomPlate : UIView
{
    UITextField *text;
    UIView *feed;
    CGFloat height;
    VBFPopFlatButton *minimizeButton;
    VBFPopFlatButton *shareButton;
    MomentsViewer *momentDisplayer;
    TGPDiscreteSlider *lifetimeSlider;
    TGPCamelLabels *labels;
    UICollectionView *membersOfRoom;
    NSArray *memberList;
}

@property UIColor *contrastColor;
@property CGFloat percentGrown;
@property MomentRoom *room;

@property id <RoomDelegate> delegate;

- (void)showMoments;
- (void)hideMoments;

@end
