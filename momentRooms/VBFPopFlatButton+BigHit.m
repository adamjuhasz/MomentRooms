//
//  VBFPopFlatButton+BigHit.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "VBFPopFlatButton+BigHit.h"

@implementation VBFPopFlatButton (bigHit)

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGSize buttonSize = self.frame.size;
    CGFloat widthToAdd = (44-buttonSize.width > 0) ? 44-buttonSize.width : 0;
    CGFloat heightToAdd = (44-buttonSize.height > 0) ? 44-buttonSize.height : 0;
    CGRect largerFrame = CGRectMake(0-(widthToAdd/2), 0-(heightToAdd/2), buttonSize.width+widthToAdd, buttonSize.height+heightToAdd);
    return (CGRectContainsPoint(largerFrame, point)) ? self : nil;
}

@end
