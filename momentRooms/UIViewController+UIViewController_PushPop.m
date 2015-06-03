//
//  UIViewController+UIViewController_PushPop.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/3/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "UIViewController+UIViewController_PushPop.h"
#import <pop/POP.h>

@implementation UIViewController (UIViewController_PushPop)

- (void)pushController:(UIViewController*)controller withSuccess:(void (^)(void))success
{
    [self pushController:controller withDirection:UIRectEdgeRight withSuccess:success];
}

- (void)pushController:(UIViewController*)controller withDirection:(UIRectEdge)direction withSuccess:(void (^)(void))success
{
    CGRect initialFrame = CGRectMake(self.view.bounds.size.width, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    switch (direction) {
        case UIRectEdgeBottom:
            initialFrame = CGRectMake(0, self.view.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height);
            break;
            
        default:
            break;
    }
    
    [self addChildViewController:controller];
    [self.view addSubview:controller.view];
    
    controller.view.frame = initialFrame;
    
    POPBasicAnimation *animation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewFrame];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    animation.fromValue = [NSValue valueWithCGRect:initialFrame];
    animation.duration = 0.4;
    animation.toValue = [NSValue valueWithCGRect:self.view.bounds];
    animation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller didMoveToParentViewController:self];
            if(success) {
                success();
            }
        });
    };
    
    [controller.view pop_addAnimation:animation forKey:@"frame"];
}

- (void)popController:(UIViewController *)controller withDirection:(UIRectEdge)direction withSuccess:(void (^)(void))success
{
    NSInteger index = [self.childViewControllers indexOfObjectIdenticalTo:controller];
    if (index == NSNotFound) {
        if (success)
            success();
        return;
    }
    
    CGRect exitFrame = CGRectMake(self.view.bounds.size.width, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    switch (direction) {
        case UIRectEdgeLeft:
            exitFrame = CGRectMake(-1*self.view.bounds.size.width, 0, self.view.bounds.size.width, self.view.bounds.size.height);
            break;
            
        default:
            break;
    }
    
    POPBasicAnimation *animation = [controller.view pop_animationForKey:@"frame"];
    if (animation == nil) {
        animation =  [POPBasicAnimation animationWithPropertyNamed:kPOPViewFrame];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        animation.duration = 0.2;
        [controller.view pop_addAnimation:animation forKey:@"frame"];
    }
    animation.toValue = [NSValue valueWithCGRect:exitFrame];
    animation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        [self removeController:controller];
        if(success) {
            success();
        }
    };
}

- (void)popController:(UIViewController*)controller withSuccess:(void (^)(void))success
{
    [self popController:controller withDirection:UIRectEdgeRight withSuccess:success];
}

- (void)removeController:(UIViewController*)controller
{
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
}


@end
