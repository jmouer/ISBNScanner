//
//  ViewController.m
//  ISBNScanner
//
//
//  Implements code from Appcoda.com
//
//  Created by Jim Mouer on 5/28/14.
//  Copyright (c) 2014 jmouer. All rights reserved.
//

#import "ViewController.h"
#define kGoogleAPIKey @"AIzaSyAqPvlwMX6wdwIaolC_iBh5J7LR2kVhEu0"
#define APP_ID @"689b63aa"
#define APP_KEY @"8a79e9dfc8df1c7c5b576a1490da0aea"


@interface ViewController ()
@property (nonatomic) BOOL isReading;
@property (strong,nonatomic) AVCaptureSession *captureSession;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *videoPreview;
-(BOOL)startReading;

@end

@implementation ViewController

NSString* bookID;
NSURL* bookPurchaseURL;

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view sendSubviewToBack:_detailView];
    _detailView.hidden = YES;
	_isReading = NO;
    _captureSession = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openPurchaseURL:(UIButton *)sender {
    if(bookPurchaseURL != nil)
        [[UIApplication sharedApplication] openURL:bookPurchaseURL];
}

- (IBAction)showDetailView:(UIButton *)sender {
    //Tests application when no input is available using a given ISBN
    //Fault in our Stars Test
    //[self.statusLabel setText:@"9780142424179"];
    //Muslim Empires test
    //[self.statusLabel setText:@"9780521691420"];
    //Hello World test
    //[self.statusLabel setText:@"9781617290923"];
    
    //prevents code from executing unless a barcode has been read
    if(![self.statusLabel.text isEqualToString:@"Barcode reader is not running"]){
        NSURL* googleURL = [self buildGoogleURL:self.statusLabel.text];
        NSURL* ihURL = [self buildIHURL:self.statusLabel.text];
        NSData* data = [self executeGoogleSearch:googleURL];
        NSData* data2 = [self executeIHSearch:ihURL];
        NSDictionary* bookInfoDictionary = [self parseGoogleJSON:data];
        NSDictionary* bookPurchaseInfo = [self parseIHJSON:data2];
        if(bookInfoDictionary == nil)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Search failed. Please try again."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        [self.view bringSubviewToFront:_detailView];
        _detailView.hidden = NO;
        
        //writes data contained in bookInfoDictionary to labels
        [self.titleLabel setText:[bookInfoDictionary objectForKey:@"Title"]];
        [self.authorsLabel setText:[NSString stringWithFormat:@"By %@",[bookInfoDictionary objectForKey:@"Authors"]]];
        if(![bookInfoDictionary objectForKey:@"NumberOfRatings"])
        {
            [self.ratingsLabel setText:@"No ratings available. Be the first to rate!"];
        }
        else
        {
            [self.ratingsLabel setText:[NSString stringWithFormat:@"%@ ratings with an average rating of %@/5.",[bookInfoDictionary objectForKey:@"NumberOfRatings"],[bookInfoDictionary objectForKey:@"AverageRating"]]];
        }
        if(bookPurchaseInfo == nil){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Price search failed. Please try again or proceed without price."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [self.priceLabel setText:@"Price not found"];
            self.purchaseURLButton.enabled = NO;
        }
        else{
            [self.priceLabel setText:[NSString stringWithFormat:@"Available for $%@ from %@",[bookPurchaseInfo objectForKey:@"price"],[bookPurchaseInfo objectForKey:@"retailer_name"]]];
            self.purchaseURLButton.enabled = YES;
        }
        UIImage* thumbnail = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[bookInfoDictionary objectForKey:@"thumbnail"]]]];
        UIImageView* thumbnailImage = [[UIImageView alloc] initWithImage:thumbnail];
        [self.thumbnailImage setImage:thumbnail];
        [self.subtitleLabel setText:[bookInfoDictionary objectForKey:@"Subtitle"]];
        
    }
}

- (IBAction)returnToDefaultView:(UIButton *)sender {
    _detailView.hidden = YES;
    [self.view sendSubviewToBack:_detailView];
}

- (IBAction)openURL:(UIButton *)sender {
    NSString* baseURL = [NSString stringWithFormat:@"http://books.google.com/books?id=%@&sitesec=reviews&rf=su:Goodreads",bookID];
    NSURL* reviewURL = [NSURL URLWithString:baseURL];
    [[UIApplication sharedApplication] openURL:reviewURL];
}

-(IBAction)startStopReading:(id)sender
{
    if(!_isReading)
    {
        if([self startReading])
        {
            [_startStopButton.titleLabel setText:@"Stop"];
            [_statusLabel setText:@"Scanning for barcode"];
        }
    }
    else
    {
        [self stopReading];
        [_startStopButton.titleLabel setText:@"Start"];
    }
    _isReading = !_isReading;
}

-(BOOL)startReading
{
    NSError *error;
    //creates capture device using the default video recorder
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    //throws error i.e. 'cannot record' if there is no input
    if(!input)
    {
        NSLog(@"%@", [error localizedDescription]);
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"%@",[error localizedDescription]]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    //creates the capture session with camera input
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession addInput:input];
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc]init];
    [_captureSession addOutput:captureMetadataOutput];
    
    //creates serial queue to process metadata
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    
    //places EAN13 metadata in an array
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeEAN13Code]];
    
    //creates video preview
    _videoPreview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_videoPreview setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [_videoPreview setFrame:_viewPreview.layer.bounds];
    [_viewPreview.layer addSublayer:_videoPreview];
    
    [_captureSession startRunning];
    
    [_startStopButton.titleLabel performSelectorOnMainThread:@selector(setText:) withObject:@"Stop" waitUntilDone:NO];
    
    return YES;
    
}

-(void)stopReading
{
    [_captureSession stopRunning];
    _captureSession = nil;
    
    [_videoPreview removeFromSuperlayer];
    
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    //checks if metadata array is populated with non-nil objects
    if(metadataObjects != nil && [metadataObjects count] > 0)
    {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        //checks that metadata type is correct
        if([[metadataObj type] isEqualToString:AVMetadataObjectTypeEAN13Code])
        {
            //writes metadata object to label
            [_statusLabel performSelectorOnMainThread:@selector(setText:) withObject:[metadataObj stringValue] waitUntilDone:NO];
            [self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            [_startStopButton.titleLabel performSelectorOnMainThread:@selector(setText:) withObject:@"Start" waitUntilDone:NO];
            _isReading = NO;
            
        }
    }
}

-(NSURL*)buildGoogleURL:(NSString *)search
{
    //Creates a URL using the search input and API key
    NSString* urlString = [NSString stringWithFormat:@"https://www.googleapis.com/books/v1/volumes?q=isbn%@%@&langRestrict=en&maxResults=1&printType=books&key=%@",@"%3A", search, kGoogleAPIKey];
    //converts the URL to a NSURL object for use in the query
    NSURL* googleRequestURL = [NSURL URLWithString:urlString];
    return googleRequestURL;
}

-(NSURL*)buildIHURL:(NSString*)search
{
    NSString* urlString = [NSString stringWithFormat:@"http://us.api.invisiblehand.co.uk/v1/products?ean=%@&sort=best_price&order=asc&app_id=%@&app_key=%@",search,APP_ID,APP_KEY];
    NSURL* ihRequestURL = [NSURL URLWithString:urlString];
    return ihRequestURL;
}


-(NSData*)executeGoogleSearch:(NSURL *)searchURL
{
    NSData* data = [[NSData alloc] initWithContentsOfURL:searchURL];
    return data;
}

-(NSData*)executeIHSearch:(NSURL*)searchURL
{
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:searchURL];
    NSHTTPURLResponse* responseCode = nil;
    NSError* error = [[NSError alloc]init];
    NSData* responseData = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&responseCode
                                                             error:&error];
    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %i.", searchURL, [responseCode statusCode]);
        return  nil;
    }
    
    return responseData;
}



-(NSDictionary*)parseIHJSON:(NSData*)data
{
    NSError* error;
    if(data == nil)
    {
        return nil;
    }
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSArray* results = [json objectForKey:@"results"];
    NSDictionary* topResult = [results objectAtIndex:0];
    NSDictionary* bestPage = [topResult objectForKey:@"best_page"];
    bookPurchaseURL = [NSURL URLWithString:[bestPage objectForKey:@"original_url"]];
    return bestPage;
}

-(NSDictionary*)parseGoogleJSON:(NSData*)data
{
    NSError* error;
    if(data == nil)
    {
        return nil;
    }
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSArray* topResult = [json objectForKey:@"items"];
    NSLog(@"%@",topResult);
    NSDictionary* book = [topResult objectAtIndex:0];
    bookID = [book objectForKey:@"id"];
    NSDictionary* bookInfo = [book objectForKey:@"volumeInfo"];
    
    NSString* bookTitle = [bookInfo objectForKey:@"title"];
    NSString* bookSubtitle;
    if([bookInfo objectForKey:@"subtitle"])
    {
        bookSubtitle = [bookInfo objectForKey:@"subtitle"];
    }
    else{
        bookSubtitle = @"";
    }
    NSArray* bookAuthorList = [bookInfo objectForKey:@"authors"];
    NSString* bookAuthor = [bookAuthorList componentsJoinedByString:@", "];
    NSNumber* averageRating = [bookInfo objectForKey:@"averageRating"];
    NSNumber* numberOfRatings = [bookInfo objectForKey:@"ratingsCount"];
    NSDictionary* imageLinks = [bookInfo objectForKey:@"imageLinks"];
    NSString* thumbnail = [imageLinks objectForKey:@"thumbnail"];
    
    NSDictionary* infoDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:bookTitle,@"Title",bookAuthor,@"Authors",bookSubtitle,@"Subtitle",bookID,@"ID",thumbnail,@"thumbnail",averageRating,@"AverageRating",numberOfRatings,@"NumberOfRatings", nil];
    return infoDictionary;
}



@end
