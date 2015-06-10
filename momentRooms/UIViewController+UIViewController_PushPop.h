//
//  UIViewController+UIViewController_PushPop.h
//  momentRooms
//
//  Created by Adam Juhasz on 6/3/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (UIViewController_PushPop)

- (void)pushController:(UIViewController*)controller withSuccess:(void (^)(void))success;
- (void)pushController:(UIViewController*)controller withDirection:(UIRectEdge)direction withSuccess:(void (^)(void))success;
- (void)popController:(UIViewController *)controller withDirection:(UIRectEdge)direction withSuccess:(void (^)(void))success
;
- (void)popController:(UIViewController*)controller withSuccess:(void (^)(void))success;
- (void)popAllControllers;

@end
