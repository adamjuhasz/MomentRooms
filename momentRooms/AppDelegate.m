//
//  AppDelegate.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "AppDelegate.h"
#import <Parse/Parse.h>
#import "MomentsCloud.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <DigitsKit/DigitsKit.h>
#import "LoginViewController.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // [Optional] Power your app with Local Datastore. For more info, go to
    // https://parse.com/docs/ios_guide#localdatastore/iOS
    [Parse enableLocalDatastore];
    
#ifdef DEBUG
    [Fabric with:@[DigitsKit]];
#else
    [Fabric with:@[CrashlyticsKit, DigitsKit]];
#endif

    
    // Initialize Parse.
    [Parse setApplicationId:@"w1yclkbSiKmKKtZ8APYzZwLsAaHGDUsC9YyLfFHb"
                  clientKey:@"qlFdUfbSy3BjJNNaBYnZPj1LIAixiDeWFbFicnZ9"];
    
    // [Optional] Track statistics around application opens.
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    
    // ...
    self.mainViewController = [[IntroScreenViewController alloc] init];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = self.mainViewController;
    [self.window makeKeyAndVisible];
    
    if ([[MomentsCloud sharedCloud] loggedInUserName] == nil) {
        LoginViewController *loginView = [[LoginViewController alloc] init];
        [self.mainViewController pushController:loginView withDirection:UIRectEdgeBottom withSuccess:nil];
    } else {
        
    }

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSArray *pathComponents = [url pathComponents];
    if ([url.host isEqualToString:@"room"]) {
        NSLog(@"%@", pathComponents[1]);
        [[MomentsCloud sharedCloud] subscribeToRoomWithID:pathComponents[1] withCompletionHandler:^(MomentRoom *theRoom) {
            
        }];
    }
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [[MomentsCloud sharedCloud] storePushDeviceToken:deviceToken];
}

@end