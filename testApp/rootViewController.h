//
//  ViewController.h
//  RocksauceTestApp
//
//  Created by Ian Koenigsknecht on 7/15/13.
//  Copyright (c) 2013 BU. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SBJsonStreamParser;
@class SBJsonStreamParserAdapter;

@interface rootViewController : UIViewController
{
    NSURLConnection *redditConn;
    SBJsonStreamParser *parser;
    SBJsonStreamParserAdapter *adapter;
}

@property (strong, nonatomic) NSString* searchString;
@property (strong, nonatomic) NSString* urlString;
@end
