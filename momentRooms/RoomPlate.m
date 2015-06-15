//
//  RoomPlate.m
//  roomNav
//
//  Created by Adam Juhasz on 5/29/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "RoomPlate.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <UIColor+ContrastingColor/UIColor+ContrastingColor.h>
#import <MessageUI/MessageUI.h>
#import <TGPControls/TGPCamelLabels.h>
#import <TGPControls/TGPDiscreteSlider.h>
#import "UserCell.h"
#import "AppDelegate.h"
#import "MomentsCloud.h"

@interface RoomPlate () <UITableViewDelegate, UICollectionViewDataSource, MFMessageComposeViewControllerDelegate>
{
    CGFloat navigationHeaderHeight;
    CGFloat locationAtScrollStart;
}
@end

@implementation RoomPlate

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        locationAtScrollStart = 0;
        navigationHeaderHeight = 64;
        
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 0.0;
        
        text = [[UITextField alloc] initWithFrame:CGRectMake(0 , 20, frame.size.width, 30)];
        text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:34];
        text.userInteractionEnabled = NO;
        text.textAlignment = NSTextAlignmentCenter;
        text.minimumFontSize = 8;
        text.adjustsFontSizeToFitWidth = YES;
        text.returnKeyType = UIReturnKeyDone;
        [self addSubview:text];
        
        minimizeButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(8, 28, 20, 20) buttonType:buttonDownBasicType buttonStyle:buttonPlainStyle animateToInitialState:YES];
        minimizeButton.tintColor = [UIColor whiteColor];
        [minimizeButton addTarget:self.delegate action:@selector(minimizeRoom) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:minimizeButton];
        
        shareButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(self.bounds.size.width-28, 28, 20, 20) buttonType:buttonShareType buttonStyle:buttonPlainStyle animateToInitialState:NO];
        shareButton.tintColor = [UIColor whiteColor];
        [shareButton addTarget:self action:@selector(share) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:shareButton];
        
        CGRect bounds = [[UIScreen mainScreen] bounds];
        
        NSArray *ticks = @[@"1h", @"2h", @"4h", @"1d", @"2d", @"4d", @"1w", @"2w"];
        
        lifetimeSlider = [[TGPDiscreteSlider alloc] initWithFrame:CGRectMake(20, 90, bounds.size.width-40, 40)];
        lifetimeSlider.tickCount = (int)ticks.count;
        lifetimeSlider.tickStyle = ComponentStyleInvisible;
        lifetimeSlider.tickSize = CGSizeMake(1, 10);
        lifetimeSlider.trackStyle = ComponentStyleInvisible;
        lifetimeSlider.trackThickness = 1;
        lifetimeSlider.minimumValue = 0;
        lifetimeSlider.incrementValue = 1;
        lifetimeSlider.backgroundColor = [UIColor clearColor];
        [self addSubview:lifetimeSlider];

        labels = [[TGPCamelLabels alloc] initWithFrame:CGRectMake(20, 70, bounds.size.width-40, 25)];
        labels.names = ticks;
        [self addSubview:labels];
        
        lifetimeSlider.ticksListener = labels;
        
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
        flowLayout.minimumLineSpacing = 1;
        flowLayout.minimumInteritemSpacing = 1;
        flowLayout.itemSize = CGSizeMake(40, 40);
        membersOfRoom = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, flowLayout.itemSize.width*3+2, 100) collectionViewLayout:flowLayout];
        membersOfRoom.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        [membersOfRoom registerClass:[UserCell class] forCellWithReuseIdentifier:@"user"];
        membersOfRoom.dataSource = self;
        membersOfRoom.backgroundColor = [UIColor clearColor];
        [self addSubview:membersOfRoom];
        
        notificationSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
        notificationSwitch.onTintColor = [UIColor whiteColor];
        [notificationSwitch addTarget:self action:@selector(changePush:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:notificationSwitch];
        
        notificationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
        notificationLabel.text = @"Get notifications for new posts";
        [notificationLabel sizeToFit];
        [self addSubview:notificationLabel];
        
        removeButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                       initWithString:@"Leave room"];
        [attributedString addAttribute:NSUnderlineStyleAttributeName
                                 value:@(NSUnderlineStyleSingle)
                                 range:NSMakeRange(0, attributedString.length)];
        [removeButton setTitle:@"Leave room" forState:UIControlStateNormal];
        [removeButton setAttributedTitle:attributedString forState:UIControlStateNormal];
        [removeButton sizeToFit];
        removeButton.enabled = YES;
        [removeButton addTarget:self action:@selector(LeaveRoom) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:removeButton];
        
        backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        backgroundView.alpha = 0.2;
        backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        backgroundView.backgroundColor = [UIColor clearColor];
        [self addSubview:backgroundView];
        [self sendSubviewToBack:backgroundView];
        
        @weakify(self);
        [RACObserve(self, room) subscribeNext:^(MomentRoom *newRoom) {
            @strongify(self);
            
            [[RACObserve(newRoom, backgroundImage) filter:^BOOL(id value) {
                return (value != nil);
            }] subscribeNext:^(UIImage *backgroundImage) {
                backgroundView.image = backgroundImage;
            }];
            
            [RACObserve(newRoom, roomName) subscribeNext:^(NSString *roomName) {
                text.text = roomName;
            }];
            
            [RACObserve(newRoom, isSubscribed) subscribeNext:^(NSNumber *isSubbed) {
                notificationSwitch.on = [isSubbed boolValue];
            }];
            
            [RACObserve(newRoom, members) subscribeNext:^(NSArray *theMembersOfTheRoom) {
                memberList = theMembersOfTheRoom;
                [membersOfRoom reloadData];
            }];
            
            [RACObserve(newRoom, backgroundColor) subscribeNext:^(UIColor *roomBackgroundColor) {
                self.contrastColor = [roomBackgroundColor sqf_contrastingColorWithMethod:SQFContrastingColorYIQMethod];
                self.backgroundColor = roomBackgroundColor;
                text.textColor = self.contrastColor;
                text.tintColor = self.contrastColor;
                minimizeButton.tintColor = self.contrastColor;
                shareButton.tintColor = self.contrastColor;
                labels.upFontColor = self.contrastColor;
                labels.downFontColor = self.contrastColor;
                lifetimeSlider.thumbColor = self.contrastColor;
                NSMutableAttributedString *titleString = [[removeButton attributedTitleForState:UIControlStateNormal] mutableCopy];
                [titleString addAttribute:NSForegroundColorAttributeName value:self.contrastColor range:NSMakeRange(0,titleString.length)];
                [removeButton setAttributedTitle:titleString forState:UIControlStateNormal];
                notificationLabel.textColor = self.contrastColor;
            }];
            [RACObserve(newRoom, roomLifetime) subscribeNext:^(NSNumber *newLifetime) {
                switch ([newLifetime integerValue]) {
                    case 1*60*60:
                        lifetimeSlider.value = 0;
                        break;
                    case 2*60*60:
                        lifetimeSlider.value = 1;
                        break;
                    case 4*60*60:
                        lifetimeSlider.value = 2;
                        break;
                    case 24*60*60:
                        lifetimeSlider.value = 3;
                        break;
                    case 2*24*60*60:
                        lifetimeSlider.value = 4;
                        break;
                    case 4*24*60*60:
                        lifetimeSlider.value = 5;
                        break;
                    case 7*24*60*60:
                        lifetimeSlider.value = 6;
                        break;
                    case 14*24*60*60:
                        lifetimeSlider.value = 7;
                    default:
                        lifetimeSlider.value = 0;
                        break;
                }
                labels.value = lifetimeSlider.value;
            }];
        }];
        
        [self willMinimizeRoom];
    }
    return self;
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    if (bounds.size.width == 250) {
        height = bounds.size.height;
    }
    if (bounds.size.width > 300) {
        //text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:34];
        [text sizeToFit];
        text.bounds = CGRectMake(0, 0, bounds.size.width-80, 44);
        //feed.hidden = NO;
        //feed.frame = CGRectMake(0, height, bounds.size.width, 600);
        self.layer.cornerRadius = 0;
    } else {
        //text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:8];
        [text sizeToFit];
        text.bounds = CGRectMake(0, 0, bounds.size.width, text.bounds.size.height);
        self.layer.cornerRadius = 0.0;
    }
    
    membersOfRoom.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    
    text.center = CGPointMake(bounds.size.width/2.0, 20+text.bounds.size.height/2.0);
    
    if (momentDisplayer) {
        momentDisplayer.frame = CGRectMake(0, 64, self.bounds.size.width, self.bounds.size.height-64);
    }
    
    shareButton.frame = CGRectMake(bounds.size.width-28, 28, 20, 20);
    lifetimeSlider.bounds = CGRectMake(0, 0, bounds.size.width-40, 20);
    lifetimeSlider.center = CGPointMake(bounds.size.width/2.0, lifetimeSlider.center.y);
    labels.bounds = CGRectMake(0, 0, bounds.size.width-50, 20);
    labels.center = CGPointMake(bounds.size.width/2.0, labels.center.y);
    
    notificationSwitch.center = CGPointMake(self.bounds.size.width - (27 + notificationSwitch.bounds.size.width/2.0), 150);
    notificationLabel.center = CGPointMake(27 + notificationLabel.bounds.size.width/2.0, 150);
    
    removeButton.center = CGPointMake(27 + removeButton.bounds.size.width/2.0, 180);
    
    backgroundView.frame = bounds;
}

- (void)willMaximizeRoom
{
    isMinimized = NO;
    
    [self addSubview:minimizeButton];
    [self addSubview:shareButton];
    [self addSubview:lifetimeSlider];
    [self addSubview:labels];
    [self addSubview:notificationSwitch];
    [self addSubview:notificationLabel];
    [self addSubview:removeButton];
    [self addSubview:momentDisplayer];
    
    [membersOfRoom removeFromSuperview];
}

- (void)didMaximizeRoom
{
    momentDisplayer = [[MomentsViewer alloc] init];
    momentDisplayer.frame = CGRectMake(0, navigationHeaderHeight, self.bounds.size.width, self.bounds.size.height-navigationHeaderHeight);
    momentDisplayer.myRoom = self.room;
    momentDisplayer.backgroundColor = [UIColor whiteColor];
    momentDisplayer.tableDelegate = self;
    [self addSubview:momentDisplayer];
}

- (void)willMinimizeRoom
{
    if (isMinimized == NO) {
        isMinimized = YES;
        
        [minimizeButton removeFromSuperview];
        [shareButton removeFromSuperview];
        [lifetimeSlider removeFromSuperview];
        [labels removeFromSuperview];
        [notificationSwitch removeFromSuperview];
        [notificationLabel removeFromSuperview];
        [removeButton removeFromSuperview];
        [self addSubview:membersOfRoom];
        
        momentDisplayer.hidden = YES;
    }
}

- (void)didMinimizeRoom
{
    [momentDisplayer removeFromSuperview];
    momentDisplayer = nil;
}

- (void)share
{
    if(![MFMessageComposeViewController canSendText]) {
        UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Your device doesn't support SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [warningAlert show];
        return;
    }
    
    MFMessageComposeViewController *messageController = [[MFMessageComposeViewController alloc] init];
    NSString *mesageString = [NSString stringWithFormat:@"Join \"%@\" on Moments, moments://room/%@", self.room.roomName, self.room.roomid];
    [messageController setBody:mesageString];
    
    messageController.messageComposeDelegate = self;
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:messageController animated:YES completion:nil];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    locationAtScrollStart = momentDisplayer.frame.origin.y;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == membersOfRoom) {
        return;
    }
    UIPanGestureRecognizer *recognizer = scrollView.panGestureRecognizer;
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (isMinimized) {
            self.center = [recognizer locationInView:self.superview];
            return;
        }
        
        CGPoint newOffset = [recognizer translationInView:momentDisplayer];
        newOffset.x = 0;
        if (scrollView.contentOffset.y < 0) {
            if (newOffset.y > (navigationHeaderHeight + 150)) {
                //start dimming the controls
            }
            if (newOffset.y > (self.bounds.size.height/2.0 * 0.8)) {
                [self willMinimizeRoom];
                CGSize minimizedSize = [self.delegate sizeOfMininimzedRoom];
                self.bounds = CGRectMake(0, 0, minimizedSize.width, minimizedSize.height);
                self.center = [recognizer locationInView:self.superview];
            } else {
                scrollView.contentOffset = CGPointZero;
                momentDisplayer.frame = CGRectMake(0, newOffset.y + locationAtScrollStart, self.bounds.size.width, self.bounds.size.height-navigationHeaderHeight);
            }
        } else {
            if (momentDisplayer.frame.origin.y > navigationHeaderHeight) {
                momentDisplayer.frame = CGRectMake(0, MAX(locationAtScrollStart + newOffset.y,navigationHeaderHeight), self.bounds.size.width, self.bounds.size.height-navigationHeaderHeight);
                scrollView.contentOffset = CGPointZero;
            }
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView == membersOfRoom) {
        return;
    }
    
    if (isMinimized) {
        [self.delegate minimizeRoom];
    }
    
    if (momentDisplayer.frame.origin.y > navigationHeaderHeight) {
        CGPoint velocity = [scrollView.panGestureRecognizer velocityInView:momentDisplayer];
        CGPoint translation = [scrollView.panGestureRecognizer translationInView:momentDisplayer];
        if (velocity.y < 0) {
            momentDisplayer.frame = CGRectMake(0, navigationHeaderHeight, self.bounds.size.width, self.bounds.size.height-navigationHeaderHeight);
            targetContentOffset->y = 0;
        } else {
            momentDisplayer.frame = CGRectMake(0, navigationHeaderHeight + 150, self.bounds.size.width, self.bounds.size.height-navigationHeaderHeight);
            targetContentOffset->y = 0;
        }
        
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return memberList.count;
}

- (UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UserCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"user" forIndexPath:indexPath];
    
    cell.user = memberList[[indexPath indexAtPosition:1]];
    
    return cell;
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] dismissViewControllerAnimated:YES completion:nil];
}

- (void)LeaveRoom
{
    NSString *textOfAlert = [NSString stringWithFormat:@"Are you sure you want to leave %@?", self.room.roomName];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:textOfAlert
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* stayAction = [UIAlertAction actionWithTitle:@"Stay" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                          }];
    UIAlertAction* leaveAction = [UIAlertAction actionWithTitle:@"Leave" style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
                                                              [self.delegate minimizeRoom];
                                                              [[MomentsCloud sharedCloud] unSubscribeFromRoom:self.room withCompletionHandler:nil];
                                                          }];
    
    [alert addAction:stayAction];
    [alert addAction:leaveAction];
    
    AppDelegate *appDel = [[UIApplication sharedApplication] delegate];
    IntroScreenViewController *root = appDel.mainViewController;
    [root presentViewController:alert animated:YES completion:nil];
}

- (void)changePush:(UISwitch*)pushSwitch
{
    if (pushSwitch.on) {
        [[MomentsCloud sharedCloud] registerForPushForRoom:self.room];
    } else {
        [[MomentsCloud sharedCloud] unregisterForPushForRoom:self.room];
    }
}

@end
