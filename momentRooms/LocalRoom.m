//
//  LocalRoom.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "LocalRoom.h"

@implementation LocalRoom

- (id)init
{
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor lightGrayColor];
        self.roomName = @"Local";
        self.roomLifetime = 60*60*2;
    }
    return self;
}

@end
