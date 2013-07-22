//
//  AppDelegate.h
//  testApp
//
//  Created by Ian Koenigsknecht on 7/15/13.
//  Copyright (c) 2013 BU. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (strong, nonatomic) NSString* storedSearchString;
@property (strong, nonatomic) NSMutableArray* tableDataArray;
@property (strong, nonatomic) NSMutableArray* thumbnailDataArray;

@end
