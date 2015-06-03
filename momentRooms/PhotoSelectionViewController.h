//
//  PhotoSelectionViewController.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/26/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>

@interface PhotoSelectionViewController : UIViewController

@property MomentRoom *room;
@property UIImage *thumbnailOfSelectedImage;
@property UIImage *selectedImage;

@end
