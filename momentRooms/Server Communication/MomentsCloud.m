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
#import <ColorUtils/ColorUtils.h>
#import <CocoaSecurity/CocoaSecurity.h>

#define keychainPasswordKey(username) [NSString stringWithFormat:@"%@%@", @"password", username]

@interface MomentsCloud ()
{
    NSMutableArray *loadedMoments;
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
        self.mostRecentMoments = [NSMutableArray array];
        loadedMoments = [NSMutableArray array];
        
        @weakify(self);
        [RACObserve(self, loggedIn) subscribeNext:^(NSNumber *isLoggedIn) {
            @strongify(self);
            if ([isLoggedIn boolValue]) {
                [self loadCachedsubscribedRoomsWithCompletionBlock:^(NSArray *rooms) {
                    [self getCachedMomentsForSubscribedRoomsWithCompletionBlock:nil];
                }];
                [self getsubscribedRoomsWithCompletionBlock:^(NSArray* rooms){
                    [self getMomentsForSubscribedRoomsWithCompletionBlock:nil];
                }];
            }
        }];
        
        if ([PFUser currentUser]) {
            self.loggedIn = YES;
        }
        //[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(getMomentsForSubscribedRooms) userInfo:nil repeats:YES];
    }
    return self;
}

//user
#pragma mark User
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
#pragma mark Creation
- (void)createRoom:(MomentRoom*)newRoom
{
    PFObject *createdRoom = [self convertToPFObjectFromMomentRoom:newRoom];
    if (createdRoom == nil) {
        return;
    }
    
    [createdRoom pinInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
    }];
    [createdRoom saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            NSLog(@"Error creating room %@; %@", createdRoom, error);
            [createdRoom unpinInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
                [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
            }];
        }
        [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
    }];
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
            [newPost unpinInBackground];
            NSLog(@"couldnt upload moment because %@", error);
        }
    }];
    
    [roomObject addMoments:[NSArray arrayWithObject:moment]];
}

#pragma mark Convert between Moments/Parse

- (NSString*)pathForMomentsImage:(Moment*)moment
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:moment.postid];
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
    for (Moment *aCachedMoment in loadedMoments) {
        if ([aCachedMoment.postid isEqualToString:post.objectId]) {
            return aCachedMoment;
        }
    }
    
    Moment *newMoment = [[Moment alloc] init];
    newMoment.postid = post.objectId;
    newMoment.dateCreated = post.createdAt;
    newMoment.dateLastChanged = post.updatedAt;
    PFObject *roomObject = post[@"room"];
    newMoment.roomId = roomObject.objectId;
    newMoment.timeLifetime = [post[@"lifetime"] doubleValue];
    newMoment.text = post[@"text"];
    newMoment.filterName = post[@"filterName"];
    newMoment.filterSettings = post[@"filterSettings"];
    newMoment.userid = post[@"userid"];
    newMoment.likeCount = [post[@"likeCount"] unsignedIntegerValue];
    newMoment.commentCount = [post[@"commentCount"] unsignedIntegerValue];
    newMoment.activityCount = [post[@"activityCount"] unsignedIntegerValue];
    PFGeoPoint *location = post[@"coordinates"];
    if (location) {
        newMoment.coordinates = [[CLLocation alloc] initWithLatitude:location.latitude longitude:location.longitude];
    }
    
    NSError *readError;
    NSData *encryptedFileData = [NSData dataWithContentsOfFile:[self pathForMomentsImage:newMoment] options:0 error:&readError];
    if (encryptedFileData) {
        //CocoaSecurityResult * sha = [CocoaSecurity sha384:@"Moments"];
        //NSData *aesKey = [sha.data subdataWithRange:NSMakeRange(0, 32)];
        //NSData *aesIv = [sha.data subdataWithRange:NSMakeRange(32, 16)];
        //NSData *decryptedData = [[CocoaSecurity aesDecryptWithData:encryptedFileData key:aesKey iv:aesIv] data];
        UIImage *image = [UIImage imageWithData:encryptedFileData];
        newMoment.image = image;
    } else {
        PFFile *file = post[@"image"];
        if (file) {
            [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error){
                                    //CocoaSecurityResult * sha = [CocoaSecurity sha384:@"Moments"];
                                    //NSData *aesKey = [sha.data subdataWithRange:NSMakeRange(0, 32)];
                                    //NSData *aesIv = [sha.data subdataWithRange:NSMakeRange(32, 16)];
                                    //NSData *encryptedData = [[CocoaSecurity aesDecryptWithData:imageData key:aesKey iv:aesIv] data];
                
                                    NSError *writeError;
                                    [imageData writeToFile:[self pathForMomentsImage:newMoment] options:NSDataWritingAtomic error:&writeError];
                                    UIImage *image = [UIImage imageWithData:imageData];
                                    newMoment.image = image;
                                 }
                                 progressBlock:^(int percentDone){
                                     newMoment.downloadPercent = (float)percentDone/100.0;
                                 }];
        }
    }
    
    int i=0;
    for (i=0; i<loadedMoments.count; i++) {
        Moment *cachedMoment = loadedMoments[i];
        if ([newMoment.dateCreated compare:cachedMoment.dateCreated] == NSOrderedDescending) {
            break;
        }
    }
    [loadedMoments insertObject:newMoment atIndex:i];
    
    if (i < 5) {
        NSMutableArray *recentMoments = [self mutableArrayValueForKey:@"mostRecentMoments"];
        [recentMoments insertObject:newMoment atIndex:i];
        if (recentMoments.count >= 5) {
            [recentMoments removeLastObject];
        }
    }
    

    return newMoment;
}

//consumption
#pragma mark Get Moments
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
            [PFObject pinAllInBackground:moments];
            NSArray *momentsArray = [self processMomentsFromParse:moments];
            if (completionBlock) {
                completionBlock(momentsArray);
            }
        } else {
            NSLog(@"error getting moments: %@", error);
        }
    }];
}

- (void)getCachedMomentsForSubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    [[momentsQuery fromLocalDatastore] ignoreACLs];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *moments, NSError *error){
        if (!error) {
             NSArray *momentsArray = [self processMomentsFromParse:moments];
            if (completionBlock) {
                completionBlock(momentsArray);
            }
        }
    }];
}

- (NSMutableArray*)processMomentsFromParse:(NSArray*)moments
{
    NSMutableArray *momentsArray = [NSMutableArray array];
    for (int i=0; i<moments.count; i++) {
        PFObject *object = moments[i];
        Moment *newMoment = [self convertToMomentFromPFObject:object];
        for (MomentRoom *aroom in self.subscribedRooms) {
            if ([aroom.roomid isEqualToString:newMoment.roomId]) {
                [aroom addMoments:[NSArray arrayWithObject:newMoment]];
            }
        }
        [momentsArray insertObject:newMoment atIndex:i];
    }
    
    NSLog(@"proccessing %ld moments, of those %ld were new", (unsigned long)moments.count, (unsigned long)momentsArray.count);
    return momentsArray;
}

- (void)getCachedMomentsForRoom:(MomentRoom*)room WithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFObject *parseRoom = [self convertToPFObjectFromMomentRoom:room];
    if (parseRoom == nil) {
        return;
    }
    
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"room" equalTo:parseRoom];
    [momentsQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    [[momentsQuery fromLocalDatastore] ignoreACLs];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *moments, NSError *error){
        if (!error) {
            NSArray *momentsArray = [self processMomentsFromParse:moments];
            if (completionBlock) {
                completionBlock(momentsArray);
            }
        } else {
            NSLog(@"error getting moments: %@", error);
        }
    }];
}

- (void)getMomentsForRoom:(MomentRoom*)room WithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFObject *parseRoom = [self convertToPFObjectFromMomentRoom:room];
    if (parseRoom == nil) {
        return;
    }
    
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"room" equalTo:parseRoom];
    [momentsQuery whereKey:@"expiresAt" greaterThan:[NSDate date]];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *moments, NSError *error){
        if (!error) {
            [PFObject pinAllInBackground:moments];
            NSArray *momentsArray = [self processMomentsFromParse:moments];
            if (completionBlock) {
                completionBlock(momentsArray);
            }
        } else {
            NSLog(@"error getting moments: %@", error);
        }
    }];
}

- (PFObject*)findPFObjectForRoom:(MomentRoom*)room
{
    PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
    [[roomQuery fromLocalDatastore] ignoreACLs];
    PFObject *cachedRoom = [roomQuery getObjectWithId:room.roomid];
    return cachedRoom;
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

#pragma mark Convert MomentRoom/Parse

-(BOOL)MomentRoomIsValid:(MomentRoom*)room
{
    if (room.roomLifetime <= 0) {
        return NO;
    }
    if (room.roomName == nil || [room.roomName isEqualToString:@""]) {
        return NO;
    }
    if (room.backgroundColor == nil) {
        return NO;
    }
    return YES;
}

- (PFObject*)convertToPFObjectFromMomentRoom:(MomentRoom*)room
{
    PFObject *newRoom = [self findPFObjectForRoom:room];
    if (newRoom) {
        return newRoom;
    }

    if ([self MomentRoomIsValid:room] == NO) {
        return nil;
    }
    
    newRoom = [PFObject objectWithClassName:@"Room"];
    newRoom.objectId = room.roomid;
    newRoom[@"name"] = room.roomName;
    if (room.backgroundImage) {
        NSData *imageData = UIImageJPEGRepresentation(room.backgroundImage, 0.8);
        PFFile *backgroundImageParseFile = [PFFile fileWithName:@"background.jpg" data:imageData];
        newRoom[@"backgroundImage"] = backgroundImageParseFile;
    }
    newRoom[@"expirationTime"] = @(room.roomLifetime);
    newRoom[@"backgroundColor"] =  room.backgroundColor.stringValue;
    return newRoom;
}

- (MomentRoom*)convertToMomentRoomFromPFObject:(PFObject*)room
{
    MomentRoom *newRoom = [[MomentRoom alloc] init];
    newRoom.roomid = room.objectId;
    newRoom.roomName = room[@"name"];
    PFFile *file = room[@"backgroundImage"];
    if (file) {
        [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error){
            newRoom.backgroundImage = [UIImage imageWithData:imageData];
        }
                             progressBlock:^(int percentDone){
                                 
                             }];

    }
    newRoom.roomLifetime = [room[@"expirationTime"] floatValue];
    newRoom.backgroundColor = [UIColor colorWithString:room[@"backgroundColor"]];
    
    [self getUsersForRoom:newRoom withCompletionBlock:^(NSArray *membersOfRoom) {
        newRoom.members = membersOfRoom;
    }];
    
    return newRoom;
}

#pragma mark Get MomentRooms
- (void)getsubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    if ([PFUser currentUser] == nil) {
        return;
    }
    
    PFQuery *roleQuery = [PFRole query];
    [roleQuery whereKey:@"users" equalTo:[PFUser currentUser]];
    [roleQuery findObjectsInBackgroundWithBlock:^(NSArray *roles, NSError *error){
        if (error) {
            NSLog(@"Error getting roles with %@", error);
            return;
        }
        [PFObject pinAllInBackground:roles];
        NSMutableArray *rooms = [NSMutableArray array];
        for (PFRole *role in roles) {
            [rooms addObject:role.name];
        }
        PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
        [roomQuery whereKey:@"objectId" containedIn:rooms];
        [roomQuery findObjectsInBackgroundWithBlock:^(NSArray *rooms, NSError *error){
            if (!error) {
                NSString *nameOfObjectPin = @"subscribedRooms";
                [PFObject unpinAllObjectsInBackgroundWithName:nameOfObjectPin];
                NSMutableArray *momentRooms = [NSMutableArray array];
                for (PFObject *room in rooms) {
                    NSLog(@"%@ called %@", room.objectId, room[@"name"]);
                    MomentRoom *aNewRoom = [self convertToMomentRoomFromPFObject:room];
                    if (aNewRoom) {
                        [momentRooms addObject:aNewRoom];
                    }
                }
                [PFObject pinAllInBackground:rooms withName:nameOfObjectPin block:^(BOOL succeeded, NSError *PF_NULLABLE_S error){
                    [self loadCachedsubscribedRoomsWithCompletionBlock:^(NSArray *rooms) {
                        if (completionBlock) {
                            completionBlock(momentRooms);
                        }
                    }];
                    
                }];
            }
        }];
    }];
}

- (void)loadCachedsubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    [query findObjectsInBackgroundWithBlock:^(NSArray *cachedRooms, NSError *error){
        if (error) {
            NSLog(@"error getting cached rooms, %@", error);
            return;
        }
        
        NSMutableArray *rooms = [NSMutableArray array];
        for (PFObject *aRoom in cachedRooms) {
            BOOL roomIsCached = NO;
            MomentRoom *newRoom = [self convertToMomentRoomFromPFObject:aRoom];
            if (self.subscribedRooms) {
                for (MomentRoom *room in self.subscribedRooms) {
                    if ([room.roomid isEqualToString:aRoom.objectId]) {
                        roomIsCached = YES;
                        //change room details
                        if ([room.roomName isEqualToString:newRoom.roomName] == NO) {
                            room.roomName = newRoom.roomName;
                        }
                        if (room.roomLifetime != newRoom.roomLifetime) {
                            room.roomLifetime = newRoom.roomLifetime;
                        }
                        //should the background be changable
                        if ([room.backgroundColor isEquivalentToColor:newRoom.backgroundColor] == NO) {
                            room.backgroundColor = newRoom.backgroundColor;
                        }
                        continue;
                    }
                }
                
            }
            if (roomIsCached == NO) {
                [rooms addObject:newRoom];
            }
        }
        
        if (self.subscribedRooms == nil) {
            self.subscribedRooms = [NSMutableArray array];
        }
        
        NSMutableArray *theseMoments = [self mutableArrayValueForKey:@"subscribedRooms"];
        [theseMoments addObjectsFromArray:rooms];
        if (completionBlock) {
            completionBlock(rooms);
        }
    }];
    
    
}

- (NSArray*)cachedSubscribedRooms
{
    if (self.subscribedRooms == nil) {
        [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
    }
    return self.subscribedRooms;
}

- (MomentRoom*)getCachedRoomWithID:(NSString*)roomID
{
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    [query whereKey:@"objectId" equalTo:roomID];
    PFObject *object = [query getFirstObject];
    MomentRoom *room = [self convertToMomentRoomFromPFObject:object];
    return room;
}

#pragma mark Room subscription
- (void)subscribeToRoomWithID:(NSString *)roomID withCompletionHandler:(void (^)(MomentRoom*))completionBlock
{
    if ([PFUser currentUser] == nil) {
        return;
    }
    
    PFQuery *roleQuery = [PFRole query];
    [roleQuery whereKey:@"name" equalTo:roomID];
    [roleQuery getFirstObjectInBackgroundWithBlock:^(PFObject *roleObject,  NSError *error){
        if (!error) {
            PFRole *role = (PFRole*)roleObject;
            [role.users addObject:[PFUser currentUser]];
            [role saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
                if (succeeded) {
                    [self getsubscribedRoomsWithCompletionBlock:^(NSArray *rooms) {
                        for (MomentRoom *aRoom in rooms) {
                            if ([aRoom.roomid isEqualToString:roomID]) {
                                if (completionBlock) {
                                    completionBlock(aRoom);
                                }
                                [self getMomentsForRoom:aRoom WithCompletionBlock:^(NSArray *moments) {
                                
                                }];
                            }
                        }
                        
                    }];
                }
            }];
        }
    }];
}

#pragma mark Get Users
- (MomentUser*)convertPFUserToMomentUser:(PFUser*)user
{
    MomentUser *newUser = [[MomentUser alloc] init];
    newUser.name = user[@"username"];
    PFFile *file = user[@"image"];
    if (file) {
        [file getDataInBackgroundWithBlock:^(NSData *imageData, NSError *error){
                                 newUser.image = [UIImage imageWithData:imageData];
                             }
                             progressBlock:^(int percentDone){
                                 
                             }];
    }
    return newUser;

}

- (void)getUsersForRoom:(MomentRoom*)momentRoom withCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFQuery *roleQuery = [PFRole query];
    [roleQuery whereKey:@"name" equalTo:momentRoom.roomid];
    [roleQuery getFirstObjectInBackgroundWithBlock:^(PFObject *object,  NSError  *error) {
        if (error) {
            NSLog(@"Error getting room role; %@", error);
            return;
        }
        [PFObject pinAllInBackground:@[object]];
        PFRole *roomsRole = (PFRole*)object;
        PFRelation *users = roomsRole.users;
        PFQuery *userQuery = users.query;
        [userQuery findObjectsInBackgroundWithBlock:^(NSArray *users, NSError *error){
            if (error) {
                NSLog(@"Error getting users from Relation; %@", error);
                return;
            }
            NSMutableArray *usersInRoom = [NSMutableArray array];
            [PFObject pinAllInBackground:users];
            for (PFUser *aUser in users) {
                MomentUser *aMomentUser = [self convertPFUserToMomentUser:aUser];
                [usersInRoom addObject:aMomentUser];
            }
            if (completionBlock) {
                completionBlock(usersInRoom);
            }
        }];
        
    }];
}

#pragma mark Utilties
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
