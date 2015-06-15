//
//  LoginViewController.m
//  momentRooms
//
//  Created by Adam Juhasz on 6/3/15.
//  Copyright (c) 2015 Adam Juhasz. All rights reserved.
//

#import "LoginViewController.h"
#import <Fabric/Fabric.h>
#import <DigitsKit/DigitsKit.h>
#import <JVFloatLabeledTextField/JVFloatLabeledTextField.h>
#import <VBFPopFlatButton/VBFPopFlatButton.h>
#import "PhotoSelectionViewController.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "MomentsCloud.h"
#import "PFUser+Digits.h"
#import "UIViewController+UIViewController_PushPop.h"
#import <ColorUtils/ColorUtils.h>

@interface LoginViewController ()
{
    JVFloatLabeledTextField *usernameField;
    NSArray *hiddenComponents;
    NSArray *firstComponents;
}
@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor colorWithString:@"#FFFFFF"];
    
    VBFPopFlatButton *addPhoto = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(0, 0, 80, 80) buttonType:buttonAddType buttonStyle:buttonRoundedStyle animateToInitialState:NO];
    addPhoto.center = CGPointMake(self.view.bounds.size.width/2.0, 150);
    addPhoto.roundBackgroundColor = [UIColor blueColor];
    //[self.view addSubview:addPhoto];
    
    CGFloat usernameInset = 10;
    usernameField = [[JVFloatLabeledTextField alloc] initWithFrame:CGRectMake(usernameInset, 362/2.0, self.view.bounds.size.width - usernameInset*2, 44)];
    [usernameField setPlaceholder:@"Your nickname" floatingTitle:@"nickname"];
    usernameField.tintColor = [UIColor colorWithString:@"#744EAA"];
    [self.view addSubview:usernameField];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(usernameField.frame), self.view.bounds.size.width, 0.5)];
    line.backgroundColor = [UIColor colorWithString:@"#A3A3A3"];
    
    [self.view addSubview:line];
    
    UIButton *save = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    save.frame = CGRectMake(10, CGRectGetMaxY(line.frame) + 10, self.view.bounds.size.width - 20, 45);
    save.layer.cornerRadius = 6.0;
    save.backgroundColor = [UIColor colorWithString:@"#744EAA"];
    [save setTitle:@"Save" forState:UIControlStateNormal];
    [save setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [save addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
    save.enabled = NO;
    [self.view addSubview:save];
    
    UITextView *explanation = [[UITextView alloc] initWithFrame:CGRectMake(0, 310, self.view.bounds.size.width, 30)];
    explanation.backgroundColor = self.view.backgroundColor;
    explanation.textAlignment = NSTextAlignmentCenter;
    explanation.text = @"We use Twitter Digits to authenticate you using a phone number";
    [explanation sizeToFit];
    [self.view addSubview:explanation];
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    startButton.frame = CGRectMake(10, CGRectGetMaxY(explanation.frame) + 10, self.view.bounds.size.width - 20, 45);
    startButton.layer.cornerRadius = 6.0;
    startButton.backgroundColor = [UIColor colorWithString:@"#744EAA"];
    [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startButton.center = CGPointMake(self.view.bounds.size.width/2.0, CGRectGetMaxY(explanation.frame) + startButton.bounds.size.height/2.0 + 10);
    [startButton setTitle:@"Start" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(loadDigits) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startButton];
    
    hiddenComponents = @[addPhoto,usernameField,line, save, addPhoto];
    firstComponents = @[startButton, explanation];
    
    for (UIView *view in hiddenComponents) {
        save.hidden = YES;
        line.hidden = YES;
        usernameField.hidden = YES;
    }
    
    RACSignal *validUsernameSignal = [usernameField.rac_textSignal
     map:^id(NSString *text) {
         return @(text.length > 2);
     }];
    
    RACSignal *signUpActiveSignal = [RACSignal combineLatest:@[validUsernameSignal]
                      reduce:^id(NSNumber *usernameValid) {
                          return @([usernameValid boolValue]);
                      }];
    
    [signUpActiveSignal subscribeNext:^(NSNumber *signupActive) {
        //allow saving
        if ([signupActive boolValue] == YES) {
            [save setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
            save.enabled = YES;
        } else {
            [save setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
            save.enabled = NO;
        }
    }];
}

- (void)save
{
    PFUser *current = [PFUser currentUser];
    if (current)
    current[@"nickname"] =  usernameField.text;
    current[@"isNewDigitUser"] = @(NO);
    [current save];
    
    [[MomentsCloud sharedCloud] setLoggedIn:YES];
    [self.parentViewController popController:self withSuccess:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    return;
}

- (void)loadDigits
{
    [PFUser loginWithDigitsInBackground:^(PFUser *user, NSError *error) {
        if(!error){
            // do something with user
            [user save];
            PFUser *current = [PFUser currentUser];
            if ([current[@"isNewDigitUser"] boolValue] == YES) {
                for (UIView *view in hiddenComponents) {
                    view.hidden = NO;
                }
                for (UIView *view in firstComponents) {
                    view.hidden = YES;
                }
                [usernameField becomeFirstResponder];
            } else {
                [[MomentsCloud sharedCloud] setLoggedIn:YES];
                [self.parentViewController popController:self withSuccess:nil];
            }
        }
    }];
}

@end
