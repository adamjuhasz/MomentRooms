//
//  MomentsCloud.h
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Moment/Moment.h>
#import <Moment/MomentRoom.h>

@class PFObject;

@interface MomentsCloud : NSObject

@property NSMutableArray *subscribedRooms;
@property BOOL loggedIn;

+ (id)sharedCloud;

//user
- (BOOL)havePasswordForUserNamed:(NSString*)string;
- (void)registerUserNamed:(NSString*)username withInformation:(NSDictionary*)dictionary;
- (void)registerUserNamed:(NSString *)username withInformation:(NSDictionary*)dictionary withPassword:(NSString*)password;
- (void)loginUserNamed:(NSString*)username;
- (void)loginUserNamed:(NSString *)username withPassword:(NSString*)password;
- (NSString*)loggedInUserName;

//creation
- (MomentRoom*)createRoomNamed:(NSString*)roomName withBackground:(UIImage*)backgroundImage withBackgroundColor:(UIColor*)backgroundColor andExpirationTime:(NSTimeInterval)expirationTime;
- (void)addMoment:(Moment*)moment ToRoom:(MomentRoom*)room;

//consumption
- (void)subscribeToRoomWithID:(NSString*)roomID;
- (void)getMomentsForSubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock;
- (void)getMomentsForRoomID:(NSString*)roomID;
- (void)getsubscribedRoomsWithCompletionBlock:(void (^)(void))completionBlock;
- (NSArray*)cachedSubscribedRooms;
- (NSArray*)cachedMomentsForRoom:(MomentRoom*)room;

@end
