//
//  UserCell.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/10/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "UserCell.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface UserCell ()
{
    
}
@property UIImageView *userImage;

@end

@implementation UserCell

- (id)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.backgroundColor = [UIColor lightGrayColor];
    
    self.userImage = [[UIImageView alloc] initWithFrame:self.bounds];
    self.userImage.contentMode = UIViewContentModeScaleAspectFill;
    [self addSubview:self.userImage];
    
    self.layer.cornerRadius = self.bounds.size.width/2.0;
    self.clipsToBounds = YES;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    self.userImage.frame = bounds;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.userImage.frame = self.bounds;
}

- (void)setUser:(MomentUser *)user
{
    RAC(self.userImage, image) = RACObserve(user, image);
}

- (MomentUser*)user
{
    return nil;
}

@end
