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

@interface RecentMomentsView () <UIScrollViewDelegate>
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
        for (int i=0; i<4; i++) {
            CGRect aFrame = self.bounds;
            aFrame = CGRectOffset(aFrame, i*self.bounds.size.width, 0);
            MomentView *viewer = [[MomentView alloc] initWithFrame:aFrame];
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
        [RACObserve(theCloud, mostRecentMoments) subscribeNext:^(NSArray *recentMoments) {
            for (int i=0; i<recentMoments.count; i++) {
                MomentView *aViewer = momentViews[i];
                aViewer.moment = recentMoments[i];
            }
            pager.numberOfPages = recentMoments.count;
            scroller.contentSize = CGSizeMake(scroller.bounds.size.width*recentMoments.count, scroller.bounds.size.height);
        }];
    }
    return self;
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
