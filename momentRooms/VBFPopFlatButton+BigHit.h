//
//  VBFPopFlatButton+BigHit.h
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "VBFPopFlatButton.h"

@interface VBFPopFlatButton (BigHit)
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;
@end
