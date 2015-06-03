//
//  MomentsCloud.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "MomentsCloud.h"
#import <Parse/Parse.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

#define keychainPasswordKey(username) [NSString stringWithFormat:@"%@%@", @"password", username]

@interface MomentsCloud ()
{
   
}
@end

@implementation MomentsCloud

+ (id)sharedCloud
{
    static MomentsCloud *floatingCloud;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        floatingCloud = [[MomentsCloud alloc] init];
    });
    return floatingCloud;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self loadCachedsubscribedRooms];
        [RACObserve(self, loggedIn) subscribeNext:^(NSNumber *isLoggedIn) {
            if ([isLoggedIn boolValue]) {
                [self getsubscribedRoomsWithCompletionBlock:^{
                    [self getMomentsForSubscribedRoomsWithCompletionBlock:nil];
                }];
            }
        }];
        if ([PFUser currentUser]) {
            self.loggedIn = YES;
        }
        [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(getMomentsForSubscribedRooms) userInfo:nil repeats:YES];
    }
    return self;
}

//user
- (BOOL)havePasswordForUserNamed:(NSString*)username
{
    NSString *password = [[UICKeyChainStore keyChainStore] stringForKey:keychainPasswordKey(username)];
    if (password) {
        return YES;
    } else {
        return NO;
    }
}

- (void)registerUserNamed:(NSString*)username withInformation:(NSDictionary*)dictionary
{
    [self registerUserNamed:username withInformation:dictionary withPassword:[self randomStringWithLength:20]];
}

- (void)registerUserNamed:(NSString *)username withInformation:(NSDictionary*)dictionary withPassword:(NSString*)password
{
    PFUser *theUser = [PFUser user];
    theUser.username = username;
    theUser.password = password;
    for (NSString *key in [dictionary allKeys]) {
        theUser[key] = [dictionary objectForKey:key];
    }
    
    [theUser signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            [[UICKeyChainStore keyChainStore] setString:username forKey:@"lastUsernameUsed"];
            [[UICKeyChainStore keyChainStore] setString:password forKey:keychainPasswordKey(username)];
            self.loggedIn = YES;
        }
    }];
}

- (void)loginUserNamed:(NSString*)username
{
    [self loginUserNamed:username withPassword:[[UICKeyChainStore keyChainStore] stringForKey:keychainPasswordKey(username)]];
}

- (void)loginUserNamed:(NSString *)username withPassword:(NSString*)password
{
    [PFUser logInWithUsernameInBackground:username
                                 password:password
                                    block:^(PFUser *user, NSError *error){
                                        if (user) {
                                            NSLog(@"logged in as %@", username);
                                            [[UICKeyChainStore keyChainStore] setString:username forKey:@"lastUsernameUsed"];
                                            [[UICKeyChainStore keyChainStore] setString:password forKey:keychainPasswordKey(username)];
                                            self.loggedIn = YES;
                                        } else {
                                            //login failure
                                            NSLog(@"Error couldn't log in as %@; %@", username, error);
                                        }
    }];
}

- (NSString*)loggedInUserName
{
    PFUser *user = [PFUser currentUser];
    if (user == nil) {
        return nil;
    } else {
        return user.username;
    }
}

//creation
- (MomentRoom*)createRoomNamed:(NSString*)roomName withBackground:(UIImage*)backgroundImage withBackgroundColor:(UIColor*)backgroundColor andExpirationTime:(NSTimeInterval)expirationTime
{
    NSData *imageData = UIImageJPEGRepresentation(backgroundImage, 1.0);
    PFFile *backgroundImageParseFile = [PFFile fileWithName:@"background.jpg" data:imageData];
    
    PFObject *newRoom = [PFObject objectWithClassName:@"Room"];
    newRoom[@"name"] = roomName;
    newRoom[@"backgroundImage"] = backgroundImageParseFile;
    newRoom[@"expirationTime"] = @(expirationTime);
    newRoom[@"backgroundColor"] =  backgroundColor;
    [newRoom pinInBackground];
    [newRoom saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (!error) {

        } else {
            NSLog(@"Error creating room %@; %@", roomName, error);
            [newRoom unpinInBackground];
        }
    }];
    
    return [self convertToMomentRoomFromPFObject:newRoom];
}

- (void)addMoment:(Moment*)moment ToRoom:(MomentRoom*)roomObject
{
    PFUser *user = [PFUser currentUser];
    if (user == nil) {
        return;
    }
    
    PFObject *room = [self findPFObjectForRoom:roomObject];
    if (room == nil) {
        return;
    }
    
    moment.timeLifetime = [room[@"expirationTime"] doubleValue];
    moment.userid = [user objectId];
    
    PFObject *newPost = [self convertToPFObjectFromMoment:moment];
    newPost[@"room"] = room;
    newPost[@"createdBy"] = user;
    
    [newPost pinInBackground];
    [newPost saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (succeeded) {
            moment.postid = [newPost objectId];
            moment.dateLastChanged = [newPost updatedAt];
            moment.dateCreated = [newPost createdAt];
            //NSLog(@"%@", moment);
        } else {
            NSLog(@"couldnt upload moment because %@", error);
        }
    }];
    
    [roomObject addMoments:[NSArray arrayWithObject:moment]];
}

- (PFObject*)convertToPFObjectFromMoment:(Moment*)moment
{
    NSData *imageData = UIImageJPEGRepresentation(moment.image, 1.0);
    PFFile *image = [PFFile fileWithName:@"image.jpg" data:imageData contentType:@"image/jpeg"];
    
    PFObject *newPost = [PFObject objectWithClassName:@"Post"];
    newPost[@"expiresAt"] = moment.dateExpires;
    if (moment.filterSettings) {
        newPost[@"filterSettings"] = moment.filterSettings;
    } else {
        newPost[@"filterSettings"] = [NSDictionary dictionary];
    }
    newPost[@"filterName"] = moment.filterName;
    if (moment.text) {
        newPost[@"text"] = moment.text;
    } else {
        newPost[@"text"] = @"";
    }
    newPost[@"image"] = image;
    newPost[@"lifetime"] = @(moment.timeLifetime);
    newPost[@"userid"] = moment.userid;
    if (moment.coordinates) {
        newPost[@"coordinates"] = [PFGeoPoint geoPointWithLocation:moment.coordinates];
    }
    return newPost;
}

- (Moment*)convertToMomentFromPFObject:(PFObject*)post
{
    Moment *newMoment = [[Moment alloc] init];
    newMoment.postid = post.objectId;
    newMoment.dateCreated = post.createdAt;
    newMoment.dateLastChanged = post.updatedAt;
    PFObject *roomObject = post[@"room"];
    newMoment.roomId = roomObject.objectId;
    newMoment.timeLifetime = [post[@"lifetime"] doubleValue];
    newMoment.text = post[@"text"];
    newMoment.filterSettings = post[@"filterSettings"];
    newMoment.filterName = post[@"filterName"];
    newMoment.userid = post[@"userid"];
    newMoment.likeCount = [post[@"likeCount"] unsignedIntegerValue];
    newMoment.commentCount = [post[@"commentCount"] unsignedIntegerValue];
    newMoment.activityCount = [post[@"activityCount"] unsignedIntegerValue];
    PFGeoPoint *location = post[@"coordinates"];
    if (location) {
        newMoment.coordinates = [[CLLocation alloc] initWithLatitude:location.latitude longitude:location.longitude];
    }
    
    PFFile *file = post[@"image"];
    [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error){
        UIImage *image = [UIImage imageWithData:imageData];
        newMoment.image = image;
                         }
                         progressBlock:^(int percentDone){
                             newMoment.downloadPercent = (float)percentDone/100.0;
                         }];
    return newMoment;
}

//consumption
- (void)getMomentsForSubscribedRooms
{
    [self getMomentsForSubscribedRoomsWithCompletionBlock:nil];
}

- (void)getMomentsForSubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    NSArray *cachedRooms = [query findObjects];
    
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"room" containedIn:cachedRooms];
    [momentsQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *moments, NSError *error){
        if (!error) {
            [PFObject pinAll:moments];
            NSLog(@"found %ld moments", (unsigned long)moments.count);
            NSMutableArray *momentsArray = [NSMutableArray array];
            for (PFObject *object in moments) {
                Moment *newMoment = [self convertToMomentFromPFObject:object];
                for (MomentRoom *aroom in self.subscribedRooms) {
                    if ([aroom.roomid isEqualToString:newMoment.roomId]) {
                        [aroom addMoments:[NSArray arrayWithObject:newMoment]];
                    }
                }
                //NSLog(@"Generated moment: %@", newMoment);
                [momentsArray addObject:newMoment];
            }
            if (completionBlock) {
                completionBlock(momentsArray);
            }
        } else {
            NSLog(@"error getting moments: %@", error);
        }
    }];
}
- (NSArray*)getMomentsForRoomNamed:(NSString*)roomName
{
    return nil;
}

- (PFObject*)findPFObjectForRoom:(MomentRoom*)room
{
    PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
    PFObject *cachedRoom = [roomQuery getObjectWithId:room.roomid];
    return cachedRoom;
}

- (PFObject*)convertToPFObjectFromMomentRoom:(MomentRoom*)room
{
    PFObject *newRoom = [self findPFObjectForRoom:room];
    if (newRoom) {
        return newRoom;
    }
    
    newRoom = [PFObject objectWithClassName:@"Room"];
    newRoom.objectId = room.roomid;
    newRoom[@"name"] = room.roomName;
    newRoom[@"backgroundImage"] = room.backgroundImage;
    newRoom[@"expirationTime"] = @(room.roomLifetime);
    newRoom[@"backgroundColor"] =  room.backgroundColor;
    return newRoom;
}

- (MomentRoom*)convertToMomentRoomFromPFObject:(PFObject*)room
{
    MomentRoom *newRoom = [[MomentRoom alloc] init];
    newRoom.roomid = room.objectId;
    newRoom.roomName = room[@"name"];
    newRoom.backgroundImage = room[@"backgroundImage"];
    newRoom.roomLifetime = [room[@"expirationTime"] floatValue];
    newRoom.backgroundColor = room[@"backgroundColor"];
    return newRoom;
}

- (void)getsubscribedRoomsWithCompletionBlock:(void (^)(void))completionBlock
{
    if ([PFUser currentUser] == nil) {
        return;
    }
    
    PFQuery *roleQuery = [PFRole query];
    [roleQuery whereKey:@"users" equalTo:[PFUser currentUser]];
    [roleQuery findObjectsInBackgroundWithBlock:^(NSArray *roles, NSError *error){
        NSMutableArray *rooms = [NSMutableArray array];
        for (PFRole *role in roles) {
            [rooms addObject:role.name];
        }
        PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
        [roomQuery whereKey:@"objectId" containedIn:rooms];
        [roomQuery findObjectsInBackgroundWithBlock:^(NSArray *rooms, NSError *error){
            if (!error) {
                [PFObject unpinAllObjectsWithName:@"subscribedRooms"];
                for (PFObject *room in rooms) {
                    NSLog(@"%@ called %@", room.objectId, room[@"name"]);
                }
                NSError *pinError;
                [PFObject pinAll:rooms withName:@"subscribedRooms" error:&pinError ];
                [self loadCachedsubscribedRooms];
                
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }];
}

- (void)loadCachedsubscribedRooms
{
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    NSArray *cachedRooms = [query findObjects];
    
    NSMutableArray *rooms = [NSMutableArray array];
    for (PFObject *aRoom in cachedRooms) {
        BOOL roomIsCached = NO;
        if (self.subscribedRooms) {
            for (MomentRoom *room in self.subscribedRooms) {
                if ([room.roomid isEqualToString:aRoom.objectId]) {
                    roomIsCached = YES;
                    continue;
                }
            }
            
        }
        if (roomIsCached == NO) {
            MomentRoom *newRoom = [self convertToMomentRoomFromPFObject:aRoom];
            [rooms addObject:newRoom];
        }
    }
    
    if (self.subscribedRooms == nil) {
        self.subscribedRooms = [NSMutableArray array];
    }
    
    NSMutableArray *theseMoments = [self mutableArrayValueForKey:@"subscribedRooms"];
    [theseMoments addObjectsFromArray:rooms];
}

- (NSArray*)cachedSubscribedRooms
{
    if (self.subscribedRooms == nil) {
        [self loadCachedsubscribedRooms];
    }
    return self.subscribedRooms;
}

- (void)getMomentsForRooms:(NSArray*)rooms
{
    NSMutableArray *array = [NSMutableArray array];
    for (PFObject *room in rooms) {
        [array addObject:room[@"name"]];
    }
    [self getMomentsForRoomIDs:array];
}

- (void)getMomentsForRoomIDs:(NSArray*)rooms
{
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Post"];
    [postQuery whereKey:@"room" containedIn:rooms];
    [postQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    [postQuery findObjectsInBackgroundWithBlock:^(NSArray *rooms, NSError *error){
        [PFObject pinAll:rooms];
    }];
}

- (void)getMomentsForRoomID:(NSString*)roomID
{
    [self getMomentsForRoomIDs:[NSArray arrayWithObject:roomID]];
}

- (NSArray*)cachedMomentsForRoom:(MomentRoom*)room
{
    PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
    [[roomQuery fromLocalDatastore] ignoreACLs];
    [roomQuery whereKey:@"objectId" equalTo:room.roomid];
    
    PFQuery *postQuery = [PFQuery queryWithClassName:@"Post"];
    [[postQuery fromLocalDatastore] ignoreACLs];
    [postQuery whereKey:@"room" matchesQuery:roomQuery];
    [postQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    NSArray *parseMoments = [postQuery findObjects];
    
    NSMutableArray *moments = [NSMutableArray array];
    for (PFObject *parseMoment in parseMoments) {
        Moment *aMoment = [self convertToMomentFromPFObject:parseMoment];
        [moments addObject:aMoment];
    }

    for (MomentRoom *aRoom in self.subscribedRooms) {
        if (aRoom.roomid == room.roomid) {
            [aRoom addMoments:moments];
        }
    }
    
    return moments;
}

- (void)subscribeToRoomWithID:(NSString *)roomID
{
    
}

NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*?<>";
- (NSString *)randomStringWithLength:(int)len
{
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex:(NSUInteger)arc4random_uniform((u_int32_t)[letters length])]];
    }
    
    return randomString;
}

@end
