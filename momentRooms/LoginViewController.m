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

@interface LoginViewController ()
{
    JVFloatLabeledTextField *usernameField;
    NSArray *hiddenComponents;
}
@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    VBFPopFlatButton *addPhoto = [[VBFPopFlatButton alloc] initWithFrame:CGRectMake(0, 0, 80, 80) buttonType:buttonAddType buttonStyle:buttonRoundedStyle animateToInitialState:NO];
    addPhoto.center = CGPointMake(self.view.bounds.size.width/2.0, 150);
    addPhoto.roundBackgroundColor = [UIColor blueColor];
    addPhoto.hidden = YES;
    [self.view addSubview:addPhoto];
    
    CGFloat usernameInset = 40;
    usernameField = [[JVFloatLabeledTextField alloc] initWithFrame:CGRectMake(usernameInset, 250, self.view.bounds.size.width - usernameInset*2, 44)];
    [usernameField setPlaceholder:@"What is your name?" floatingTitle:@"name"];
    usernameField.hidden = YES;
    [self.view addSubview:usernameField];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(usernameInset, 250+44, self.view.bounds.size.width - usernameInset*2, 1)];
    line.backgroundColor = [UIColor lightGrayColor];
    line.hidden = YES;
    [self.view addSubview:line];
    
    UITextView *explanation = [[UITextView alloc] initWithFrame:CGRectMake(0, 310, self.view.bounds.size.width, 30)];
    explanation.text = @"We use digits to authenticate you using your phone number";
    [self.view addSubview:explanation];
    
    UIButton *save = [[UIButton alloc] initWithFrame:CGRectMake(usernameInset, 350, self.view.bounds.size.width - usernameInset*2, 44)];
    [save setTitle:@"Save" forState:UIControlStateNormal];
    [save setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [save addTarget:self action:@selector(save) forControlEvents:UIControlEventTouchUpInside];
    save.enabled = NO;
    save.hidden = YES;
    [self.view addSubview:save];
    
    hiddenComponents = @[addPhoto,usernameField,line, save];
    
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
    
    [current setUsername:usernameField.text];
    current[@"isNewDigitUser"] = @(NO);
    [current saveEventually];
    
    [self.parentViewController popController:self withSuccess:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //[usernameField becomeFirstResponder];
    [PFUser loginWithDigitsInBackground:^(PFUser *user, NSError *error) {
        if(!error){
            // do something with user
            PFUser *current = [PFUser currentUser];
            if ([current[@"isNewDigitUser"] boolValue] == YES) {
                for (UIView *view in hiddenComponents) {
                    view.hidden = NO;
                }
                [usernameField becomeFirstResponder];
            } else {
                [self.parentViewController popController:self withSuccess:nil];
            }
            [[MomentsCloud sharedCloud] setLoggedIn:YES];
        }
    }];
}


@end
