//
//  CreateNewMomentRoom.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "CreateNewMomentRoom.h"

@implementation CreateNewMomentRoom

- (id)init
{
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:216/255.0 green:216/255.0 blue:216/255.0 alpha:1.0];
        self.allowsPosting = NO;
    }
    return self;
}

@end
