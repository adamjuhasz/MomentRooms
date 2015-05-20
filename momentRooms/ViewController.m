//
//  ViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 5/20/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "ViewController.h"
#import <Moment/Moment.h>
#import <Parse/Parse.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    MomentFilter *demoFilter = [MomentFilter filterWithName:@"blockOut"];
    Moment *demo = [[Moment alloc] init];
    demo.filter = demoFilter;
    demo.image = [UIImage imageNamed:@"demo"];
    demoFilter.filterValue = 0.5;
    self.demoImageView.image = demo.filteredImage;
    
    PFObject *testObject = [PFObject objectWithClassName:@"TestObject"];
    testObject[@"foo"] = @"bar";
    [testObject saveInBackground];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
