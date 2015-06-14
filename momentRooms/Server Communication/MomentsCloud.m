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
    NSMutableDictionary *globalCachedMoments;
    NSMutableDictionary *globalCachedRooms;
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
        self.subscribedRooms = [NSMutableArray array];
        globalCachedMoments = [NSMutableDictionary dictionary];
        globalCachedRooms = [NSMutableDictionary dictionary];
        
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
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(getMomentsForSubscribedRooms) userInfo:nil repeats:YES];
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
    
    newRoom.roomid = [NSString stringWithFormat:@"%@_%@", @"@temp", [NSDate date]];
    newRoom.members = @[[self convertPFUserToMomentUser:[PFUser currentUser]]];
    NSMutableArray *subscribedRooms = [self mutableArrayValueForKey:@"subscribedRooms"];
    [subscribedRooms insertObject:newRoom atIndex:0];
    [globalCachedRooms setObject:newRoom forKey:newRoom.roomid];
    
    [createdRoom saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            NSLog(@"Error creating room \"%@\"; couldnt save; %@", createdRoom, error);
            [self tagError:@"createRoom" withError:error];
            [globalCachedRooms removeObjectForKey:newRoom.roomid];
            [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
            return;
            
        }
        [globalCachedRooms removeObjectForKey:newRoom.roomid];
        
        newRoom.roomid = createdRoom.objectId;
        newRoom.createdAt = createdRoom.createdAt;
        
        [globalCachedRooms setObject:newRoom forKey:newRoom.roomid];
        
        [self registerForPushForRoom:newRoom];
        [createdRoom pinInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
            if (error) {
                NSLog(@"Error creating room \"%@\"; couldnt pin; %@", createdRoom, error);
                [self tagError:@"createRoom" withError:error];
                [self getsubscribedRoomsWithCompletionBlock:nil];
            }
            [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
        }];
    }];
    
    [self tagEvent:@"createRoom" withInformation:nil];
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
    newPost[@"roomId"] = roomObject.roomid;
    
    moment.postid = [NSString stringWithFormat:@"%@_%@", @"@temp", [NSDate date]];
    moment.dateCreated = [NSDate date];
    moment.roomId = roomObject.roomid;
    
    [globalCachedMoments setObject:moment forKey:moment.postid];
    [roomObject addMoments:@[moment]];
    [self generateRecentMoments];
    
    [newPost saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            [newPost saveEventually];
            NSLog(@"Error adding moment; couldnt upload moment; %@", error);
            [self tagError:@"addMoment" withError:error];
            [roomObject.moments removeObject:moment];
            [globalCachedMoments removeObjectForKey:moment.postid];
            [self generateRecentMoments];
            return;
        }
        
        [globalCachedMoments removeObjectForKey:moment.postid];
        moment.postid = [newPost objectId];
        [globalCachedMoments setObject:moment forKey:moment.postid];
        
        moment.dateLastChanged = [newPost updatedAt];
        moment.dateCreated = [newPost createdAt];
        
        [newPost pinInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
            if (error) {
                NSLog(@"Error adding moment; couldnt pin moment; %@", error);
                [self tagError:@"addMoment" withError:error];
                [self getMomentsForSubscribedRoomsWithCompletionBlock:nil];
                return;
            }
        }];
    }];
    
    [self tagEvent:@"addMoment" withInformation:nil];
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
    Moment *aCachedMoment = [globalCachedMoments objectForKey:post.objectId];
    if (aCachedMoment) {
        return aCachedMoment;
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
    
    [self cacheMoment:newMoment];
    return newMoment;
}

- (Moment*)cacheMoment:(Moment*)theMomentToCache
{
    if ([globalCachedMoments objectForKey:theMomentToCache.postid]) {
        //should we check for changes?
        //TODO
        return [globalCachedMoments objectForKey:theMomentToCache.postid];
    }
    
    [globalCachedMoments setObject:theMomentToCache forKey:theMomentToCache.postid];
    
    for (int i=0; i<MIN(self.mostRecentMoments.count, 5); i++) {
        Moment *aRecentMoment = self.mostRecentMoments[i];
        if ([theMomentToCache.dateCreated compare:aRecentMoment.dateCreated] == NSOrderedDescending) {
            NSMutableArray *recentMoments = [self mutableArrayValueForKey:@"mostRecentMoments"];
            [recentMoments insertObject:theMomentToCache atIndex:i];
            if (recentMoments.count > 5) {
                [recentMoments removeLastObject];
            }
            break;
        }
    }
    
    if (self.mostRecentMoments.count == 0) {
        NSMutableArray *recentMoments = [self mutableArrayValueForKey:@"mostRecentMoments"];
        [recentMoments insertObject:theMomentToCache atIndex:0];
    }
    
    return theMomentToCache;
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
    
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"room" matchesQuery:query];
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

- (NSMutableArray*)processMomentsFromParse:(NSArray*)listOfNewParseMoments
{
    NSMutableArray *momentsArray = [NSMutableArray array];
    
    for (int i=0; i<listOfNewParseMoments.count; i++) {
        PFObject *object = listOfNewParseMoments[i];
        Moment *newMoment = [self convertToMomentFromPFObject:object];
        
        MomentRoom *potentialRoom = [globalCachedRooms objectForKey:newMoment.roomId];
        if (potentialRoom) {
            [potentialRoom addMoments:@[newMoment]];
        }
        [momentsArray addObject:newMoment];
    }
    
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

- (void)removeMomentsForRoom:(MomentRoom*)room
{
    PFObject *parseRoom = [self convertToPFObjectFromMomentRoom:room];
    
    for (Moment *oldMoment in room.moments) {
        [globalCachedMoments removeObjectForKey:oldMoment.postid];
    }
    
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [[momentsQuery fromLocalDatastore] ignoreACLs];
    [momentsQuery whereKey:@"room" equalTo:parseRoom];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error){
        if (error) {
            NSLog(@"Error removing moments from room; error getting moments; %@", error);
            [self tagError:@"removeMomentsForRoom" withError:error];
            return;
        }
        
        [PFObject unpinAllInBackground:objects block:^(BOOL succeeded, NSError *PF_NULLABLE_S error){
            if (error) {
                NSLog(@"Error removing moments from room; error unpinning moments; %@", error);
                [self tagError:@"removeMomentsForRoom" withError:error];
                return;
            }
        }];
    }];
    
    [self generateRecentMoments];
}

- (void)generateRecentMoments
{
    NSMutableArray *allMoments = [[globalCachedMoments allValues] mutableCopy];
    if (allMoments.count == 0) {
        return;
    }
            
    [allMoments sortUsingComparator:^NSComparisonResult(Moment *obj1, Moment *obj2) {
        return [obj2.dateCreated compare:obj1.dateCreated];
    }];
    NSRange deleteRange = {MIN(allMoments.count-1, 5), ((allMoments.count-5.0) >= 0) ? (allMoments.count-5.0)  : 0};
    [allMoments removeObjectsInRange:deleteRange];
    
    self.mostRecentMoments = allMoments;
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
    newRoom.isSubscribed = [self isRegisteredForPushForRoom:newRoom];
    newRoom.createdAt = room.createdAt;
    
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
    [roleQuery includeKey:@"name"];
    
    PFQuery *roomQuery = [PFQuery queryWithClassName:@"Room"];
    [roomQuery whereKey:@"objectId" matchesKey:@"name" inQuery:roleQuery];
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
}

- (void)loadCachedsubscribedRoomsWithCompletionBlock:(void (^)(NSArray*))completionBlock
{
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    [query orderByAscending:@"createdAt"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *fetchedCachedRooms, NSError *error){
        if (error) {
            NSLog(@"error getting cached rooms, %@", error);
            return;
        }
        
        NSMutableArray *allCachedRooms = [NSMutableArray array];
        for (PFObject *aRoom in fetchedCachedRooms) {
            MomentRoom *newlyCreatedRoom = [self convertToMomentRoomFromPFObject:aRoom];
            MomentRoom *cachedRoom = [self cacheMomentRoom:newlyCreatedRoom];
            [self addMomentRoomToSubscribedList:cachedRoom];
            [allCachedRooms addObject:cachedRoom];
        }
        
        NSMutableArray *deletedRooms = [self.subscribedRooms mutableCopy];
        [deletedRooms removeObjectsInArray:allCachedRooms];
        if (deletedRooms.count > 0) {
            NSMutableArray *subscribedRooms = [self mutableArrayValueForKey:@"subscribedRooms"];
            [subscribedRooms removeObjectsInArray:deletedRooms];
        }
        
        
        if (completionBlock) {
            completionBlock(allCachedRooms);
        }
    }];
}

- (MomentRoom*)cacheMomentRoom:(MomentRoom*)aPotentiallyNewRoom
{
    BOOL roomWasAlreadyCached = NO;
    
    if ([globalCachedRooms objectForKey:aPotentiallyNewRoom.roomid]) {
        MomentRoom *previouslyCachedRoom = [globalCachedRooms objectForKey:aPotentiallyNewRoom.roomid];
        if ([aPotentiallyNewRoom.roomid isEqualToString:previouslyCachedRoom.roomid]) {
            roomWasAlreadyCached = YES;
            //change room details
            if ([aPotentiallyNewRoom.roomName isEqualToString:previouslyCachedRoom.roomName] == NO) {
                previouslyCachedRoom.roomName = aPotentiallyNewRoom.roomName;
            }
            if (aPotentiallyNewRoom.roomLifetime != previouslyCachedRoom.roomLifetime) {
                previouslyCachedRoom.roomLifetime = aPotentiallyNewRoom.roomLifetime;
            }
            
            previouslyCachedRoom.allowsPosting = aPotentiallyNewRoom.allowsPosting;
            [previouslyCachedRoom addMoments:aPotentiallyNewRoom.moments];
            
            //should the background be changable
            if ([aPotentiallyNewRoom.backgroundColor isEquivalentToColor:previouslyCachedRoom.backgroundColor] == NO) {
                previouslyCachedRoom.backgroundColor = aPotentiallyNewRoom.backgroundColor;
            }
            
            roomWasAlreadyCached = YES;
            return previouslyCachedRoom;
        }
    }
    
    if (roomWasAlreadyCached == NO) {
        //cache the room
        [globalCachedRooms setObject:aPotentiallyNewRoom forKey:aPotentiallyNewRoom.roomid];
    }
    
    return aPotentiallyNewRoom;
}

- (void)addMomentRoomToSubscribedList:(MomentRoom*)theRoom
{
    for (MomentRoom *alreadyListedRoom in self.subscribedRooms) {
        //dont list it twice
        if ([alreadyListedRoom.roomid isEqualToString:theRoom.roomid]) {
            return;
        }
    }
    
    int i=0;
    for (i=0; i<self.subscribedRooms.count; i++) {
        MomentRoom *aCachedRoom = self.subscribedRooms[i];
        if ([aCachedRoom.createdAt compare:theRoom.createdAt] == NSOrderedAscending) {
            break;
        }
    }
    
    NSMutableArray *subscribedRooms = [self mutableArrayValueForKey:@"subscribedRooms"];
    [subscribedRooms insertObject:theRoom atIndex:i];
}

- (NSArray*)cachedSubscribedRooms
{
    if (self.subscribedRooms.count == 0) {
        [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
    }
    return self.subscribedRooms;
}

- (MomentRoom*)getCachedRoomWithID:(NSString*)roomID
{
    if (roomID == nil) {
        return nil;
    }
    MomentRoom *potentialRoom = [globalCachedRooms objectForKey:roomID];
    if (potentialRoom) {
        return potentialRoom;
    }
    
    PFQuery *query = [PFQuery queryWithClassName:@"Room"];
    [[query fromLocalDatastore] ignoreACLs];
    [query whereKey:@"objectId" equalTo:roomID];
    PFObject *object = [query getFirstObject];
    
    potentialRoom = [self convertToMomentRoomFromPFObject:object];
    return potentialRoom;
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
        if (error) {
            NSLog(@"Error subscribing; Error getting role for room; %@", error);
            [self tagError:@"subscribe" withError:error];
            return;
        }
        
        PFRole *role = (PFRole*)roleObject;
        [role.users addObject:[PFUser currentUser]];
        [role saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
            if (error) {
                NSLog(@"Error subscribing; Error saving role; %@", error);
                [self tagError:@"subscribe" withError:error];
                return;
            }
            
            [self getsubscribedRoomsWithCompletionBlock:^(NSArray *rooms) {
                MomentRoom *aRoom = [globalCachedRooms objectForKey:roomID];
                [self getMomentsForRoom:aRoom WithCompletionBlock:nil];
                [self registerForPushForRoom:aRoom];
                if (completionBlock) {
                    completionBlock(aRoom);
                }
            }];
        }];
    }];
}

- (void)unSubscribeFromRoom:(MomentRoom*)room withCompletionHandler:(void (^)(void))completionBlock
{
    if ([PFUser currentUser] == nil) {
        return;
    }
    
    //let us assume this will work out
    [self removeMomentsForRoom:room];
    [self unregisterForPushForRoom:room];
    [globalCachedRooms removeObjectForKey:room.roomid];
    NSMutableArray *subscribedRooms = [self mutableArrayValueForKey:@"subscribedRooms"];
    [subscribedRooms removeObject:room];
    
    //now do it for real
    PFObject *roomObject = [self convertToPFObjectFromMomentRoom:room];
    [PFObject unpinAllInBackground:@[roomObject] block:^(BOOL succeeded, NSError *error){
        if(error) {
            NSLog(@"Error unsubscribing; Error unpinning room; %@", error);
            [self tagError:@"unSubscribeFromRoom" withError:error];
            return;
        }
    }];
    
    PFQuery *roleQuery = [PFRole query];
    [roleQuery whereKey:@"name" equalTo:room.roomid];
    [roleQuery getFirstObjectInBackgroundWithBlock:^(PFObject *roleObject,  NSError *error){
        if (error) {
            NSLog(@"Error unsubscribing; Error getting role for room; %@", error);
            [self tagError:@"unSubscribeFromRoom" withError:error];
            [self loadCachedsubscribedRoomsWithCompletionBlock:nil];
            return;
        }
        
        PFRole *role = (PFRole*)roleObject;
        [role.users removeObject:[PFUser currentUser]];
        [role saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
            if (error) {
                NSLog(@"Error unsubscribing; Error removing user from role; %@", error);
                [self tagError:@"unSubscribeFromRoom" withError:error];
                [self getsubscribedRoomsWithCompletionBlock:nil];
                return;
            }
            
            if (completionBlock) {
                completionBlock();
            }
        }];
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
        [PFObject pinAllInBackground:@[object] withName:@"role"];
        PFRole *roomsRole = (PFRole*)object;
        PFRelation *users = roomsRole.users;
        PFQuery *userQuery = users.query;
        [userQuery findObjectsInBackgroundWithBlock:^(NSArray *users, NSError *error){
            if (error) {
                NSLog(@"Error getting users from Relation; %@", error);
                return;
            }
            NSMutableArray *usersInRoom = [NSMutableArray array];
            [PFObject pinAllInBackground:users withName:@"user"];
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

#pragma mark Push Notification

- (NSString*)generateChannelName:(MomentRoom*)room
{
    NSString *channel = [NSString stringWithFormat:@"Room_%@", room.roomid];
    return channel;
}

- (void)requestPushPermisssion
{
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes  categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)storePushDeviceToken:(NSData*)deviceToken
{
    // Store the deviceToken in the current Installation and save it to Parse
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    currentInstallation[@"user"] = [PFUser currentUser];
    [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            NSLog(@"Error storePushDeviceToken; Couldn't save PFInstallation: %@", error);
            [self tagError:@"storePushDeviceToken" withError:error];
            return;
        }
    }];
}

- (void)registerForPushForRoom:(MomentRoom*)room
{
    [self requestPushPermisssion];
    room.isSubscribed = YES;
    
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation addUniqueObject:[self generateChannelName:room] forKey:@"channels"];
    [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            NSLog(@"Error registerForPushForRoom; Couldn't save PFInstallation; %@", error);
            [self tagError:@"registerForPushForRoom" withError:error];
            room.isSubscribed = NO;
            return;
        }
    }];
    
    [self tagEvent:@"registerForPushForRoom" withInformation:nil];
}

- (void)unregisterForPushForRoom:(MomentRoom*)room
{
    room.isSubscribed = NO;
    
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation removeObject:[self generateChannelName:room] forKey:@"channels"];
    [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error){
        if (error) {
            NSLog(@"Error unregisterForPushForRoom; Couldn't save PFInstallation; %@", error);
            [self tagError:@"unregisterForPushForRoom" withError:error];
            room.isSubscribed = YES;
            return;
        }
    }];
    
    [self tagEvent:@"registerForPushForRoom" withInformation:nil];
}

- (BOOL)isRegisteredForPushForRoom:(MomentRoom*)room
{
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSArray *subscribedChannels = [currentInstallation objectForKey:@"channels"];
    for (NSString *roomId in subscribedChannels) {
        if ([room.roomid isEqualToString:roomId]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark Analytics

- (void)tagEvent:(NSString *)event withInformation:(NSDictionary *)info
{
    if (info) {
        [PFAnalytics trackEventInBackground:event dimensions:info block:nil];
    } else {
        [PFAnalytics trackEventInBackground:event block:nil];
    }
}

- (void)tagError:(NSString*)errorEvent withError:(NSError*)error
{
    [self tagEvent:@"error" withInformation:[NSDictionary dictionaryWithObjectsAndKeys:error, @"error", errorEvent, @"event", nil]];
}
         

#pragma mark Utilties

- (void)deleteExpiredMoments
{
    PFQuery *momentsQuery = [PFQuery queryWithClassName:@"Post"];
    [momentsQuery whereKey:@"expiresAt" lessThan:[NSDate date]];
    [momentsQuery findObjectsInBackgroundWithBlock:^(NSArray *expiredMoments, NSError *error){
        for (PFObject *anExpiredMoment in expiredMoments) {
            //delete its file
            
        }
        [PFObject unpinAllInBackground:expiredMoments];
    }];
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
