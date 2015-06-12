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

@interface RoomPlate () <UITableViewDelegate, UICollectionViewDataSource, MFMessageComposeViewControllerDelegate>

@end

@implementation RoomPlate

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 3.0;
        
        text = [[UITextField alloc] initWithFrame:CGRectMake(0 , 20, frame.size.width, 30)];
        text.font = [UIFont fontWithName:@"HelveticaNeue-Medium " size:34];
        text.userInteractionEnabled = NO;
        text.textAlignment = NSTextAlignmentCenter;
        text.minimumFontSize = 8;
        text.adjustsFontSizeToFitWidth = YES;
        text.returnKeyType = UIReturnKeyDone;
        [self addSubview:text];
        
        feed = [[UIView alloc] initWithFrame:self.bounds];
        feed.hidden = YES;
        feed.backgroundColor = [UIColor whiteColor];
        //[self addSubview:feed];
        
        minimizeButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(8, 28, 20, 20) buttonType:buttonDownBasicType buttonStyle:buttonPlainStyle animateToInitialState:YES];
        minimizeButton.tintColor = [UIColor whiteColor];
        [minimizeButton addTarget:self.delegate action:@selector(minimizeRoom) forControlEvents:UIControlEventTouchUpInside];
        //minimizeButton.hidden = YES;
        [self addSubview:minimizeButton];
        
        shareButton = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(self.bounds.size.width-28, 28, 20, 20) buttonType:buttonShareType buttonStyle:buttonPlainStyle animateToInitialState:NO];
        shareButton.tintColor = [UIColor whiteColor];
        [shareButton addTarget:self action:@selector(share) forControlEvents:UIControlEventTouchUpInside];
        //shareButton.hidden = YES;
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
        //lifetimeSlider.hidden = YES;
        [self addSubview:lifetimeSlider];

        labels = [[TGPCamelLabels alloc] initWithFrame:CGRectMake(20, 70, bounds.size.width-40, 25)];
        labels.names = ticks;
        //labels.hidden = YES;
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
        notificationSwitch.enabled = NO;
        [self addSubview:notificationSwitch];
        
        notificationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 44)];
        notificationLabel.text = @"Get notifications for new posts";
        [notificationLabel sizeToFit];
        [self addSubview:notificationLabel];
        
        removeButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
        [removeButton setTitle:@"Leave room" forState:UIControlStateNormal];
        [removeButton sizeToFit];
        removeButton.enabled = NO;
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
                notificationLabel.textColor = self.contrastColor;
                [removeButton setTitleColor:self.contrastColor forState:UIControlStateNormal];
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
        
        [self hideMoments];
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
        self.layer.cornerRadius = 3.0;
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

- (void)showMoments
{
    momentDisplayer = [[MomentsViewer alloc] init];
    momentDisplayer.frame = CGRectMake(0, 64, self.bounds.size.width, self.bounds.size.height-64);
    momentDisplayer.myRoom = self.room;
    //momentDisplayer.backgroundColor = [UIColor whiteColor];
    momentDisplayer.tableDelegate = self;
    
    RACSignal *hasMomentsToDisplay = [RACObserve(momentDisplayer.myRoom, moments)
                                map:^id(NSArray *moments) {
                                    return @(moments.count > 0);
                                }];
    
    RACSignal *createActiveSignal = [RACSignal combineLatest:@[hasMomentsToDisplay]
                                                      reduce:^id(NSNumber *isValid) {
                                                          return @([isValid boolValue]);
                                                      }];
    
    [createActiveSignal subscribeNext:^(NSNumber *isValid) {
        //allow saving
        if ([isValid boolValue] == YES) {
            //momentDisplayer.hidden = NO;
        } else {
            //momentDisplayer.hidden = YES;
        }
    }];
    
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

- (void)hideMoments
{
    [momentDisplayer removeFromSuperview];
    momentDisplayer = nil;
    
    [minimizeButton removeFromSuperview];
    [shareButton removeFromSuperview];
    [lifetimeSlider removeFromSuperview];
    [labels removeFromSuperview];
    [notificationSwitch removeFromSuperview];
    [notificationLabel removeFromSuperview];
    [removeButton removeFromSuperview];
    
    [self addSubview:membersOfRoom];
}

- (void)panningOnScroller:(UIGestureRecognizer*)recognizer
{
    NSLog(@"pan recognizer: %@", recognizer);
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == membersOfRoom) {
        return;
    }
    UIPanGestureRecognizer *recognizer = scrollView.panGestureRecognizer;
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        NSLog(@"contentoffset: %@, translation: %@", NSStringFromCGPoint(scrollView.contentOffset), NSStringFromCGPoint([recognizer translationInView:momentDisplayer]));
        if (scrollView.contentOffset.y < 0) {
            CGPoint newOffset = [recognizer translationInView:momentDisplayer];
            newOffset.x = 0;
            newOffset.y *= -1;
            scrollView.contentOffset = newOffset;
        } else {
            /*
            CGRect screenBounds = [[UIScreen mainScreen] bounds];
            CGPoint newOffset = [recognizer translationInView:momentDisplayer];
            CGFloat percentToMinimize = 1 - newOffset.y / screenBounds.size.height;
            NSLog(@"pulled down: %f", percentToMinimize);
            if (percentToMinimize > 0.5) {
                self.center = [recognizer locationInView:self.superview];
            }
            else {
                self.bounds = CGRectMake(0, 0, screenBounds.size.width * percentToMinimize, screenBounds.size.height * percentToMinimize);
            }
             */
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (scrollView == membersOfRoom) {
        return;
    }
    if (scrollView.contentOffset.y < 0 && scrollView.contentOffset.y > -150) {
        /*
        CGPoint center = momentDisplayer.center;
        center.y += scrollView.contentOffset.y * -1;
        momentDisplayer.center = center;
        targetContentOffset->y = 0;
        scrollView.contentOffset = CGPointMake(0, 0);
         */
    }
    NSLog(@"velocity: %@ at %@", NSStringFromCGPoint(velocity), NSStringFromCGPoint(scrollView.contentOffset));
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

@end
