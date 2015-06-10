//
//  RecentMomentsView.h
//  momentRooms
//
//  Created by Adam Juhasz on 6/5/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Moment/MomentRoom.h>

@protocol RecentMomentsDelegate <NSObject>
@required
- (void)openRoom:(MomentRoom*)theRoom;

@end

@interface RecentMomentsView : UIView

@property (weak) id <RecentMomentsDelegate> delegate;

@end
