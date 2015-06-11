//
//  AppDelegate.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IntroScreenViewController.h"
#import "UIViewController+UIViewController_PushPop.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong) IntroScreenViewController *mainViewController;

@end

