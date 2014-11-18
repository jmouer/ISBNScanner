//
//  ViewController.h
//  ISBNScanner
//
//  Created by Jim Mouer on 5/28/14.
//  Copyright (c) 2014 jmouer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "semantics3-objc/semantics3_objc.h"

@interface ViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate>

@property (weak,nonatomic) IBOutlet UIView *viewPreview;
@property (weak,nonatomic) IBOutlet UILabel *statusLabel;
@property (weak,nonatomic) IBOutlet UIButton *startStopButton;
@property (weak,nonatomic) IBOutlet UIButton *searchButton;

@property (strong,nonatomic) IBOutlet UIView *detailView;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *authorsLabel;
@property (weak, nonatomic) IBOutlet UILabel *ratingsLabel;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImage;
@property (weak, nonatomic) IBOutlet UILabel *priceLabel;

- (IBAction)openPurchaseURL:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIButton *purchaseURLButton;

-(IBAction)showDetailView:(UIButton *)sender;
-(IBAction)returnToDefaultView:(UIButton *)sender;
-(IBAction)openURL:(UIButton *)sender;

-(IBAction)startStopReading:(id)sender;


@end