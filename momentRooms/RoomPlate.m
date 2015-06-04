//
//  RoomPlate.m
//  roomNav
//
//  Created by Adam Juhasz on 5/29/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "RoomPlate.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "MomentsViewer.h"
#import <UIColor+ContrastingColor/UIColor+ContrastingColor.h>
#import <VBFPopFlatButton/VBFPopFlatButton.h>

@interface RoomPlate ()
{
    UILabel *text;
    UIView *feed;
    CGFloat height;
    VBFPopFlatButton *minimizeButton;
    MomentsViewer *momentDisplayer;
}
@end

@implementation RoomPlate

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 3.0;
        
        text = [[UILabel alloc] initWithFrame:CGRectMake(0 , 20, frame.size.width, 60)];
        text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:20];
        text.textAlignment = NSTextAlignmentCenter;
        [self addSubview:text];
        
        feed = [[UIView alloc] initWithFrame:self.bounds];
        feed.hidden = YES;
        feed.backgroundColor = [UIColor whiteColor];
        [self addSubview:feed];
        
        minimizeButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(8, 28, 20, 20) buttonType:buttonDownBasicType buttonStyle:buttonPlainStyle animateToInitialState:YES];
        minimizeButton.tintColor = [UIColor whiteColor];
        [minimizeButton addTarget:self.delegate action:@selector(minimizeRoom) forControlEvents:UIControlEventTouchUpInside];
        minimizeButton.hidden = YES;
        [self addSubview:minimizeButton];
        
        [RACObserve(self, room) subscribeNext:^(MomentRoom *newRoom) {
            [RACObserve(newRoom, roomName) subscribeNext:^(NSString *roomName) {
                text.text = roomName;
            }];
            [RACObserve(newRoom, backgroundColor) subscribeNext:^(UIColor *roomBackgroundColor) {
                self.contrastColor = [roomBackgroundColor sqf_contrastingColorWithMethod:SQFContrastingColorYIQMethod];
                self.backgroundColor = roomBackgroundColor;
                text.textColor = self.contrastColor;
                minimizeButton.tintColor = self.contrastColor;
            }];
        }];
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    if (bounds.size.width == 250) {
        height = bounds.size.height;
    }
    if (bounds.size.width > 300) {
        text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:34];
        [text sizeToFit];
        text.bounds = CGRectMake(0, 0, text.bounds.size.width, 44);
        //feed.hidden = NO;
        //feed.frame = CGRectMake(0, height, bounds.size.width, 600);
        self.layer.cornerRadius = 0;
    } else {
        text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:20];
        [text sizeToFit];
        self.layer.cornerRadius = 3.0;
    }
    
    text.center = CGPointMake(bounds.size.width/2.0, 20+text.bounds.size.height/2.0);
}

- (void)showMoments
{
    momentDisplayer = [[MomentsViewer alloc] init];
    momentDisplayer.frame = CGRectMake(0, 64, self.bounds.size.width, self.bounds.size.height-64);
    momentDisplayer.myRoom = self.room;
    [self addSubview:momentDisplayer];
    
    minimizeButton.hidden = NO;
}

- (void)hideMoments
{
    [momentDisplayer removeFromSuperview];
    momentDisplayer = nil;
    
    minimizeButton.hidden = YES;
}

@end
