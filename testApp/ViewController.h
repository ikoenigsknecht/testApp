//
//  ViewController.h
//  testApp
//
//  Created by Ian Koenigsknecht on 7/16/13.
//  Copyright (c) 2013 Ian Koenigsknecht. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PullRefreshTableViewController.h"

@class SBJsonStreamParser;
@class SBJsonStreamParserAdapter;

@interface ViewController : PullRefreshTableViewController
{
    NSURLConnection *redditConn;
    SBJsonStreamParser *parser;
    SBJsonStreamParserAdapter *adapter;
    NSString *parsedString;
    NSString *author;
    NSString *title;
    NSString *thumbnailLink;
    NSMutableArray *tableDataArray;
    BOOL messagingTypeIsEmail;
}
@property (weak, nonatomic) IBOutlet UISearchBar *subredditSearchBar; //search bar
@property (weak, nonatomic) IBOutlet UITableView *postDisplayTable; //table
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView; //the background image
@property (weak, nonatomic) IBOutlet UIView *mainView; //main view
@property (strong, nonatomic) NSString* searchString;
@property (strong, nonatomic) NSString* urlString;
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
@end

