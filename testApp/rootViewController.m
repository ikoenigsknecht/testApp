//
//  ViewController.m
//  RocksauceTestApp
//
//  Created by Ian Koenigsknecht on 7/15/13.
//  Copyright (c) 2013 BU. All rights reserved.
//

#import "rootViewController.h"
#import "AppDelegate.h"
#import "SBJson.h"

@interface rootViewController () <SBJsonStreamParserAdapterDelegate,UISearchBarDelegate>

@end

@implementation rootViewController
@synthesize subredditSearchBar;
@synthesize postDisplayTable;
@synthesize searchString;
@synthesize urlString;

- (void)viewDidLoad
{
    [super viewDidLoad];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [self setSearchBarText:subredditSearchBar text:appDelegate.storedSearchString];
    [self.subredditSearchBar setDelegate:self];
}

- (void)viewDidUnload
{
    [self setSubredditSearchBar:nil];
    [self setPostDisplayTable:nil];
    [super viewDidUnload];
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.storedSearchString = subredditSearchBar.text;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self handleSearch:self.subredditSearchBar];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [self setSearchBarText:searchBar text:searchBar.text];
}

- (void)handleSearch:(UISearchBar *)searchBar {
    urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/%@/.json",searchBar.text];
    adapter = [[SBJsonStreamParserAdapter alloc] init];
    parser = [[SBJsonStreamParser alloc] init];
    adapter.delegate = self;
    parser.delegate = adapter;
    parser.supportMultipleDocuments = YES;
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
    {
        if ([data length] > 0 && error == nil)
            [self loadDownloadedData:data];
        else if ([data length] == 0 && error == nil)
            NSLog(@"There was no data retrieved");
        else if (error != nil)
            NSLog(@"The following error occurred while loading data from %@: %@",urlString,error);
    }];
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar {
    [searchBar resignFirstResponder];
}
     
- (void)setSearchBarText:(UISearchBar *)searchBar text:(NSString *)searchText {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.storedSearchString = searchBar.text;
}

- (void)loadDownloadedData:(NSData *)data {
    NSLog(@"%@",data);
    
}

@end
