//
//  RecentMomentsView.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/5/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "RecentMomentsView.h"
#import "MomentsCloud.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <Moment/MomentView.h>
#import "MomentViewWithRoom.h"

@interface RecentMomentsView () <UIScrollViewDelegate, MomentViewWithRoomDelegte>
{
    UIScrollView *scroller;
    NSMutableArray *momentViews;
    UIPageControl *pager;
}
@end

@implementation RecentMomentsView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        scroller = [[UIScrollView alloc] initWithFrame:self.bounds];
        scroller.pagingEnabled = YES;
        scroller.delegate = self;
        scroller.showsHorizontalScrollIndicator = scroller.showsVerticalScrollIndicator = NO;
        [self addSubview:scroller];
        
        momentViews = [NSMutableArray array];
        for (int i=0; i<5; i++) {
            CGRect aFrame = self.bounds;
            aFrame = CGRectOffset(aFrame, i*self.bounds.size.width, 0);
            MomentViewWithRoom *viewer = [[MomentViewWithRoom alloc] initWithFrame:aFrame];
            viewer.delegate = self;
            [momentViews addObject:viewer];
            [scroller addSubview:viewer];
        }
        
        pager = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, 40, 10)];
        pager.center = CGPointMake(self.bounds.size.width/2.0, self.bounds.size.height - (pager.bounds.size.height + 10));
        pager.pageIndicatorTintColor = [UIColor colorWithWhite:0.0 alpha:0.2];
        pager.currentPageIndicatorTintColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        pager.hidesForSinglePage = YES;
        [self addSubview:pager];
        
        MomentsCloud *theCloud = [MomentsCloud sharedCloud];
        [[RACObserve(theCloud, mostRecentMoments) throttle:2.0] subscribeNext:^(NSArray *recentMoments) {
            for (int i=0; i<MIN(recentMoments.count, momentViews.count); i++) {
                MomentViewWithRoom *aViewer = momentViews[i];
                aViewer.moment = recentMoments[i];
            }
            pager.numberOfPages = recentMoments.count;
            scroller.contentSize = CGSizeMake(scroller.bounds.size.width*recentMoments.count, scroller.bounds.size.height);
            [scroller scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }];
    }
    return self;
}

- (void)openRoom:(MomentRoom *)theRoom
{
    [self.delegate openRoom:theRoom];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageNumber = scrollView.contentOffset.x / self.bounds.size.width;
    pageNumber = round(pageNumber);
    pageNumber = MAX(0, pageNumber);
    pageNumber = MIN(pager.numberOfPages, pageNumber);
    pager.currentPage = pageNumber;
}

@end
