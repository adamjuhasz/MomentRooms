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

@property NSMutableArray *mostRecentMoments;
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
- (void)createRoom:(MomentRoom*)newRoom;
- (void)addMoment:(Moment*)moment ToRoom:(MomentRoom*)room;

//Room Management
- (void)subscribeToRoomWithID:(NSString *)roomID withCompletionHandler:(void (^)(MomentRoom*))completionBlock;
- (void)unSubscribeFromRoom:(MomentRoom*)room withCompletionHandler:(void (^)(void))completionBlock;

//consumption
- (void)getMomentsForSubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock;
- (void)getMomentsForRoom:(MomentRoom*)room WithCompletionBlock:(void (^)(NSArray*))completionBlock;
- (void)getCachedMomentsForRoom:(MomentRoom*)room WithCompletionBlock:(void (^)(NSArray*))completionBlock;
- (void)getsubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock;
- (NSArray*)cachedSubscribedRooms;
- (NSArray*)cachedMomentsForRoom:(MomentRoom*)room;
- (MomentRoom*)getCachedRoomWithID:(NSString*)roomID;

@end
