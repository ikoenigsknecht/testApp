//
//  ViewController.m
//  testApp
//
//  Created by Ian Koenigsknecht on 7/16/13.
//  Copyright (c) 2013 Ian Koenigsknecht. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "SBJson.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "QuartzCore/CALayer.h"
#import "PullRefreshTableViewController.h"

@interface ViewController () <SBJsonStreamParserAdapterDelegate,UISearchBarDelegate,UITableViewDelegate,UITableViewDataSource,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate,UIScrollViewDelegate>
@end

@implementation ViewController
@synthesize subredditSearchBar;
@synthesize postDisplayTable;
@synthesize backgroundImageView;
@synthesize mainView;
@synthesize searchString;
@synthesize urlString;

UIButton *emailButton;
UIButton *smsButton;
UIButton *closeButton;
UIImageView *shareWindow;

//these parameters are used for creating the text labels for each UITableViewCell
#define CELL_WIDTH 320.0f
#define CELL_MARGIN 70.0f
#define REFRESH_HEADER_HEIGHT 52.0f

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [postDisplayTable setDelegate:self];
    [postDisplayTable setDataSource:self];
    [subredditSearchBar setDelegate:self];
    
    //set the search bar text
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    tableDataArray = [[NSMutableArray alloc] init];
    [self setSearchBarText:subredditSearchBar text:appDelegate.storedSearchString];
    [self handleSearch:subredditSearchBar];
    postDisplayTable.scrollEnabled = TRUE;
    
    //make the views clear and hide the table (will reappear when the data is initially loaded)
    mainView.backgroundColor = [UIColor clearColor];
    postDisplayTable.backgroundColor = [UIColor clearColor];
    postDisplayTable.hidden = TRUE;
    
    //initialize a single tap gesture for use on the 'shareWindow'
    UITapGestureRecognizer *tapGestureRecognize = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureRecognizer:)];
    tapGestureRecognize.delegate = self;
    tapGestureRecognize.numberOfTapsRequired = 1;
    [self.mainView addGestureRecognizer:tapGestureRecognize];
    
    [self addPullToRefreshHeader];
}

- (void)viewDidUnload
{
    [self setSubredditSearchBar:nil];
    [self setPostDisplayTable:nil];
    [super viewDidUnload];
    
    //store the current search string
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.storedSearchString = subredditSearchBar.text;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

//perform a search and close the keyboard when the search button is pressed
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self handleSearch:self.subredditSearchBar];
    [postDisplayTable setUserInteractionEnabled:TRUE];
}

//set the search string when the text bar is not being edited
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [self setSearchBarText:searchBar text:searchBar.text];
    [postDisplayTable setUserInteractionEnabled:TRUE];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [postDisplayTable setUserInteractionEnabled:FALSE];
}

//this function handles the initial retrieval of json data from reddit.com
- (void)handleSearch:(UISearchBar *)searchBar {
    //create the parser and adapter
    adapter = [[SBJsonStreamParserAdapter alloc] init];
    parser = [[SBJsonStreamParser alloc] init];
    adapter.delegate = self;
    parser.delegate = adapter;
    parser.supportMultipleDocuments = YES;
    
    //create a request and pull the json data packet
    urlString = [NSString stringWithFormat:@"http://www.reddit.com/r/%@/.json",searchBar.text]; //set the url to retrieve from
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         //if there is data and no error, save the data and load it
         if ([data length] > 0 && error == nil) {
             AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
             appDelegate.tableDataArray = [[NSMutableArray alloc] init];
             [self loadDownloadedData:data];
         }
         //else, print errors
         else if ([data length] == 0 && error == nil)
             NSLog(@"There was no data retrieved");
         else if (error != nil)
             NSLog(@"The following error occurred while loading data from %@: %@",urlString,error);
     }];
    //release the keyboard
    [searchBar resignFirstResponder];
}

//release the keyboard if the cancel button is clicked
- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar {
    [searchBar resignFirstResponder];
}

//function for setting the search bar text field
- (void)setSearchBarText:(UISearchBar *)searchBar text:(NSString *)searchText {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.storedSearchString = searchBar.text;
}

//when data is downloaded via the request in 'handleSearch', parse the data 
- (void)loadDownloadedData:(NSData *)data {
    SBJsonStreamParserStatus status = [parser parse:data];
    if (status == SBJsonStreamParserError) {
        [self performSelectorOnMainThread:@selector(displaySearchAlert) withObject:nil waitUntilDone:NO]; //display an alert view to let them know they goofed
    }
}

//create an alert view when the user enters in an incorrect subreddit name
- (void)displaySearchAlert {
    NSLog(@"An error occurred while parsing the data from %@",urlString); //nslog nonsense
    
    //display the alert view
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"You did not enter a valid subreddit string" delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil];
    [alertView show];
}

//error condition for the parser
- (void)parser:(SBJsonStreamParser *)parser foundArray:(NSArray *)array {
    [NSException raise:@"unexpected" format:@"Should not get here"];
}

//when a dictionary object is found while parsing, run this...
//this function breaks the parsed dictionary into its sub-dictionary objects and stores each entry in an array
- (void)parser:(SBJsonStreamParser *)parser foundObject:(NSDictionary *)dict {
    if ([dict objectForKey:@"data"] != nil) { //if the data is not nil...
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSDictionary *dataDict = [dict objectForKey:@"data"];
        appDelegate.thumbnailDataArray = [[NSMutableArray alloc] init];
        NSArray *array = [dataDict objectForKey:@"children"]; //this dictionary object contains a number of 'data' JSON entries that correspond to each post
        for (int i = 0; i < [array count]; i++) { //search through the array and store each post's entry into the array
            NSDictionary *tempDict = [array objectAtIndex:i];
            NSDictionary *tempDict1 = [tempDict objectForKey:@"data"];
            [appDelegate.tableDataArray addObject:tempDict1];
            
            NSString *tl = [tempDict1 objectForKey:@"thumbnail"];
            if (tl != nil && ![tl isEqualToString:@"nsfw"] && ![tl isEqualToString:@""]) {
                NSURL *url = [NSURL URLWithString:tl];
                NSData *data = [NSData dataWithContentsOfURL:url];
                
                //check if the thumbnail link actually returned data...if it didn't, set the thumbnail to a default image
                if ([data length] > 0) {
                    [appDelegate.thumbnailDataArray addObject:[[UIImage alloc] initWithData:data]];
                } else {
                    [appDelegate.thumbnailDataArray addObject:[UIImage imageNamed:@"no_photo_available.jpg"]];
                }
                //if the thumbnail is excluded because the post is "nsfw", set the thumbnail to a default image
            } else if ([tl isEqualToString:@"nsfw"]) {
                [appDelegate.thumbnailDataArray addObject:[UIImage imageNamed:@"no_photo_available.jpg"]];
                //if there is no thumbnail provided, set the thumbnail to a default image
            } else if (tl == nil || [tl isEqualToString:@""]) {
                [appDelegate.thumbnailDataArray addObject:[UIImage imageNamed:@"no_photo_available.jpg"]];
            }
        }
        [self reloadTable]; //reload the table now that we have a newly populated array
        [postDisplayTable setContentOffset:CGPointZero animated:YES];
    }
}

///////////////////////////////////
//// UITable Functions - Begin ////

//reload the table data and display the table if it was previously hidden
- (void)reloadTable
{
    if (postDisplayTable.hidden == TRUE)
        postDisplayTable.hidden = FALSE;
    [postDisplayTable reloadData];
}

//determine the lenght of the table
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return appDelegate.tableDataArray.count;
}

//this function creates each table cell based on the data in the previously populated array
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:nil]; //initialize the cell

    //initialize some label and view objects
    UILabel *userLabel = nil;
    UILabel *titleLabel = nil;
    UIImage *thumbnail = nil;
    UIImageView *thumbnailView = nil;
    
    //initial setup of labels
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil]; //reuse cells if possible
        
        //userLabel prints the name of the reddit user associated with the current post
        userLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [userLabel setLineBreakMode:UILineBreakModeWordWrap];
        userLabel.backgroundColor = [UIColor clearColor];
        userLabel.textAlignment =  UITextAlignmentLeft;
        [[cell contentView] addSubview:userLabel];
        
        //titleLabel prints the title of the current post
        titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [titleLabel setLineBreakMode:UILineBreakModeWordWrap];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = UITextAlignmentLeft;
        [[cell contentView] addSubview:titleLabel];
    }
    
    [userLabel setNumberOfLines:0];
    [titleLabel setNumberOfLines:0];
    
    //pull the dictionary object from the current index of the array and pull out the username, title and thumbnail url entries
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSDictionary *tempDict = [appDelegate.tableDataArray objectAtIndex:indexPath.row];
    author = [tempDict objectForKey:@"author"];
    title = [tempDict objectForKey:@"title"];
    thumbnailLink = [tempDict objectForKey:@"thumbnail"];
    
    //determine the size of each text label
    CGSize constraint = CGSizeMake(CELL_WIDTH - CELL_MARGIN, CGFLOAT_MAX);
    CGSize sizeAuthor = [author sizeWithFont:[UIFont fontWithName:@"Bebas Neue" size:20] 
                           constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    CGSize sizeTitle = [title sizeWithFont:[UIFont systemFontOfSize:14] 
                         constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    
    //determine height of the current table cell
    float combinedHeight = sizeTitle.height + sizeAuthor.height + 15.0f;
    combinedHeight = MAX(combinedHeight, 60.0f);
    float temp = combinedHeight - 50.0f;
    temp = temp / 2.0f;
    
    //set the remaining parameters of the userLabel and size it to fit the text
    [userLabel setText:author];
    [userLabel setFont:[UIFont fontWithName:@"Bebas Neue" size:20]];
    [userLabel setTextColor:[UIColor greenColor]];
    [userLabel setFrame:CGRectMake(CELL_MARGIN, 5.0f, CELL_WIDTH - CELL_MARGIN - 5.0f, sizeAuthor.height)];
    
    //set the remaining parameters of the titleLabel and size it to fit the text
    [titleLabel setText:title];
    [titleLabel setFont:[UIFont systemFontOfSize:14]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setFrame:CGRectMake(CELL_MARGIN, 5.0f + sizeAuthor.height, sizeTitle.width, sizeTitle.height+5.0f)];
    
    thumbnail = [appDelegate.thumbnailDataArray objectAtIndex:indexPath.row];
    
    //create the thumbnailView
    CGSize size = CGSizeMake(50.0f, 50.0f);
    thumbnail = [self imageWithImage:thumbnail scaledToSize:size]; //resize the image
    thumbnailView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
    thumbnailView.image = thumbnail;
    thumbnailView.backgroundColor = [UIColor whiteColor];
    thumbnailView.clipsToBounds = YES;      //
    thumbnailView.layer.cornerRadius = 5.0; //these two lines round the corners of the thumbnail...it looks cleaner, in my opinion
    
    //create a container for the thumbnailView so the shadow can coexist with the rounded image
    UIView * containerView = [[UIView alloc] initWithFrame:CGRectMake(5.0f, 5.0f, 50.0f, 50.0f)];
    //create the shadow on the containerView
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(2,2);
    containerView.layer.shadowOpacity = 0.9;
    containerView.layer.shadowRadius = 5.0;
    containerView.clipsToBounds = NO;
    
    //add the thumbnailView as a subview of containerView...then add containerView as a subview of the cell's contentView
    [containerView addSubview:thumbnailView];
    [[cell contentView] addSubview:containerView];
    
    cell.backgroundColor = [UIColor clearColor]; //make the background of the cell clear so you can see the backgroundView
    
    return cell;
}

//determine the height of the current cell based on the height needed to fit the thumbnail, title and username
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    //pull the author and title from the JSON data array
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSDictionary *tempDict = [appDelegate.tableDataArray objectAtIndex:indexPath.row];
    author = [tempDict objectForKey:@"author"];
    title = [tempDict objectForKey:@"title"];
    
    //determine the size of the author and title labels
    CGSize constraint = CGSizeMake(CELL_WIDTH - CELL_MARGIN, CGFLOAT_MAX);
    CGSize sizeAuthor = [author sizeWithFont:[UIFont fontWithName:@"Bebas Neue" size:20] 
                           constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    CGSize sizeTitle = [title sizeWithFont:[UIFont systemFontOfSize:14] 
                                   constrainedToSize:constraint lineBreakMode:UILineBreakModeWordWrap];
    
    //calculate the height needed to fit everything in the cell and return that
    CGFloat height = sizeAuthor.height + sizeTitle.height + 17.0f;
    height = MAX(height, 62.0f);
    
    return height;
}

//this function sets the action performed when a cell is tapped
//when a cell is tapped, open the 'shareWindow' and allow the user to interact with it
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //initialize the shareWindow with the "shareCard" image
    shareWindow = [[UIImageView alloc] initWithFrame:CGRectMake((320.0f - 283.0f) / 2, (480.0f - 201.0f) / 2, 283.0f, 201.0f)];
    shareWindow.image = [UIImage imageNamed:@"shareCard.png"];
    [mainView addSubview:shareWindow];
    
    //initialize the emailButton with the "email" image
    emailButton = [[UIButton alloc] init];
    [shareWindow addSubview:emailButton];
    emailButton.frame = CGRectMake(8.0f, 73.0f, 268.0f, 48.0f);
    UIImage *temp = [self imageWithImage:[UIImage imageNamed:@"email.png"] scaledToSize:emailButton.frame.size];
    [emailButton setImage:temp forState:UIControlStateNormal];
    
    //initialize the smsButton with the "sms" image
    smsButton = [[UIButton alloc] init];
    [shareWindow addSubview:smsButton];
    smsButton.frame = CGRectMake(8.0f, 140.0f, 268.0f, 48.0f);
    temp = [self imageWithImage:[UIImage imageNamed:@"sms.png"] scaledToSize:smsButton.frame.size];
    [smsButton setImage:temp forState:UIControlStateNormal];
    
    //create a clear button in the top right corner for closing the shareWindow
    closeButton = [[UIButton alloc] init];
    [shareWindow addSubview:closeButton];
    closeButton.frame = CGRectMake(238.0f, 0.0f, 45.0f, 45.0f);
    closeButton.backgroundColor = [UIColor clearColor];
    
    //set the title variable to the title of the selected post for use in the sms/email applications
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSDictionary *tempDict = [appDelegate.tableDataArray objectAtIndex:indexPath.row];
    title = [tempDict objectForKey:@"title"];
    
    //remove the blue highlight from the selected cell
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //make the shareWindow the front-most view and give it the interaction
    [mainView bringSubviewToFront:shareWindow];
    [postDisplayTable setUserInteractionEnabled:FALSE];
    [shareWindow setUserInteractionEnabled:TRUE];
}

//// UITable Functions - End ////
/////////////////////////////////

////////////////////////////////////
//// Various Functions - Begins ////

//this function resizes an image
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

//when a gesture is performed, perform an action based on the view that it was performed in
- (void)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    //if the emailButton is pressed, open the email composition window to send the current post title to a friend
    if (touch.view == emailButton) {
        if ([MFMailComposeViewController canSendMail]) { //if an email account exists
            MFMailComposeViewController *emailController = [[MFMailComposeViewController alloc] init];
            emailController.mailComposeDelegate = self;
            
            [emailController setSubject:[NSString stringWithFormat:@"Check out this awesome Reddit post!"]];
            [emailController setMessageBody:[NSString stringWithFormat:@"%@",title] isHTML:YES];
            
            [self presentModalViewController:emailController animated:YES]; //open the email composition window
        } else { //show error message if no mail account is active
            messagingTypeIsEmail = TRUE;
            [self performSelectorOnMainThread:@selector(displayMessagingAlert) withObject:nil waitUntilDone:NO];
        }
    //if the smsButton is pressed, open the sms client to send the current post title to a friend via text
    } else if (touch.view == smsButton) {
        if ([MFMessageComposeViewController canSendText]) { //if the device can send text messages
            MFMessageComposeViewController *messageController = [[MFMessageComposeViewController alloc] init];
            messageController.messageComposeDelegate = self;
            
            [messageController setBody:[NSString stringWithFormat:@"Check out this awesome Reddit post:\n\n%@",title]];
            
            [self presentModalViewController:messageController animated:YES]; //open the sms client
        } else {
            messagingTypeIsEmail = FALSE;
            [self performSelectorOnMainThread:@selector(displayMessagingAlert) withObject:nil waitUntilDone:NO];
        }
    } else if (touch.view == closeButton) { //if the closeButton is pressed, hide the shareWindow and restore interaction to the main view
        [postDisplayTable setUserInteractionEnabled:TRUE];
        [shareWindow setUserInteractionEnabled:FALSE];
        shareWindow.hidden = TRUE;
    }
}

//create an alert for a messaging error
- (void)displayMessagingAlert {
    NSString *temp = [[NSString alloc] init];
    if (messagingTypeIsEmail) { temp = @"This requires an email account!"; } //change the message based on email or sms
    else { temp = @"This requires SMS service!"; }
    
    //display the alertview
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:temp delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil];
    [alertView show];
}

//this function closes the mail composition window when the user is done
- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

//this function closes the sms composition window when the user is done
- (void) messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    // Close the Text Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

//// Various Functions -  Ends ////
///////////////////////////////////

//////////////////////////////////////////
//// PushtoRefresh Functions - Begins ////

//the next three functions are basic initialization functions
- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        [self setupStrings];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        [self setupStrings];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil) {
        [self setupStrings];
    }
    return self;
}

//initialize the strings that are displayed when the view is pulled down, released, etc.
- (void)setupStrings{
    textPull = @"Pull down to refresh...";
    textRelease = @"Release to refresh...";
    textLoading = @"Loading...";
}

//create the refresh header
- (void)addPullToRefreshHeader {
    //initialize the view
    refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0 - REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
    refreshHeaderView.backgroundColor = [UIColor clearColor];
    
    //create the label (used to display the strings in 'setupStrings')
    refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, REFRESH_HEADER_HEIGHT)];
    refreshLabel.backgroundColor = [UIColor clearColor];
    refreshLabel.font = [UIFont boldSystemFontOfSize:12.0];
    refreshLabel.textAlignment = UITextAlignmentCenter;
    refreshLabel.textColor = [UIColor whiteColor];
    
    //create the arrow object
    refreshArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"arrow.png"]];
    refreshArrow.frame = CGRectMake(floorf((REFRESH_HEADER_HEIGHT - 27) / 2),
                                    (floorf(REFRESH_HEADER_HEIGHT - 44) / 2),
                                    27, 44);
    
    //create the loading progress spinner
    refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    refreshSpinner.frame = CGRectMake(floorf(floorf(REFRESH_HEADER_HEIGHT - 20) / 2), floorf((REFRESH_HEADER_HEIGHT - 20) / 2), 20, 20);
    refreshSpinner.hidesWhenStopped = YES;
    
    //add the label, arrow and spinner to the header view, then add the header view to the table's view
    [refreshHeaderView addSubview:refreshLabel];
    [refreshHeaderView addSubview:refreshArrow];
    [refreshHeaderView addSubview:refreshSpinner];
    [self.postDisplayTable addSubview:refreshHeaderView];
}

//called when the table is dragged
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (isLoading) return;
    isDragging = YES;
}

//called when the user is scrolling
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (isLoading) {
        // Update the content inset, good for section headers
        if (scrollView.contentOffset.y > 0)
            self.postDisplayTable.contentInset = UIEdgeInsetsZero;
        else if (scrollView.contentOffset.y >= -REFRESH_HEADER_HEIGHT)
            self.postDisplayTable.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
    } else if (isDragging && scrollView.contentOffset.y < 0) {
        // Update the arrow direction and label
        [UIView animateWithDuration:0.25 animations:^{
            if (scrollView.contentOffset.y < -REFRESH_HEADER_HEIGHT) {
                // User is scrolling above the header
                refreshLabel.text = self.textRelease;
                refreshArrow.transform = CGAffineTransformMakeRotation(M_PI); //flip the arrow upside down
            } else { 
                // User is scrolling somewhere within the header
                refreshLabel.text = self.textPull;
                refreshArrow.transform = CGAffineTransformMakeRotation(0); //flip the arrow back
            }
        }];
    }
}

//called when the user has stopped dragging the table
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (isLoading) return;
    isDragging = NO;
    if (scrollView.contentOffset.y <= -REFRESH_HEADER_HEIGHT) {
        // Released above the header
        [self startLoading]; //start refreshing when its released
    }
}

//start refreshing the view and show the loading progress spinner
- (void)startLoading {
    isLoading = YES;
    
    // Show the header
    [UIView animateWithDuration:0.3 animations:^{
        self.postDisplayTable.contentInset = UIEdgeInsetsMake(REFRESH_HEADER_HEIGHT, 0, 0, 0);
        refreshLabel.text = self.textLoading;
        refreshArrow.hidden = TRUE;
        [refreshSpinner startAnimating];
    }];
    
    // Refresh action!
    [self refresh];
}

//when the refresh is done, call this
- (void)stopLoading {
    isLoading = NO;
    
    // Hide the header
    [UIView animateWithDuration:0.3 animations:^{
        self.postDisplayTable.contentInset = UIEdgeInsetsZero;
        [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
    } 
                     completion:^(BOOL finished) {
                         [self performSelector:@selector(stopLoadingComplete)];
                     }];
}

//bring the arrow back and stop the spinner
- (void)stopLoadingComplete {
    // Reset the header
    refreshLabel.text = self.textPull;
    refreshArrow.hidden = FALSE;
    [refreshSpinner stopAnimating];
}

//reload the table and run the stopLoading function
- (void)refresh {
    [self reloadTable];
    [self performSelector:@selector(stopLoading) withObject:nil afterDelay:2.0];
}

@end

