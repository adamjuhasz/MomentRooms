//
//  PhotoSelectionViewController.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/26/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIViewController+UIViewController_PushPop.h"

@interface PhotoSelectionViewController : UIViewController

@property UIImage *thumbnailOfSelectedImage;
@property UIImage *selectedImage;
@property UIViewController *delegate;

@end
