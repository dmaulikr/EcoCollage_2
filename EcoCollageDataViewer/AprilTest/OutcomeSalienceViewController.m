//
//  AprilTestSecondViewController.m
//  AprilTest
//
//  Created by Tia on 4/7/14.
//  Copyright (c) 2014 Tia. All rights reserved.
//

#import "OutcomeSalienceViewController.h"
#import "AprilTestTabBarController.h"
#import "AprilTestSimRun.h"
#import "AprilTestVariable.h"
#import "FebTestIntervention.h"
#import "FebTestWaterDisplay.h"
#import "AprilTestEfficiencyView.h"
#import "AprilTestNormalizedVariable.h"
#import "AprilTestCostDisplay.h"
#import "FavoriteView.h"
#import "LeastFavoriteView.h"

@interface OutcomeSalienceViewController ()

@end

@implementation OutcomeSalienceViewController
@synthesize studyNum = _studyNum;
@synthesize url = _url;
@synthesize dataWindow = _dataWindow;
@synthesize mapWindow = _mapWindow;
@synthesize titleWindow = _titleWindow;
@synthesize SliderWindow = _SliderWindow;
@synthesize loadingIndicator = _loadingIndicator;
@synthesize scenarioNames = _scenarioNames;
@synthesize SortPickerTextField = _SortPickerTextField;
@synthesize maxBudget = _maxBudget;

//structs that will keep track of the highest and lowest costs of Installation and maintenance (for convenience)
typedef struct Value
{
    float highestCost;
    float lowestCost;
}Value;

Value  *installationCost  = NULL;
Value  *maintenanceCost   = NULL;
Value  *privateDamages    = NULL;
Value  *impactNeighbors   = NULL;
Value  *neighborsImpactMe = NULL;
Value  *gw_infiltration   = NULL;
Value  *floodedStreets    = NULL;
Value  *standingWater     = NULL;
Value  *efficiency_val    = NULL;

NSArray *sortedArray;

NSMutableArray * trialRunSubViews;      //contains all subviews/visualizations added to UIview per trial
NSMutableArray * waterDisplays;
NSMutableArray * maxWaterDisplays;
NSMutableArray * efficiency;
NSMutableArray * lastKnownConcernProfile;
NSMutableArray * bgCols;
NSMutableArray * publicCostDisplays;
NSMutableArray * OverBudgetLabels;
NSMutableArray * favoriteLabels;
NSMutableArray * favoriteViews;
NSMutableArray * leastFavoriteViews;
NSMutableArray * interventionViews;

UILabel *redThreshold;
NSArray *arrStatus;
NSMutableDictionary *scoreColors;
int sortChosen = 0;
int lastMoved = 0;
int trialNum = 0;
int trialOffset = 0;
bool passFirstThree = FALSE;
float kOFFSET_FOR_KEYBOARD = 425.0;
float offsetForMoving = 0.0;
float originalOffset = 0.0;
UITextField *edittingTX;
NSTimer *scrollingTimer = nil;
UILabel  *investmentBudget;
UILabel  *interventionCap;
UILabel  *WaterDepthOverStorm;
UISlider *BudgetSlider;
UISlider *StormPlaybackWater;
UISlider *StormPlaybackInterv;
UIPickerView *SortType;
UITapGestureRecognizer *tapGestureRecognizer;

//Important values that change elements of objects
float thresh = 6;
int hours = 0;
int hoursAfterStorm;


//budget limits set by the application
NSString *minBudgetLabel;
NSString *maxBudgetLabel;
float maxBudgetLimit   = 150000;        //max budget set by user
float min_budget_limit = 0;
float max_budget_limit = 5000000;


//length of the budget bars set by the change in the budget slider
int dynamic_cd_width;
float maxPublicInstallNorm;

@synthesize currentConcernRanking = _currentConcernRanking;


// called everytime tab is switched to this view
// necessary in case currentSession changes, i.e. is disconnected and reconnected again
- (void)viewDidAppear:(BOOL)animated {
    
    //log switch in screens to log file
    AprilTestTabBarController *tabControl = (AprilTestTabBarController*)[self parentViewController];
    NSString *logEntry = [tabControl generateLogEntryWith:@"Switched To Outcome Salience View Screen"];
    NSLog(@"%@",logEntry);
    [tabControl writeToLogFileString:logEntry];
    
    [super viewDidAppear:animated];
    [self drawMultipleTrials];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    _currentConcernRanking = tabControl.currentConcernRanking;
    _studyNum = tabControl.studyNum;
    _url = tabControl.url;
    trialRunSubViews        = [[NSMutableArray alloc] init];
    waterDisplays           = [[NSMutableArray alloc] init];
    maxWaterDisplays        = [[NSMutableArray alloc] init];
    efficiency              = [[NSMutableArray alloc] init];
    _scenarioNames          = [[NSMutableArray alloc] init];
    publicCostDisplays      = [[NSMutableArray alloc] init];
    OverBudgetLabels        = [[NSMutableArray alloc] init];
    favoriteLabels          = [[NSMutableArray alloc] init];
    favoriteViews           = [[NSMutableArray alloc] init];
    leastFavoriteViews      = [[NSMutableArray alloc] init];
    interventionViews       = [[NSMutableArray alloc] init];
    
    _mapWindow.delegate = self;
    _dataWindow.delegate = self;
    _titleWindow.delegate = self;
    _SliderWindow.delegate = self;
    bgCols = [[NSMutableArray alloc] init];
    
    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _loadingIndicator.center = CGPointMake(512, 300);
    _loadingIndicator.color = [UIColor blueColor];
    [self.view addSubview:_loadingIndicator];

     arrStatus = [[NSArray alloc] initWithObjects:@"Trial Number", @"Best Score", @"Investment", @"Damage Reduction",@"Intervention Capacity", @"Water Depth over Storm", @"Max Flooded Area", @"Impact on my Neighbors", @"Efficiency of Intervention", @"Groundwater Infiltration", nil];
    
    _SortPickerTextField.text = [NSString stringWithFormat:@"%@", arrStatus[sortChosen]];
    _SortPickerTextField.delegate = self;
    
    if (SortType == nil){
        SortType = [[UIPickerView alloc] initWithFrame:CGRectMake(80, 120, 300, 100)];
        SortType.backgroundColor = [UIColor lightTextColor];
        SortType.layer.borderWidth = 1;
        [SortType setDataSource:self];
        [SortType setDelegate:self];
        [SortType setShowsSelectionIndicator:YES];
       
    }
    
    scoreColors = [[NSMutableDictionary alloc] initWithObjects:
                   [NSArray arrayWithObjects:
                     [UIColor colorWithHue:.3 saturation:.6 brightness:.9 alpha: 0.5],
                     [UIColor colorWithHue:.31 saturation:.6 brightness:.91 alpha: 0.5],
                     [UIColor colorWithHue:.32 saturation:.6 brightness:.92 alpha: 0.5],
                     [UIColor colorWithHue:.33 saturation:.6 brightness:.93 alpha: 0.5],
                     [UIColor colorWithHue:.35 saturation:.8 brightness:.6 alpha: 0.5],
                    [UIColor colorWithHue:.36 saturation:.8 brightness:.61 alpha: 0.5],
                    [UIColor colorWithHue:.37 saturation:.8 brightness:.62 alpha: 0.5],
                    [UIColor colorWithHue:.38 saturation:.8 brightness:.63 alpha: 0.5],
                     [UIColor colorWithHue:.4 saturation:.8 brightness:.3 alpha: 0.5],
                     [UIColor colorWithHue:.65 saturation:.8 brightness:.6 alpha: 0.5],
                     [UIColor colorWithHue:.6 saturation:.8 brightness:.3 alpha: 0.5],
                     [UIColor colorWithHue:.6 saturation:.0 brightness:.3 alpha: 0.5],
                     [UIColor colorWithHue:.6 saturation:.0 brightness:.9 alpha: 0.5],
                    [UIColor colorWithHue:.55 saturation:.8 brightness:.9 alpha: 0.5], nil]  forKeys: [[NSArray alloc] initWithObjects: @"publicCost", @"publicCostI", @"publicCostM", @"publicCostD", @"privateCost", @"privateCostI", @"privateCostM", @"privateCostD",  @"efficiencyOfIntervention", @"puddleTime", @"puddleMax", @"groundwaterInfiltration", @"impactingMyNeighbors", @"capacity", nil] ];
    
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    [self budgetUpdated];

    // automatically send Momma the favorited trial when connection begins
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendFavorite)
                                                 name:@"sendFavorite"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendLeastFavorite)
                                                 name:@"sendLeastFavorite"
                                               object:nil];
    
}


- (BOOL) textFieldShouldBeginEditing:(UITextField *)textView
{
    if (textView == _SortPickerTextField){
        SortType.frame = CGRectMake(80, 120, 300, SortType.frame.size.height);
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:.50];
        [UIView setAnimationDelegate:self];
        SortType.frame = CGRectMake(80, 120, 300, SortType.frame.size.height);
        [self.view addSubview:SortType];
        [UIView commitAnimations];
        return NO;
    }
    else{
        return YES;
    }
}

- (void) handleTapFrom: (UITapGestureRecognizer *)recognizer
{
    //Code to handle the gesture
    if ([SortType isHidden]){
        NSLog(@"View Doesn't Exist");
    }
    else{
        [SortType removeFromSuperview];
    }
}

- (void)doneTouched:(UIBarButtonItem *)sender
{
    // hide the picker view
    UIAlertView *alert= [[UIAlertView alloc] initWithTitle:@"Hey!!" message:@"Its Dynamic" delegate:self cancelButtonTitle:@"Just Leave" otherButtonTitles:nil, nil];
    [alert show];
    [SortType resignFirstResponder];
    
    // perform some action
    //Handle the sort afterwards
    [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];
    [self handleSort:(int)sortChosen];
    [_loadingIndicator stopAnimating];
}

- (void) viewWillAppear:(BOOL)animated{
    //[trialRuns removeAllObjects];
    //[waterDisplays removeAllObjects];
    //[efficiency removeAllObjects];
    
    sortedArray = [_currentConcernRanking sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                            NSInteger first = [(AprilTestVariable*)a currentConcernRanking];
                            NSInteger second = [(AprilTestVariable*)b currentConcernRanking];
                            if(first > second) return NSOrderedAscending;
                            else return NSOrderedDescending;
                            }];
    
    for (UIView *view in [_titleWindow subviews]){
        [view removeFromSuperview];
    }
    for( UIView *view in [_dataWindow subviews]){
        [view removeFromSuperview];
    }
    for (UIView *view in [_mapWindow subviews]){
        [view removeFromSuperview];
    }
    for (UIView *view in [_SliderWindow subviews]){
        [view removeFromSuperview];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawSingleTrial)
                                                 name:@"drawSingleTrial"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(drawMultipleTrials)
                                                 name:@"drawMultipleTrials"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(budgetUpdated)
                                                 name:@"updateBudget"
                                               object:nil];
    
  
    [super viewWillAppear:animated];
}

- (void) viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"drawSingleTrial" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"drawMultipleTrials" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"budgetChanged" object:nil];
    
    
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/*
- (IBAction)pullNextRun:(id)sender {
    [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];
    [self loadNextSimulationRun];
}*/

- (IBAction)NormTypeSwitched:(UISwitch *)sender {
    /**
      * Make Sure to update all displays/labels to reflect the change 
      */
    
    if ([sender isOn]){
        //alert= [[UIAlertView alloc] initWithTitle:@"Hey!!" message:@"Its Dynamic" delegate:self cancelButtonTitle:@"Just Leave" otherButtonTitles:nil, nil];
        [self removeBudgetLabels];
        [self normalizeAllandUpdateDynamically];
        [self handleSort:sortChosen];
    }
    else{
        //alert= [[UIAlertView alloc] initWithTitle:@"Hey!!" message:@"Its Static" delegate:self cancelButtonTitle:@"Just Leave" otherButtonTitles:nil, nil];
        [self removeBudgetLabels];
        [self normalizaAllandUpdateStatically];
        [self handleSort:sortChosen];
    }
  
}


-(void) removeBudgetLabels{
    for (int i = 0; i < OverBudgetLabels.count; i++){
        UILabel *label = [OverBudgetLabels objectAtIndex:i];
        [label removeFromSuperview];
    }
    [OverBudgetLabels removeAllObjects];
}

- (void) updateBudgetLabels{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    //remove all old labels
    [self removeBudgetLabels];
    
    
    int width = 0;
    for (int i = 0; i < _currentConcernRanking.count; i++){
        AprilTestVariable * currentVar =[sortedArray objectAtIndex:i];
        if ([currentVar.name compare: @"publicCost"] == NSOrderedSame)
            break;
        else
            width += currentVar.widthOfVisualization;
    }
    
    //create a new label for any trials that are over the budget
    for (int i = 0; i < trialRunSubViews.count; i++){
        //AprilTestSimRun *simRun = [trialRuns objectAtIndex:i];
        AprilTestSimRun *simRun= [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        
        if (simRun.publicInstallCost > maxBudgetLimit){
            UILabel *valueLabel;
            [self drawTextBasedVar:[NSString stringWithFormat: @"Over budget: $%@", [formatter stringFromNumber: [NSNumber numberWithInt: (int) (simRun.publicInstallCost-maxBudgetLimit)]] ] withConcernPosition:width+25 andyValue:i *175 + 80 andColor:[UIColor redColor] to:&valueLabel];
            
            [OverBudgetLabels addObject:valueLabel];
        }
    }
}


-(void)StormHoursChangedOutcome:(id)sender{
    UISlider *slider = (UISlider*)sender;
    hours= slider.value;
    StormPlaybackWater.value = hours;
    StormPlaybackInterv.value = hours;
    //-- Do further actions
    
    hoursAfterStorm = floorf(hours);
    if (hoursAfterStorm % 2 != 0) hoursAfterStorm--;
    
    interventionCap.text = [NSString stringWithFormat:@"Storm Playback: %@ hours", [NSNumber numberWithInt:hours]];
    WaterDepthOverStorm.text = [NSString stringWithFormat:@"Storm Playback: %@ hours", [NSNumber numberWithInt:hours]];
}

- (void)StormHoursChosenOutcome:(NSNotification *)notification {
    
    [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];
    
    NSMutableString * content = [NSMutableString alloc];
    /*
    for(int i = 0; i < trialRunSubViews.count; i++){
        //FebTestWaterDisplay * temp = (FebTestWaterDisplay *) [waterDisplays objectAtIndex:i];
        //AprilTestEfficiencyView * temp2 = (AprilTestEfficiencyView *)[efficiency objectAtIndex:i];
        //FebTestWaterDisplay * tempHeights = (FebTestWaterDisplay *) [maxWaterDisplays objectAtIndex: i];
        
        FebTestWaterDisplay * temp = [[trialRunSubViews objectAtIndex:i] objectForKey:@"WaterDisplay"];
        AprilTestEfficiencyView * temp2 = [[trialRunSubViews objectAtIndex:i] objectForKey:@"EfficiencyView"];
        FebTestWaterDisplay * tempHeights = [[trialRunSubViews objectAtIndex:i] objectForKey:@"MWaterDisplay"];
        
        [temp2 updateViewForHour:hoursAfterStorm];
        //[temp updateView:hoursAfterStorm];
        [temp fastUpdateView:hoursAfterStorm];
        [tempHeights updateView:48];
    }*/
    
    AprilTestTabBarController *tabControl = (AprilTestTabBarController*)[self parentViewController];
    for (int i = 0; i < [trialRunSubViews count]; i++){
        AprilTestSimRun *simRun = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        /*
        //update intervention capacity
        AprilTestEfficiencyView * temp2 = [[trialRunSubViews objectAtIndex:i] objectForKey:@"EfficiencyView"];
        [temp2 updateViewForHour:hoursAfterStorm];*/
        
        /* Update Intervention Capacity */
        [[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum] updateViewForHour:hoursAfterStorm];
        UIImageView *EfficiencyView = [[trialRunSubViews objectAtIndex:simRun.trialNum] valueForKey:@"EfficiencyView"];
        UIImage *newEfficiencyViewImage  = [[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum] viewforEfficiencyToImage];
        [EfficiencyView setImage:newEfficiencyViewImage];
        
        /* update water display */
        //Access the map from the tab controller and update with the newest hours on water depth
        ((FebTestWaterDisplay*)[tabControl.waterDisplaysInTab objectAtIndex:simRun.trialNum]).thresholdValue = thresh;
        [[tabControl.waterDisplaysInTab objectAtIndex:simRun.trialNum] fastUpdateView:hoursAfterStorm];
        
        //Update water depth image from the current trial
        UIImageView *waterDepthView = [[trialRunSubViews objectAtIndex:simRun.trialNum] valueForKey:@"WaterDepthView"];
        UIImage *newWaterDepth = [tabControl viewToImageForWaterDisplay:[tabControl.waterDisplaysInTab objectAtIndex:simRun.trialNum]];
        [waterDepthView setImage:newWaterDepth];
    }
    
    [_mapWindow setScrollEnabled:TRUE];
    [_dataWindow setScrollEnabled:TRUE];
    [_titleWindow setScrollEnabled:TRUE];
    [_loadingIndicator stopAnimating];
    
    
    NSDate *myDate = [[NSDate alloc] init];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH:mm:ss"];
    NSString *prettyVersion = [dateFormat stringFromDate:myDate];
    
    //if(notification == UIControlEventTouchUpInside || notification == UIControlEventTouchUpOutside){
    content = [content initWithFormat:@"%@\tHours after storm set to: %d",prettyVersion, hoursAfterStorm];
    
    //    NSLog(content);
    [content appendString:@"\n\n"];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile_simResults.txt"];
    
    //create file if it doesn't exist
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
        [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
    
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
    [file seekToEndOfFile];
    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];;
    //}
}



/**
  * Returns the width from the minimum end of a slider
  * to a particular value on the slider
  * 
  * Used to draw the budget labels underneath the budget slider
  */
- (int)getWidthFromSlider:(UISlider *)aSlider toValue:(float) value;
{
    if (value < aSlider.minimumValue){
        return 0;
    }
    
    float sliderRange = aSlider.frame.size.width - aSlider.currentThumbImage.size.width;
    float sliderOrigin = aSlider.frame.origin.x + (aSlider.currentThumbImage.size.width / 2.0);
    
    float sliderValueToPixels = (((value-aSlider.minimumValue)/(aSlider.maximumValue-aSlider.minimumValue)) * sliderRange) + sliderOrigin;
    float sliderValforZero    = ((0/(aSlider.maximumValue-aSlider.minimumValue)) * sliderRange) + sliderOrigin;
    
    int returnLocation = (int)sliderValueToPixels - (int)sliderValforZero;
    if (returnLocation == 0){
        return 1;
    }
    else if(returnLocation > 160){
        return 160;
    }
    else
        return returnLocation;
}

- (void)budgetUpdated {
    // method called when budget is updated from Momma
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    [self updateBudgetSliderTo:tabControl.budget];
    
    //update the width of the public install cost bars (make sure it isn't 0)
    dynamic_cd_width = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
    
    //only update all labels/bars if Static normalization is switched on
    if (!_DynamicNormalization.isOn){
        [self normalizaAllandUpdateStatically];
    }
}

//selector method that handles a change in value when budget changes (slider under titles)
-(void)BudgetChanged:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    int value = slider.value;
    //-- Do further actions
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    value = 1000.0 * floor((value/1000.0)+0.5);
    
    investmentBudget.text = [NSString stringWithFormat:@"Set Budget: $%@", [formatter stringFromNumber:[NSNumber numberWithInt:value]]];
    maxBudgetLimit = value;
    
    //update the width of the public install cost bars (make sure it isn't 0)
    dynamic_cd_width = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
    
    //only update all labels/bars if Static normalization is switched on
    if (!_DynamicNormalization.isOn){
        [self normalizaAllandUpdateStatically];
    }
}

//method that updates Budget slider with animation and writes the new value to a label WITHOUT making a change to the max set by the User
-(void) updateBudgetSliderTo: (float) newValue
{
    [BudgetSlider setValue:newValue animated:YES];
    maxBudgetLimit = newValue;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    investmentBudget.text = [NSString stringWithFormat:@"Set Budget: $%@", [formatter stringFromNumber:[NSNumber numberWithInt:newValue]]];
}

-(void) normalizaAllandUpdateStatically{
    trialNum = (int)[trialRunSubViews count];
    [self normalizeStatically];
    
    dynamic_cd_width = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
    [self updatePublicCostDisplays: trialNum];
    [self updateBudgetLabels];
    
    //updates the component scores
    for (int i = 0; i < trialNum; i++)
        [self updateComponentScore:i];
}

-(void) normalizeAllandUpdateDynamically{
    trialNum = (int)[trialRunSubViews count];
    [self normalizeDynamically];
    
    dynamic_cd_width = [self getWidthFromSlider:BudgetSlider toValue:installationCost->highestCost];
    [self updatePublicCostDisplays: trialNum];
    [self updateBudgetLabels];
    
    //updates the component scores
    for (int i = 0; i < trialNum; i++)
        [self updateComponentScore:i];
}

-(void) normalizeStatically
{
    for (int i = 0; i < trialRunSubViews.count; i++)
    {
        //AprilTestSimRun *someTrial = [trialRuns objectAtIndex:i];
        //AprilTestNormalizedVariable *someTrialNorm = [trialRunsNormalized objectAtIndex:i];
        AprilTestSimRun *someTrial = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        AprilTestNormalizedVariable *someTrialNorm = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialStatic"];
        
        if (maxBudgetLimit == 0){ maxBudgetLimit = .01; }
        
        //public cost
        someTrialNorm.publicInstallCost     = ((float)someTrial.publicInstallCost/(maxBudgetLimit));
        someTrialNorm.publicMaintenanceCost = ((float)someTrial.publicMaintenanceCost/(maxBudgetLimit));
    }
    
}

//will normalize the cost of installation and maintenance
- (void)normalizeDynamically
{
    if (installationCost  == NULL) { installationCost = (Value*)malloc(sizeof(Value));  }
    if (maintenanceCost   == NULL) { maintenanceCost = (Value*) malloc(sizeof(Value));  }
    if (privateDamages    == NULL) { privateDamages = (Value*)malloc(sizeof(Value));    }
    if (neighborsImpactMe == NULL) { neighborsImpactMe = (Value*)malloc(sizeof(Value)); }
    if (impactNeighbors   == NULL) { impactNeighbors = (Value*)malloc(sizeof(Value));   }
    if (gw_infiltration   == NULL) { gw_infiltration = (Value*) malloc(sizeof(Value));  }
    if (floodedStreets    == NULL) { floodedStreets = (Value*) malloc(sizeof(Value));   }
    if (standingWater     == NULL) { standingWater = (Value*) malloc(sizeof(Value));    }
    if (efficiency_val    == NULL) { efficiency_val = (Value*) malloc(sizeof(Value));   }
    
    //Obtain the min and max of the data elements found in a trial
    int i;
    for (i = 0; i < trialRunSubViews.count; i++)
    {
        //AprilTestSimRun  *someTrial     = [trialRuns objectAtIndex:i];
        //AprilTestNormalizedVariable *someTrialNorm = [trialRunsNormalized objectAtIndex:i];
        AprilTestSimRun *someTrial = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        AprilTestNormalizedVariable *someTrialNorm = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialStatic"];
        
        if (i == 0){
            installationCost->highestCost  =  someTrial.publicInstallCost;
            installationCost->lowestCost   =  someTrial.publicInstallCost;
            
            maintenanceCost->highestCost   =  someTrial.publicMaintenanceCost;
            maintenanceCost->lowestCost    =  someTrial.publicMaintenanceCost;
            
            privateDamages->highestCost    = someTrial.privateDamages;
            privateDamages->lowestCost     = someTrial.privateDamages;
            
            impactNeighbors->highestCost   = someTrial.impactNeighbors;
            impactNeighbors->lowestCost    = someTrial.impactNeighbors;
            
            neighborsImpactMe->highestCost = someTrial.neighborsImpactMe;
            neighborsImpactMe->lowestCost  = someTrial.neighborsImpactMe;
            
            gw_infiltration->highestCost   = someTrial.infiltration;
            gw_infiltration->lowestCost    = someTrial.infiltration;
            
            floodedStreets->highestCost    = someTrialNorm.floodedStreets;
            floodedStreets->lowestCost     = someTrialNorm.floodedStreets;
            
            standingWater->highestCost     = someTrialNorm.standingWater;
            standingWater->lowestCost      = someTrialNorm.standingWater;
            
            efficiency_val->highestCost    = someTrialNorm.efficiency;
            efficiency_val->lowestCost     = someTrialNorm.efficiency;
        }
        
        //public cost
        if (someTrial.publicMaintenanceCost <= maintenanceCost->lowestCost) { maintenanceCost->lowestCost = someTrial.publicMaintenanceCost; }
        if (someTrial.publicMaintenanceCost >= maintenanceCost->highestCost){ maintenanceCost->highestCost = someTrial.publicMaintenanceCost; }
        
        if (someTrial.publicInstallCost <= installationCost->lowestCost){ installationCost->lowestCost = someTrial.publicInstallCost; }
        if (someTrial.publicInstallCost >= installationCost->highestCost) { installationCost->highestCost = someTrial.publicInstallCost; }
        
        
        //private cost
        if (someTrial.privateDamages <= privateDamages->lowestCost){  privateDamages->lowestCost = someTrial.privateDamages; }
        if (someTrial.privateDamages >= privateDamages->highestCost){ privateDamages->highestCost = someTrial.privateDamages; }
        
        //neighbors
        if (someTrial.impactNeighbors <= impactNeighbors->lowestCost){  impactNeighbors->lowestCost = someTrial.impactNeighbors; }
        if (someTrial.impactNeighbors >= impactNeighbors->highestCost){ impactNeighbors->highestCost = someTrial.impactNeighbors; }
        
        if (someTrial.neighborsImpactMe <= neighborsImpactMe->lowestCost){ neighborsImpactMe->lowestCost = someTrial.neighborsImpactMe; }
        if (someTrial.neighborsImpactMe >= neighborsImpactMe->highestCost){neighborsImpactMe->highestCost = someTrial.neighborsImpactMe; }
        
        //infiltration
        if (someTrial.infiltration <= gw_infiltration->lowestCost){ gw_infiltration->lowestCost = someTrial.infiltration; }
        if (someTrial.infiltration >= gw_infiltration->highestCost){ gw_infiltration->highestCost = someTrial.infiltration; }
        
        //flooded streets
        if (someTrialNorm.floodedStreets <= floodedStreets->lowestCost){ floodedStreets->lowestCost = someTrialNorm.floodedStreets; }
        if (someTrialNorm.floodedStreets >= floodedStreets->highestCost){ floodedStreets->highestCost = someTrialNorm.floodedStreets; }
        
        //standing water
        if (someTrialNorm.standingWater <= standingWater->lowestCost) { standingWater->lowestCost = someTrialNorm.standingWater; }
        if (someTrialNorm.standingWater >= standingWater->highestCost){ standingWater->highestCost = someTrialNorm.standingWater;}
        
        //efficiency
        if (someTrialNorm.efficiency <= efficiency_val->lowestCost){ efficiency_val->lowestCost = someTrialNorm.efficiency; }
        if (someTrialNorm.efficiency >= efficiency_val->highestCost){ efficiency_val->highestCost = someTrialNorm.efficiency; }
        
    }

    printf("\n");
    
    /**
     * Avoid Division by 0 or any other issues that may cause errors during normalizations
     *
     */
    
    if (maintenanceCost->highestCost == 0){
        maintenanceCost->highestCost = 0.01;
    }
    else if (maintenanceCost->lowestCost == 0){
        maintenanceCost->lowestCost = 0.01;
    }
    
    if (installationCost->highestCost == 0){
        installationCost->highestCost = 0.01;
    }
    else if (installationCost->lowestCost == 0){
        installationCost->lowestCost = 0.01;
    }
    
    if (privateDamages->highestCost == 0){
        privateDamages->highestCost = 0.01;
    }
    else if (privateDamages->lowestCost == 0){
        privateDamages->lowestCost = 0.01;
    }
    
    if (impactNeighbors->highestCost > 1) {
        impactNeighbors->highestCost = 1;
    }
    else if( impactNeighbors->lowestCost <= 0){
        impactNeighbors->lowestCost = 0.01;
    }
    
    if (neighborsImpactMe->highestCost == 0) {
        neighborsImpactMe->highestCost = 0.01;
    }
    else if (neighborsImpactMe->lowestCost == 0){
        neighborsImpactMe->lowestCost = 0.01;
    }
    
    if (gw_infiltration->highestCost == 0){
        gw_infiltration->highestCost = 0.01;
    }
    else if (gw_infiltration->lowestCost == 0){
        gw_infiltration->lowestCost = 0.01;
    }
    
    if (floodedStreets->highestCost == 0){
        floodedStreets->highestCost = 0.01;
    }
    else if (floodedStreets->lowestCost == 0){
        floodedStreets->lowestCost =0.01;
    }
    
    if (standingWater->highestCost == 0){
        standingWater->highestCost = 0.01;
    }
    else if (standingWater->lowestCost == 0){
        standingWater->lowestCost = 0.01;
    }
    
    if (efficiency_val->highestCost == 0){
        efficiency_val->highestCost = 0.01;
    }
    else if (efficiency_val->lowestCost == 0){
        efficiency_val->lowestCost = 0.01;
    }
    
    
    //normalize all the variables in accordance to the max value of all current trials
    for (i = 0; i < trialRunSubViews.count; i++)
    {
        //AprilTestSimRun  *someTrial     = [trialRuns objectAtIndex:i];
        //AprilTestNormalizedVariable  *someTrialNorm = [trialRunsNormalized objectAtIndex:i];
        //AprilTestNormalizedVariable  *someTrialDyn  = [trialRunsDynNorm  objectAtIndex:i];
        
        AprilTestSimRun *someTrial = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        AprilTestNormalizedVariable *someTrialNorm = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialStatic"];
        AprilTestNormalizedVariable *someTrialDyn  = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialDynamic"];
        
        someTrialDyn.publicInstallCost     = (float)someTrial.publicInstallCost/installationCost->highestCost;
        someTrialDyn.publicMaintenanceCost = (float)someTrial.publicMaintenanceCost/maintenanceCost->highestCost;
        someTrialDyn.privateDamages        = (float)someTrial.privateDamages/privateDamages->highestCost;
        
        if (impactNeighbors->highestCost == impactNeighbors->lowestCost){ someTrialDyn.impactNeighbors = .5; }
        else
            someTrialDyn.impactNeighbors = ((someTrial.impactNeighbors - impactNeighbors->lowestCost)/ (impactNeighbors->highestCost - impactNeighbors->lowestCost));
        
        if (gw_infiltration->highestCost == gw_infiltration->lowestCost){ someTrialDyn.infiltration = .5; }
        else
            someTrialDyn.infiltration = ((someTrial.infiltration - gw_infiltration->lowestCost)/ (gw_infiltration->highestCost - gw_infiltration->lowestCost));
        
        if (neighborsImpactMe->highestCost == neighborsImpactMe->lowestCost){ someTrialDyn.neighborsImpactMe = .5; }
        else
            someTrialDyn.neighborsImpactMe = ((someTrial.neighborsImpactMe - neighborsImpactMe->lowestCost)/ (neighborsImpactMe->highestCost - neighborsImpactMe->lowestCost));
        
        if (floodedStreets->highestCost == floodedStreets->lowestCost) { someTrialDyn.floodedStreets = .5; }
        else
            someTrialDyn.floodedStreets = ((someTrialNorm.floodedStreets - floodedStreets->lowestCost) / (floodedStreets->highestCost - floodedStreets->lowestCost));
        
        if (standingWater->highestCost == standingWater->lowestCost) { someTrialDyn.standingWater = .5; }
        else
            someTrialDyn.standingWater = ((someTrialNorm.standingWater - standingWater->lowestCost) / (standingWater->highestCost - standingWater->lowestCost));
        
        if (efficiency_val->highestCost == efficiency_val->lowestCost) { someTrialDyn.efficiency = .5; }
        else
            someTrialDyn.efficiency = ((someTrialNorm.efficiency - efficiency_val->lowestCost) / (efficiency_val->highestCost - efficiency_val->lowestCost));
        
    }
}

//Updates the text of a UILabel (used to update labels after new trials are fetched)
- (NSMutableAttributedString *)myLabelAttributes:(NSString *)input{
    NSMutableAttributedString *labelAttributes = [[NSMutableAttributedString alloc] initWithString:input];
    return labelAttributes;
}

//updates the score of the public install costs to reflect new trial
- (void) updatePublicCostDisplays:(int) trial
{
    AprilTestCostDisplay        *newCD;
    AprilTestNormalizedVariable *normVar;
    AprilTestSimRun             *var;
    CGRect                      frame;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    float maxBudgetWidth = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
    
    for (int i = 0; i < trial; i++){
        newCD = [publicCostDisplays objectAtIndex:i];
        [newCD.budgetUsed removeFromSuperview];
        [newCD.budget removeFromSuperview];
        [newCD.budgetOver removeFromSuperview];
        [newCD.valueLabel removeFromSuperview];
        
        //var     = [trialRuns objectAtIndex:i];
        //normVar = (_DynamicNormalization.isOn) ? ([trialRunsDynNorm objectAtIndex:i]) : ([trialRunsNormalized objectAtIndex:i]);
        var = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialRun"];
        normVar = (_DynamicNormalization.isOn) ? ([[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialDynamic"]) : ([[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialStatic"]);
        
        frame   = CGRectMake(25, i*175 + 40, dynamic_cd_width, 30);
        float costWidth = [self getWidthFromSlider:BudgetSlider toValue:var.publicInstallCost];
        [newCD updateWithCost:var.publicInstallCost normScore: normVar.publicInstallCost costWidth:costWidth maxBudgetWidth:maxBudgetWidth andFrame:frame];
    }
    
}

- (void) updateComponentScore: (int) trial{
    //AprilTestSimRun *simRun = [trialRuns objectAtIndex:trial];
    //AprilTestSimRun *simRun = [[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialRun"];
    
    AprilTestNormalizedVariable *simRunNormal;
    
    if (_DynamicNormalization.isOn){
        //simRunNormal = [trialRunsDynNorm objectAtIndex:trial];
        simRunNormal = [[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialDynamic"];
    }
    else{
        //simRunNormal = [trialRunsNormalized objectAtIndex:trial];
        simRunNormal = [[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialStatic"];
    }
    
    float priorityTotal= 0;
    float scoreTotal = 0;
    
    for(int i = 0; i < _currentConcernRanking.count; i++){
        
        priorityTotal += [(AprilTestVariable *)[_currentConcernRanking objectAtIndex:i] currentConcernRanking];
    }
    
    int width = 0;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    NSMutableArray *scoreVisVals = [[NSMutableArray alloc] init];
    NSMutableArray *scoreVisNames = [[NSMutableArray alloc] init];
    
    int visibleIndex = 0;
    
    for(int i = 0 ; i <_currentConcernRanking.count ; i++){
        AprilTestVariable * currentVar =[sortedArray objectAtIndex:i];
        
        if([currentVar.name compare: @"publicCost"] == NSOrderedSame){
            float investmentInstallN = simRunNormal.publicInstallCost;
            float investmentMaintainN = simRunNormal.publicMaintenanceCost;
            
            scoreTotal += ((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentInstallN));
            scoreTotal += ((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentMaintainN));
            
            [scoreVisVals addObject:[NSNumber numberWithFloat:((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentInstallN))]];
            [scoreVisVals addObject:[NSNumber numberWithFloat:((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentMaintainN))]];
            
            [scoreVisNames addObject: @"publicCostI"];
            [scoreVisNames addObject: @"publicCostM"];
        }
        else if ([currentVar.name compare: @"privateCost"] == NSOrderedSame){
            
            scoreTotal += (currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages) + currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.neighborsImpactMe)) /2;
            
            [scoreVisVals addObject:[NSNumber numberWithFloat:(currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages) + currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.neighborsImpactMe)) /2]];
            
            [scoreVisNames addObject: @"privateCostD"];
            
        }
        else if ([currentVar.name compare: @"impactingMyNeighbors"] == NSOrderedSame){
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.impactNeighbors);
            [scoreVisVals addObject:[NSNumber numberWithFloat: currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.impactNeighbors)]];
            [scoreVisNames addObject: currentVar.name];
        }
        else if ([currentVar.name compare: @"neighborImpactingMe"] == NSOrderedSame){
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (simRunNormal.neighborsImpactMe);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * ( simRunNormal.neighborsImpactMe)]];
            [scoreVisNames addObject: currentVar.name];
        }
        else if ([currentVar.name compare: @"groundwaterInfiltration"] == NSOrderedSame){
           
            scoreTotal += (currentVar.currentConcernRanking/priorityTotal) * (simRunNormal.infiltration );
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * ( simRunNormal.infiltration )]];
            [scoreVisNames addObject: currentVar.name];
        }
        else if([currentVar.name compare:@"puddleTime"] == NSOrderedSame){
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.floodedStreets);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * (1- simRunNormal.floodedStreets)]];
            [scoreVisNames addObject: currentVar.name];
            
        }
        else if([currentVar.name compare:@"puddleMax"] == NSOrderedSame){
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.standingWater);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * (1- simRunNormal.standingWater)]];
            [scoreVisNames addObject: currentVar.name];
            
        }
        else if ([currentVar.name compare: @"capacity"] == NSOrderedSame){
        
            scoreTotal += currentVar.currentConcernRanking/priorityTotal *  simRunNormal.efficiency;
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal *  simRunNormal.efficiency]];
            [scoreVisNames addObject: currentVar.name];
        
            
        }
        else if ([currentVar.name compare: @"efficiencyOfIntervention"] == NSOrderedSame){
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * 1;
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * 0]];
            [scoreVisNames addObject:currentVar.name];
        }
        
        width+= currentVar.widthOfVisualization;
        if (currentVar.widthOfVisualization > 0) visibleIndex++;
    }

    //border around component score
    UILabel *fullValueBorder = [[UILabel alloc] initWithFrame:CGRectMake(148, (trial)*175 + 73,  114, 26)];
    fullValueBorder.backgroundColor = [UIColor grayColor];
    UILabel *fullValue = [[UILabel alloc] initWithFrame:CGRectMake(150, (trial)*175 + 75,  110, 22)];
    fullValue.backgroundColor = [UIColor whiteColor];
    [_mapWindow addSubview:fullValueBorder];
    [_mapWindow addSubview:fullValue];
    //NSLog(@" %@", scoreVisVals);
    float maxX = 150;
    float totalScore = 0;
    
    UILabel * componentScore;
    //computing and drawing the final component score
    for(int i =  0; i < scoreVisVals.count; i++){
        float scoreWidth = [[scoreVisVals objectAtIndex: i] floatValue] * 100;
        if (scoreWidth < 0) scoreWidth = 0.0;
        totalScore += scoreWidth;
        componentScore = [[UILabel alloc] initWithFrame:CGRectMake(maxX, (trial)*175 + 75, floor(scoreWidth), 22)];
        componentScore.backgroundColor = [scoreColors objectForKey:[scoreVisNames objectAtIndex:i]];
        [_mapWindow addSubview:componentScore];
        maxX+=floor(scoreWidth);
    }
    
    //update the length of the component (performance) score in order to be able to sort by best score
    NSNumber *newPerformanceScore = [NSNumber numberWithFloat:totalScore];
    NSDictionary *oldDictionary   = [trialRunSubViews objectAtIndex:trial];
    NSMutableDictionary *newDict = [[NSMutableDictionary alloc] init];
    [newDict addEntriesFromDictionary:oldDictionary];
    [newDict setObject:newPerformanceScore forKey:@"PerformanceScore"];
    [trialRunSubViews replaceObjectAtIndex:trial withObject:newDict];
}

/*
- (void)loadNextSimulationRun{
    
    //pull content from the server that is said to be from le trial with real vals
    NSString * urlPlusFile = [NSString stringWithFormat:@"%@/%@", _url, @"simOutput.php"];
    NSString *myRequestString = [[NSString alloc] initWithFormat:@"trialID=%d&studyID=%d", trialNum, _studyNum ];
    NSData *myRequestData = [ NSData dataWithBytes: [ myRequestString UTF8String ] length: [ myRequestString length ] ];
    NSMutableURLRequest *request = [ [ NSMutableURLRequest alloc ] initWithURL: [ NSURL URLWithString: urlPlusFile ] ];
    [ request setHTTPMethod: @"POST" ];
    [ request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
    [ request setHTTPBody: myRequestData ];
    
    NSString *content;
    while( !content){
        NSURLResponse *response;
        NSError *err;
        NSData *returnData = [ NSURLConnection sendSynchronousRequest: request returningResponse:&response error:&err];
        //NSLog(@"error: %@", err);
        
        if( [returnData bytes]) content = [NSString stringWithUTF8String:[returnData bytes]];
        NSLog(@"responseData: %@", content);
    }
    
    //pull content from the server that is said to be from le trial that is said to be normalized vals (ranging from 0 to 1)
    NSString *urlPlusFileN = [NSString stringWithFormat:@"%@/%@", _url, @"simOutputN.php"];
    NSString *myRequestStringN = [[NSString alloc] initWithFormat:@"trialID=%d&studyID=%d", trialNum, _studyNum ];
    NSData *myRequestDataN = [ NSData dataWithBytes: [ myRequestStringN UTF8String ] length: [ myRequestStringN length ] ];
    NSMutableURLRequest *requestN = [ [ NSMutableURLRequest alloc ] initWithURL: [ NSURL URLWithString: urlPlusFileN ] ];
    [ requestN setHTTPMethod: @"POST" ];
    [ requestN setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
    [ requestN setHTTPBody: myRequestDataN ];

    NSString *contentN;
    while( !contentN){
        NSURLResponse *responseN;
        NSError *err;
        NSData *returnDataN = [ NSURLConnection sendSynchronousRequest: requestN returningResponse:&responseN error:&err];
        //NSLog(@"error: %@", err);
        
        if( [returnDataN bytes]) contentN = [NSString stringWithUTF8String:[returnDataN bytes]];
       //NSLog(@"responseData: %@", contentN);
    }
    
    
    if(content != NULL && content.length > 100 && contentN != NULL){
        //Adds a new trial to a list of trials (normalized, real, dynamic)
        AprilTestSimRun *simRun = [[AprilTestSimRun alloc] init:content withTrialNum:trialNum];
        AprilTestNormalizedVariable *simRunNormal = [[AprilTestNormalizedVariable alloc] init: contentN withTrialNum:trialNum];
        AprilTestNormalizedVariable *simRunDyn    = [[AprilTestNormalizedVariable alloc] init: contentN withTrialNum:trialNum];
        
        [trialRuns addObject: simRun];                  //contains trials containing real values
        [trialRunsNormalized addObject:simRunNormal];   //contains trials containing normalized values
        [trialRunsDynNorm addObject:simRunDyn];         //contains normalized data that will be dynamically altered every time a new trial is fetched
        
        //draws the newest trial after latest normalization of data (static or dynamic)
        [self drawTrial: trialNum];
        trialNum++;
        
        //chooses between static/dynamic normalization of trial data
        if (_DynamicNormalization.isOn)
            [self normalizeAllandUpdateDynamically];
        else
            [self normalizeStatically];
        
        //update with the current sort chosen after a new trial is drawn
        [self handleSort: sortChosen];
        
        //automatically scroll to the bottom (subject to change since its a little to rapid a transformation... maybeee) UPDATE: Scroling was smoothened
        if (trialNum > 3){
            scrollingTimer = [NSTimer scheduledTimerWithTimeInterval:(0.10)
                                                              target:self selector:@selector(autoscrollTimerFired:) userInfo:nil repeats:NO];
        }
    }
 
}*/


//autoscroll to the bottom of the mapwindow (trial and component score) scrollview
- (void) autoscrollTimerFired: (NSTimer*)Timer
{
    NSNumber *trial = ((NSNumber*)[Timer userInfo]);
    int trialInt = (int)[trial integerValue];
    
    trialOffset = (trialInt - 3 < 0) ? 0 : (175 * (trialInt-3) + 35);
    
    //CGPoint bottomOffset = CGPointMake(0, _mapWindow.contentSize.height - _mapWindow.bounds.size.height);
    CGPoint bottomOffset = CGPointMake(0, trialOffset);
    [_mapWindow setContentOffset:bottomOffset animated:YES];
    
}

-(void) OffsetView: (UIView*) view toX:(int)x andY:(int)y{
    ///GENERAL FORMULA FOR TRANSLATING A FRAME
    CGRect frame = view.frame;
    frame.origin.x = x;
    frame.origin.y = y;
    [view setFrame: frame];
    /*
    CGRect frame = CGRectMake(x, y, view.frame.size.width, view.frame.size.height);
    [view setFrame: frame];*/
}

-(void) drawTrial: (int) trial{
    //UILabel *maintenance;
    UILabel *damage;
    UILabel *damageReduced;
    UILabel *sewerLoad;
    UILabel *impactNeighbor;
    UILabel *gw_infiltration;
    UILabel *efficiencyOfIntervention;
    
    
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    AprilTestSimRun *simRun = (trial < trialRunSubViews.count) ? ([[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialRun"])  : ([tabControl.trialRuns objectAtIndex:trial]);
    
    AprilTestNormalizedVariable *simRunNormal;
    //determines via UIswitch what type of normalization is being drawn
    if (_DynamicNormalization.isOn){
        simRunNormal = (trial < trialRunSubViews.count) ? ([[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialDynamic"])  : ([tabControl.trialRunsDynNorm objectAtIndex:trial]);
    }
    else{
        simRunNormal = (trial < trialRunSubViews.count) ? ([[trialRunSubViews objectAtIndex:trial] valueForKey:@"TrialStatic"]) :([tabControl.trialRunsNormalized objectAtIndex:trial]);
    }

    //creates a UIImageview of the intervention map OR finds it in the stored trials already loaded
    UIImageView *interventionImageView;
    if (trial >= [trialRunSubViews count]){
        UIView *tempView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 115, 125)];
        FebTestIntervention *interventionView = [[FebTestIntervention alloc] initWithPositionArray:simRun.map andFrame:tempView.frame];
        interventionView.view = tempView;
        [interventionView updateView];
        
        interventionImageView = [[UIImageView alloc] initWithFrame:(CGRectMake(20, 175 * (trial) + 40, 115, 125))];
        interventionImageView.image = [interventionView viewToImage];
        [interventionViews addObject:interventionImageView];
        [_mapWindow addSubview:interventionImageView];
    }
    else{
        interventionImageView = [interventionViews objectAtIndex:simRun.trialNum];
        interventionImageView.frame = CGRectMake(20, 175 * (trial) + 40, 115, 125);
        [_mapWindow addSubview:interventionImageView];
    }
    [_mapWindow setContentSize: CGSizeMake(_mapWindow.contentSize.width, (trial+1)*200)];
    
    //int scoreBar=0;
    float priorityTotal= 0;
    float scoreTotal = 0;
    
    for(int i = 0; i < _currentConcernRanking.count; i++){
        priorityTotal += [(AprilTestVariable *)[_currentConcernRanking objectAtIndex:i] currentConcernRanking];
    }
    
    UITextField *tx;
    if(trial >= [trialRunSubViews count]){
        tx = [[UITextField alloc] initWithFrame:CGRectMake(20, 175*(trial)+5, 245, 30)];
        tx.borderStyle = UITextBorderStyleRoundedRect;
        tx.font = [UIFont systemFontOfSize:15];
        tx.placeholder = @"enter text";
        tx.autocorrectionType = UITextAutocorrectionTypeNo;
        tx.keyboardType = UIKeyboardTypeDefault;
        tx.returnKeyType = UIReturnKeyDone;
        tx.clearButtonMode = UITextFieldViewModeWhileEditing;
        tx.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        tx.delegate = self;
        tx.text = [NSString stringWithFormat:  @"Trial %d", simRunNormal.trialNum];
        [_mapWindow addSubview:tx];
        [_scenarioNames addObject:tx];
    } else {
        tx = [_scenarioNames objectAtIndex:simRun.trialNum];
        tx.frame = CGRectMake(20, 175*(trial)+5, 245, 30);
        [_mapWindow addSubview:tx];
    }
    
    int width = 0;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    NSMutableArray *scoreVisVals = [[NSMutableArray alloc] init];
    NSMutableArray *scoreVisNames = [[NSMutableArray alloc] init];
    AprilTestCostDisplay *cd;
    //FebTestWaterDisplay * wd;
    //FebTestWaterDisplay * mwd;
    //AprilTestEfficiencyView *ev;
    UIImageView *waterDepthView;
    UIImageView *MaxWaterDepthView;
    UIImageView *efficiencyImageView;
    int visibleIndex = 0;
    
    for(int i = 0 ; i <_currentConcernRanking.count ; i++){
        
        AprilTestVariable * currentVar =[sortedArray objectAtIndex:i];
        if(trial == 0 && visibleIndex %2 == 0 && currentVar.widthOfVisualization > 0){
            UILabel *bgCol = [[UILabel alloc] initWithFrame:CGRectMake(width, -2, currentVar.widthOfVisualization+1, _dataWindow.contentSize.height + 100)];
            bgCol.backgroundColor = [UIColor whiteColor];
            bgCol.layer.borderColor = [UIColor lightGrayColor].CGColor;
            bgCol.layer.borderWidth = 2.0;
            [_dataWindow addSubview:bgCol];
            [bgCols addObject:bgCol];
        }
        
        
        //laziness: this is just the investment costs
        if([currentVar.name compare: @"publicCost"] == NSOrderedSame){
            float investmentInstall = simRun.publicInstallCost;
            //float investmentMaintain = simRun.publicMaintenanceCost;
            float investmentInstallN = simRunNormal.publicInstallCost;
            float investmentMaintainN = simRunNormal.publicMaintenanceCost;
            CGRect frame = CGRectMake(width + 25, trial*175 + 40, dynamic_cd_width, 30);
            
            
            if(publicCostDisplays.count <= trial){
                //NSLog(@"Drawing water display for first time");
                float costWidth = [self getWidthFromSlider:BudgetSlider toValue:simRun.publicInstallCost];
                float maxBudgetWidth = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
                
                cd = [[AprilTestCostDisplay alloc] initWithCost:investmentInstall normScore:investmentInstallN costWidth:costWidth maxBudgetWidth:maxBudgetWidth andFrame:frame];
                [_dataWindow addSubview: cd];
                [publicCostDisplays addObject:cd];
                
            } else {
                //NSLog(@"Repositioning water display");
                cd = [publicCostDisplays objectAtIndex:trial];
                cd.frame = CGRectMake(width + 25, trial*175 + 40, dynamic_cd_width, 30);
                [_dataWindow addSubview:cd];
            }
            
            
            //checks if over budget, if so, prints warning message
            if ((simRun.publicInstallCost > maxBudgetLimit) && (!_DynamicNormalization.isOn)){
                //store update labels for further use (updating over budget when using absolute val)
               
                UILabel *valueLabel;
                [self drawTextBasedVar:[NSString stringWithFormat: @"Over budget: $%@", [formatter stringFromNumber: [NSNumber numberWithInt: (int) (investmentInstall-maxBudgetLimit)]] ] withConcernPosition:width+25 andyValue:trial *175 + 80 andColor:[UIColor redColor] to:&valueLabel];
                
                [OverBudgetLabels addObject:valueLabel];
            }
            
            //removing maintenance component
            /*
            [self drawTextBasedVar: [NSString stringWithFormat:@"Maintenance Cost: $%@", [formatter stringFromNumber: [NSNumber numberWithInt:investmentMaintain ]]] withConcernPosition:width + 25 andyValue: (trial * 175) +100 andColor:[UIColor blackColor] to:&maintenance];*/
            
            
            scoreTotal += ((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentInstallN));
            scoreTotal += ((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentMaintainN));
            //scoreTotal += ((currentVar.currentConcernRanking/3.0)/priorityTotal * (1 - simRun.impactNeighbors));

            [scoreVisVals addObject:[NSNumber numberWithFloat:((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentInstallN))]];
            [scoreVisVals addObject:[NSNumber numberWithFloat:((currentVar.currentConcernRanking/2.0)/priorityTotal * (1 - investmentMaintainN))]];
            //[scoreVisVals addObject:[NSNumber numberWithFloat:((currentVar.currentConcernRanking/3.0)/priorityTotal * (1 - simRun.impactNeighbors))]];
            [scoreVisNames addObject: @"publicCostI"];
            [scoreVisNames addObject: @"publicCostM"];
            //[scoreVisNames addObject: @"publicCostD"];


            //just damages now
        } else if ([currentVar.name compare: @"privateCost"] == NSOrderedSame){

            
            [self drawTextBasedVar: [NSString stringWithFormat:@"Rain Damage: $%@", [formatter stringFromNumber: [NSNumber numberWithInt:simRun.privateDamages]]] withConcernPosition:width + 25 andyValue: (trial*175) +40 andColor:[UIColor blackColor] to:&damage];
            [self drawTextBasedVar: [NSString stringWithFormat:@"Damaged Reduced by: %@%%", [formatter stringFromNumber: [NSNumber numberWithInt: 100 -(int)(100*simRunNormal.privateDamages)]]] withConcernPosition:width + 25 andyValue: (trial*175) +70 andColor:[UIColor blackColor] to:&damageReduced];
            [self drawTextBasedVar: [NSString stringWithFormat:@"Sewer Load: %.2f%%", 100*simRun.neighborsImpactMe] withConcernPosition:width + 25 andyValue: (trial ) * 175 + 100 andColor:[UIColor blackColor] to:&sewerLoad];
            

            scoreTotal += (currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages) + currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.neighborsImpactMe)) /2;

            //add values for the score visualization
    
            [scoreVisVals addObject:[NSNumber numberWithFloat:(currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages) + currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.neighborsImpactMe)) /2]];
            //scoreTotal +=currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages);
            //[scoreVisVals addObject: [NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.privateDamages)]];
            [scoreVisNames addObject: @"privateCostD"];
            
        } else if ([currentVar.name compare: @"impactingMyNeighbors"] == NSOrderedSame){
            
            [self drawTextBasedVar: [NSString stringWithFormat:@"%.2f%% of rainwater", 100*simRun.impactNeighbors] withConcernPosition:width + 30 andyValue: (trial ) * 175 + 40 andColor:[UIColor blackColor] to:&impactNeighbor];
            [self drawTextBasedVar: [NSString stringWithFormat:@" run-off to neighbors"] withConcernPosition:width + 30 andyValue: (trial ) * 175 + 55 andColor:[UIColor blackColor] to:nil];
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.impactNeighbors);
            [scoreVisVals addObject:[NSNumber numberWithFloat: currentVar.currentConcernRanking/priorityTotal * (1-simRunNormal.impactNeighbors)]];
            [scoreVisNames addObject: currentVar.name];
        } else if ([currentVar.name compare: @"neighborImpactingMe"] == NSOrderedSame){
            
            [self drawTextBasedVar: [NSString stringWithFormat:@"%.2f%%", 100*simRun.neighborsImpactMe] withConcernPosition:width + 50 andyValue: (trial)*175 + 40 andColor:[UIColor blackColor] to:nil];
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * ( simRunNormal.neighborsImpactMe);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * ( simRunNormal.neighborsImpactMe)]];
            [scoreVisNames addObject: currentVar.name];
        } else if ([currentVar.name compare: @"groundwaterInfiltration"] == NSOrderedSame){

            [self drawTextBasedVar: [NSString stringWithFormat:@"%.2f%% of rainwater was", 100*simRun.infiltration] withConcernPosition:width + 30 andyValue: (trial)* 175 + 40 andColor:[UIColor blackColor] to:&gw_infiltration];
            [self drawTextBasedVar: [NSString stringWithFormat:@" infiltrated by the swales"] withConcernPosition:width + 30 andyValue: (trial)* 175 + 55  andColor:[UIColor blackColor] to:nil];
            
            scoreTotal += (currentVar.currentConcernRanking/priorityTotal) * (simRunNormal.infiltration );
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * ( simRunNormal.infiltration )]];
            [scoreVisNames addObject: currentVar.name];
        } else if([currentVar.name compare:@"puddleTime"] == NSOrderedSame){
            
            AprilTestTabBarController *tabControl = (AprilTestTabBarController*)[self parentViewController];
        
            //Moved to creating UIImageViews... to minimize lag in scrolling
            ((FebTestWaterDisplay*)[tabControl.waterDisplaysInTab objectAtIndex:simRun.trialNum]).thresholdValue = thresh;
            [[tabControl.waterDisplaysInTab objectAtIndex:trial] fastUpdateView:hoursAfterStorm];
            
            waterDepthView = [[UIImageView alloc]initWithFrame:CGRectMake(width + 10, (trial)*175 + 40, 115, 125)];
            waterDepthView.image = [tabControl viewToImageForWaterDisplay:[tabControl.waterDisplaysInTab objectAtIndex:simRun.trialNum]];
            [_dataWindow addSubview:waterDepthView];
            
            /*
            //NSLog(@"%d, %d", waterDisplays.count, i);
            if(waterDisplays.count <= trial){
                //NSLog(@"Drawing water display for first time");
                wd = [[FebTestWaterDisplay alloc] initWithFrame:CGRectMake(width + 10, (trial)*175 + 40, 115, 125) andContent:simRun.standingWater];
                wd.view = _dataWindow;
                [waterDisplays addObject:wd];
            } else {
                wd = [waterDisplays objectAtIndex:simRun.trialNum];
                wd.frame = CGRectMake(width + 10, (trial)*175 + 40, 115, 125);
            }
            wd.thresholdValue = thresh;
            [wd fastUpdateView: StormPlaybackWater.value];*/
            
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.floodedStreets);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * (1- simRunNormal.floodedStreets)]];
            [scoreVisNames addObject: currentVar.name];
            
        } else if([currentVar.name compare:@"puddleMax"] == NSOrderedSame){
            
            AprilTestTabBarController *tabControl = (AprilTestTabBarController*)[self parentViewController];
            ((FebTestWaterDisplay*)[tabControl.maxWaterDisplaysInTab objectAtIndex:trial]).thresholdValue = thresh;
            [[tabControl.maxWaterDisplaysInTab objectAtIndex:trial] updateView:48];
            
            MaxWaterDepthView = [[UIImageView alloc]initWithFrame:CGRectMake(width + 10, (trial)*175 + 40, 115, 125)];
            MaxWaterDepthView.image = [tabControl viewToImageForWaterDisplay:[tabControl.maxWaterDisplaysInTab objectAtIndex:simRun.trialNum]];
            [_dataWindow addSubview:MaxWaterDepthView];
            
            /*
            //display window for maxHeights
            if(maxWaterDisplays.count <= trial){
                mwd  = [[FebTestWaterDisplay alloc] initWithFrame:CGRectMake(width + 10, (trial)*175 + 40, 115, 125) andContent:simRun.maxWaterHeights];
                mwd.view = _dataWindow;
                [maxWaterDisplays addObject:mwd];
            } else {
                mwd = [maxWaterDisplays objectAtIndex:simRun.trialNum];
                mwd.frame = CGRectMake(width + 10, (trial)*175 + 40, 115, 125);
            }
            mwd.thresholdValue = thresh;
            [mwd updateView:48];*/
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * (1 - simRunNormal.standingWater);
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * (1- simRunNormal.standingWater)]];
            [scoreVisNames addObject: currentVar.name];

        } else if ([currentVar.name compare: @"capacity"] == NSOrderedSame){
            
            /*
            if( efficiency.count <= trial){
                //NSLog(@"Drawing efficiency display for first time");
            ev = [[AprilTestEfficiencyView alloc] initWithFrame:CGRectMake(width, (trial )*175 + 40, 130, 150) withContent: simRun.efficiency];
                ev.trialNum = i;
                ev.view = _dataWindow;
                [efficiency addObject:ev];
            } else {
                //NSLog(@"Repositioning efficiency display");
                ev = [efficiency objectAtIndex:simRun.trialNum];
                ev.frame = CGRectMake(width, (trial )*175 + 40, 130, 150);
            }
            [ev updateViewForHour: StormPlaybackInterv.value];*/
            
            if (trial >= [trialRunSubViews count]){
                AprilTestTabBarController *tabControl = (AprilTestTabBarController*)[self parentViewController];
                ((AprilTestEfficiencyView*)[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum]).trialNum = i;
                [[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum] updateViewForHour:StormPlaybackInterv.value];
                
                efficiencyImageView         = [[UIImageView alloc] initWithFrame:CGRectMake(width, (trial )*175 + 40, 180, 150)];
                efficiencyImageView.image   = [[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum] viewforEfficiencyToImage];
                [_dataWindow addSubview:efficiencyImageView];
            }
            else{
                efficiencyImageView         = [[UIImageView alloc] initWithFrame:CGRectMake(width, (trial )*175 + 40, 180, 150)];
                efficiencyImageView.image   = [[tabControl.efficiencyViewsInTab objectAtIndex:simRun.trialNum] viewforEfficiencyToImage];
                [_dataWindow addSubview:efficiencyImageView];
            }
            
            scoreTotal += currentVar.currentConcernRanking/priorityTotal *  simRunNormal.efficiency;
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal *  simRunNormal.efficiency]];
            //NSLog(@"%@", NSStringFromCGRect(ev.frame));
            [scoreVisNames addObject: currentVar.name];
            
        } else if ([currentVar.name compare: @"efficiencyOfIntervention"] == NSOrderedSame){
            [self drawTextBasedVar: [NSString stringWithFormat:@"$/Gallon Spent: $%.2f", simRun.dollarsGallons  ] withConcernPosition:width + 25 andyValue: (trial * 175) + 40 andColor: [UIColor blackColor] to:&efficiencyOfIntervention];
            scoreTotal += currentVar.currentConcernRanking/priorityTotal * 1;
            [scoreVisVals addObject:[NSNumber numberWithFloat:currentVar.currentConcernRanking/priorityTotal * 0]];
            [scoreVisNames addObject:currentVar.name];
        }

        width+= currentVar.widthOfVisualization;
        if (currentVar.widthOfVisualization > 0) visibleIndex++;
    }
    //border around component score
    UILabel *fullValueBorder = [[UILabel alloc] initWithFrame:CGRectMake(148, (trial)*175 + 73,  114, 26)];
    fullValueBorder.backgroundColor = [UIColor grayColor];
    UILabel *fullValue = [[UILabel alloc] initWithFrame:CGRectMake(150, (trial)*175 + 75,  110, 22)];
    fullValue.backgroundColor = [UIColor whiteColor];
    [_mapWindow addSubview:fullValueBorder];
    [_mapWindow addSubview:fullValue];
    //NSLog(@" %@", scoreVisVals);
    float maxX = 150;
    float totalScore = 0;
    UILabel *componentScore;
    
    //computing and drawing the final component score
    for(int i =  0; i < scoreVisVals.count; i++){
        float scoreWidth = [[scoreVisVals objectAtIndex: i] floatValue] * 100;
        if (scoreWidth < 0) scoreWidth = 0.0;
        totalScore += scoreWidth;
           componentScore = [[UILabel alloc] initWithFrame:CGRectMake(maxX, (trial)*175 + 75, floor(scoreWidth), 22)];
        componentScore.backgroundColor = [scoreColors objectForKey:[scoreVisNames objectAtIndex:i]];
        [_mapWindow addSubview:componentScore];
        maxX+=floor(scoreWidth);
    }
    
    [_dataWindow setContentSize:CGSizeMake(width+=100, (trial+1)*200)];
    for(UILabel * bgCol in bgCols){
        if(_dataWindow.contentSize.height > _dataWindow.frame.size.height){
            [bgCol setFrame: CGRectMake(bgCol.frame.origin.x, bgCol.frame.origin.y, bgCol.frame.size.width, _dataWindow.contentSize.height + 100)];
        }else {
            [bgCol setFrame: CGRectMake(bgCol.frame.origin.x, bgCol.frame.origin.y, bgCol.frame.size.width, _dataWindow.frame.size.height + 100)];
        }
    }
    
    UILabel *scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 175*(trial) + 40, 0, 0)];
    scoreLabel.text = @"Performance:";
    scoreLabel.font = [UIFont systemFontOfSize:14.0];
    [scoreLabel sizeToFit];
    scoreLabel.textColor = [UIColor blackColor];
    [_mapWindow addSubview:scoreLabel];
    UILabel *scoreLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(150, 175*(trial) + 60, 0, 0)];
    scoreLabel2.text = [NSString stringWithFormat:  @"Broken down by source:"];
    scoreLabel2.font = [UIFont systemFontOfSize:10.0];
    [scoreLabel2 sizeToFit];
    scoreLabel2.textColor = [UIColor blackColor];
    [_mapWindow addSubview:scoreLabel2];

    
    FavoriteView *favoriteView;
    UITapGestureRecognizer *tappedFavorite = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(favoriteTapped:)];
    tappedFavorite.numberOfTapsRequired = 1;
    tappedFavorite.numberOfTouchesRequired = 1;
    
    LeastFavoriteView *leastFavoriteView;
    UITapGestureRecognizer *tappedLeastFavorite = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(leastFavoriteTapped:)];
    tappedLeastFavorite.numberOfTapsRequired = 1;
    tappedLeastFavorite.numberOfTouchesRequired = 1;
    
    UILabel *favoriteLabel;
    
    //if its a new trial... draw new favorite and least favorite views
    //else retrieve it from the current views kept track of
    if (trial >= [trialRunSubViews count]) {
        favoriteView = [[FavoriteView alloc]initWithFrame:CGRectMake(154, trial * 175 + 125, 40, 40) andTrialNumber:simRun.trialNum];
        [favoriteView addGestureRecognizer:tappedFavorite];
        [favoriteView setUserInteractionEnabled:YES];
        [favoriteViews addObject:favoriteView];
        [_mapWindow addSubview:favoriteView];
        
        leastFavoriteView = [[LeastFavoriteView alloc]initWithFrame:CGRectMake(212, trial * 175 + 125, 40, 40) andTrialNumber:simRun.trialNum];
        [leastFavoriteView addGestureRecognizer:tappedLeastFavorite];
        [leastFavoriteView setUserInteractionEnabled:YES];
        [leastFavoriteViews addObject:leastFavoriteView];
        [_mapWindow addSubview:leastFavoriteView];
        
        favoriteLabel = [[UILabel alloc]initWithFrame:CGRectMake(148, trial * 175 + 105, 114, 20)];
        favoriteLabel.text = @"Best      Worst";
        favoriteLabel.font = [UIFont systemFontOfSize:14.0];
        [favoriteLabel setTextAlignment:NSTextAlignmentCenter];
        [favoriteLabels addObject:favoriteLabel];
        [_mapWindow addSubview:favoriteLabel];
    }
    else{
        favoriteView = [favoriteViews objectAtIndex:simRun.trialNum];
        favoriteView.trialNum = trial;
        [favoriteView addGestureRecognizer:tappedFavorite];
        [favoriteView setUserInteractionEnabled:YES];
        [favoriteView setFrame:CGRectMake(154, trial * 175 + 125, 40, 40) andTrialNumber:simRun.trialNum];
        [_mapWindow addSubview:favoriteView];
        
        leastFavoriteView = [leastFavoriteViews objectAtIndex:simRun.trialNum];
        leastFavoriteView.trialNum = trial;
        [leastFavoriteView addGestureRecognizer:tappedLeastFavorite];
        [leastFavoriteView setUserInteractionEnabled:YES];
        [leastFavoriteView setFrame:CGRectMake(212, trial * 175 + 125, 40, 40) andTrialNumber:simRun.trialNum];
        [_mapWindow addSubview:leastFavoriteView];
        
        favoriteLabel = [favoriteLabels objectAtIndex:simRun.trialNum];
        favoriteLabel.frame = CGRectMake(148, trial * 175 + 105, 114, 20);
        [_mapWindow addSubview:favoriteLabel];
    }


    //NSLog(@"Trial: %d\nScore: %@ / 100\n\n", simRun.trialNum, [NSNumber numberWithInt: totalScore]);
    
    NSDictionary *trialRunInfo = @{@"TrialNum"            : [NSNumber numberWithInt:simRun.trialNum],
                                   @"TrialRun"            : [tabControl.trialRuns objectAtIndex:simRun.trialNum],
                                   @"TrialStatic"         : [tabControl.trialRunsNormalized objectAtIndex:simRun.trialNum],
                                   @"TrialDynamic"        : [tabControl.trialRunsDynNorm objectAtIndex:simRun.trialNum],
                                   @"TrialTxTBox"         : tx,
                                   @"PerformanceScore"    : [NSNumber numberWithInt: totalScore],
                                   //@"WaterDisplay"      : wd,
                                   //@"MWaterDisplay"     : mwd,
                                   //@"EfficiencyView"      : ev,
                                   //@"Maintenance"       : maintenance,
                                   @"InterventionImgView" : interventionImageView,
                                   @"WaterDepthView"      : waterDepthView,
                                   @"MWaterDepthView"     : MaxWaterDepthView,
                                   @"EfficiencyView"      : efficiencyImageView,
                                   @"Damage"              : damage,
                                   @"DamageReduced"       : damageReduced,
                                   @"SewerLoad"           : sewerLoad,
                                   @"WaterInfiltration"   : gw_infiltration,
                                   @"Efficiency_Interv"   : efficiencyOfIntervention,
                                   @"ImpactNeighbor"      : impactNeighbor,
                                   @"CostDisplay"         : cd,
                                   @"FavoriteLabel"       : favoriteLabel,
                                   @"FavoriteView"        : favoriteView,
                                   @"LeastFavoriteView"   : leastFavoriteView
                                   };
   
    //Right now contains the contents of the map window scrollview
    if (trial < trialRunSubViews.count){
        [trialRunSubViews replaceObjectAtIndex:trial withObject:trialRunInfo];
    }
    else
        [trialRunSubViews addObject:trialRunInfo];
    
    NSLog(@"Just drew trial %d\n", simRun.trialNum);
   
    [_dataWindow flashScrollIndicators];          
    
}

- (void)sendFavorite {
    int favorite = -1;
    
    for (NSDictionary *trialRunInfo in trialRunSubViews) {
        if([[trialRunInfo objectForKey:@"FavoriteView"] isActive])
            favorite = (int)(((FavoriteView *)[trialRunInfo objectForKey:@"FavoriteView"]).trialNum);
    }
    
    if (favorite != -1) {
        AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
        
        if(tabControl.session) {
            NSMutableArray *favoriteTrial = [[NSMutableArray alloc]init];
            
            [favoriteTrial addObject:@"favoriteForMomma"];
            [favoriteTrial addObject:[[UIDevice currentDevice]name]];
            
            [favoriteTrial addObject:[NSNumber numberWithInt:favorite]];
            
            NSDictionary *favoriteToSendToMomma = [NSDictionary dictionaryWithObject:favoriteTrial
                                                                              forKey:@"data"];
            
            if(favoriteToSendToMomma != nil) {
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:favoriteToSendToMomma];
                if(tabControl.peerIDForMomma != nil)
                    [tabControl.session sendData:data toPeers:@[tabControl.peerIDForMomma] withDataMode:GKSendDataReliable error:nil];
            }
        }

    }
}

- (void)sendLeastFavorite {
    int leastFavorite = -1;

    for (NSDictionary *trialRunInfo in trialRunSubViews) {
        if([[trialRunInfo objectForKey:@"LeastFavoriteView"] isActive])
            leastFavorite = (int)(((LeastFavoriteView *)[trialRunInfo objectForKey:@"LeastFavoriteView"]).trialNum);
    }
    
    if (leastFavorite != -1) {
        AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
        
        if(tabControl.session) {
            NSMutableArray *leastFavoriteTrial = [[NSMutableArray alloc]init];
            
            [leastFavoriteTrial addObject:@"leastFavoriteForMomma"];
            [leastFavoriteTrial addObject:[[UIDevice currentDevice]name]];
            
            [leastFavoriteTrial addObject:[NSNumber numberWithInt:leastFavorite]];
            
            NSDictionary *leastFavoriteToSendToMomma = [NSDictionary dictionaryWithObject:leastFavoriteTrial
                                                                              forKey:@"data"];
            
            if(leastFavoriteToSendToMomma != nil) {
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:leastFavoriteToSendToMomma];
                if(tabControl.peerIDForMomma != nil)
                    [tabControl.session sendData:data toPeers:@[tabControl.peerIDForMomma] withDataMode:GKSendDataReliable error:nil];
            }
        }
        
    }
}

- (void)favoriteTapped:(UITapGestureRecognizer *)gestureRecognizer {
    NSLog(@"Tapped favorite");
    
    FavoriteView *favoriteView = (FavoriteView *)gestureRecognizer.view;
    [favoriteView isTouched];
    
    int trial = favoriteView.trialNum;
    
    // loop thru all favorite views and turn off any others
    for (NSDictionary *trialRunInfo in trialRunSubViews) {
        if (![[trialRunInfo objectForKey:@"FavoriteView"] isEqual: favoriteView] && [[trialRunInfo objectForKey:@"FavoriteView"]isActive])
            [[trialRunInfo objectForKey:@"FavoriteView"] setActive:NO];
        if ([[trialRunInfo objectForKey:@"LeastFavoriteView"]trialNum] == favoriteView.trialNum)
            [[trialRunInfo objectForKey:@"LeastFavoriteView"]setActive:NO];
    }
    
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    
    if(tabControl.session) {
        NSMutableArray *favorite = [[NSMutableArray alloc]init];
        
        [favorite addObject:@"favoriteForMomma"];
        [favorite addObject:[[UIDevice currentDevice]name]];
        
        [favorite addObject:[NSNumber numberWithInt:trial]];
        
        NSDictionary *favoriteToSendToMomma = [NSDictionary dictionaryWithObject:favorite
                                                                          forKey:@"data"];
        
        if(favoriteToSendToMomma != nil) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:favoriteToSendToMomma];
            if(tabControl.peerIDForMomma != nil)
                [tabControl.session sendData:data toPeers:@[tabControl.peerIDForMomma] withDataMode:GKSendDataReliable error:nil];
        }
    }
}

- (void)leastFavoriteTapped:(UITapGestureRecognizer *)gestureRecognizer {
    NSLog(@"Tapped least favorite");
    
    LeastFavoriteView *leastFavoriteView = (LeastFavoriteView *)gestureRecognizer.view;
    [leastFavoriteView isTouched];
    
    int trial = leastFavoriteView.trialNum;
    
    // loop thru all favorite views and turn off any others
    for (NSDictionary *trialRunInfo in trialRunSubViews) {
        if (![[trialRunInfo objectForKey:@"LeastFavoriteView"] isEqual: leastFavoriteView] && [[trialRunInfo objectForKey:@"LeastFavoriteView"]isActive])
            [[trialRunInfo objectForKey:@"LeastFavoriteView"] setActive:NO];
        if ([[trialRunInfo objectForKey:@"FavoriteView"] trialNum] == leastFavoriteView.trialNum)
            [[trialRunInfo objectForKey:@"FavoriteView"] setActive:NO];
    }
    
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    
    if(tabControl.session) {
        NSMutableArray *leastFavorite = [[NSMutableArray alloc]init];
        
        [leastFavorite addObject:@"leastFavoriteForMomma"];
        [leastFavorite addObject:[[UIDevice currentDevice]name]];
        
        [leastFavorite addObject:[NSNumber numberWithInt:trial]];
        
        NSDictionary *leastFavoriteToSendToMomma = [NSDictionary dictionaryWithObject:leastFavorite
                                                                          forKey:@"data"];
        
        if(leastFavoriteToSendToMomma != nil) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:leastFavoriteToSendToMomma];
            if(tabControl.peerIDForMomma != nil)
                [tabControl.session sendData:data toPeers:@[tabControl.peerIDForMomma] withDataMode:GKSendDataReliable error:nil];
        }
    }
}


- (void)drawSingleTrial {
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    if ([tabControl.trialRuns count] > trialNum) {
        [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];

        [self drawTrial:tabControl.trialNum-1];
        
        //chooses between static/dynamic normalization of trial data
        if (_DynamicNormalization.isOn)
            [self normalizeAllandUpdateDynamically];
        else
            [self normalizeStatically];
        
        //update with the current sort chosen after a new trial is drawn
        [self handleSort: sortChosen];
        
        
        //find the index (offset of trial drawn) of the recently drawn trial
        NSInteger index = [trialRunSubViews indexOfObjectPassingTest:
                            ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop)
                            {
                                return [[dict objectForKey:@"TrialNum"] isEqual:[NSNumber numberWithInt:tabControl.trialNum-1]];
                            }
                            ];
        
        //NSLog(@"Trial %@ drawn at index %d\n", trialDrawn,index);
        if (index == NSNotFound){
            index = trialNum;
        }
        scrollingTimer = [NSTimer scheduledTimerWithTimeInterval:(0.10)
                                                              target:self selector:@selector(autoscrollTimerFired:) userInfo:[NSNumber numberWithInt:index+1] repeats:NO];
        
        [_loadingIndicator stopAnimating];
    }
    else
        NSLog(@"Trial %d not yet loaded", trialNum);
}

- (void)drawMultipleTrials {
    [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];
    
    AprilTestTabBarController *tabControl = (AprilTestTabBarController *)[self parentViewController];
    
    for (int i =0; i < tabControl.trialNum; i++){
        [self drawTrial:i];
    }
    
    //determine depending on min and max budget limits what is to be drawn on UILabels under le BudgetSlider
    minBudgetLabel = [NSString stringWithFormat:@"$%.1f%c", ((min_budget_limit/1000000 < 1) ? (min_budget_limit/1000) : (min_budget_limit/1000000)), (min_budget_limit/1000000 < 1) ? 'K' : 'M'];
    maxBudgetLabel = [NSString stringWithFormat:@"$%.1f%c", ((max_budget_limit/1000000 < 1) ? (max_budget_limit/1000) : (max_budget_limit/1000000)), (max_budget_limit/1000000 < 1) ? 'K' : 'M'];
    
    [self drawTitles];
    [self drawSliders];
    
    dynamic_cd_width = [self getWidthFromSlider:BudgetSlider toValue:maxBudgetLimit];
    
    [_dataWindow setContentOffset:CGPointMake(0, 0)];
    [_mapWindow setContentOffset:CGPointMake(0,0 )];
    [_dataWindow flashScrollIndicators];
    
    [_loadingIndicator stopAnimating];
}

-(void)keyboardWillShow {
    // Animate the current view out of the way
    NSMutableString *content = [[NSMutableString alloc] init];
    [content appendString: @"Before new naming:\n"];
    for(int i =0; i < _scenarioNames.count; i++){
        UITextField *tx =[_scenarioNames objectAtIndex:i];
        
        [content appendString: tx.text];
        [content appendString:@"\n"];
    }
    
    [content appendString:@"\n"];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile_simResults.txt"];
    
    //create file if it doesn't exist
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
        [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
    
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
    [file seekToEndOfFile];
    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
    
    
    for (int i = 0; i < _scenarioNames.count; i++){
        UITextField *tx = [_scenarioNames objectAtIndex:i];
        if ( [tx isEditing]){
            if ((tx.frame.origin.y - _mapWindow.contentOffset.y) > (self.view.frame.size.height - 450)){
                lastMoved = 1;
                edittingTX = tx;
                [self setViewMovedUp:YES];
            }
        }
    }
    
}

-(void)keyboardWillHide {
    NSMutableString *content = [[NSMutableString alloc] init];
    [content appendString: @"After naming:\n"];
    for(int i =0; i < _scenarioNames.count; i++){
        UITextField *tx =[_scenarioNames objectAtIndex:i];
        
        [content appendString: tx.text];
        [content appendString:@"\n"];
    }
    [content appendString:@"\n"];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile_simResults.txt"];
    
    //create file if it doesn't exist
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
        [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
    
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
    [file seekToEndOfFile];
    [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
       if(lastMoved == 1) [self setViewMovedUp:NO];
    lastMoved = 0;


}

//method to move the view up/down whenever the keyboard is shown/dismissed
-(void)setViewMovedUp:(BOOL)movedUp{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3]; // if you want to slide up the view
    
    CGPoint rect = self.mapWindow.contentOffset;
    CGPoint rect2 = self.dataWindow.contentOffset;
    
    if (movedUp){
        originalOffset = rect.y;
        rect.y += (edittingTX.frame.origin.y + _mapWindow.contentOffset.y) - 225;
        rect2.y = rect.y;
    }
    else{
        // revert back to the normal state.
        rect.y = originalOffset;
        rect2.y = originalOffset;
    }
    self.mapWindow.contentOffset = rect;
    self.dataWindow.contentOffset = rect2;
    
    [UIView commitAnimations];
}

//Draws Labels to set on the dataWindow Scrollview but also returns object to be added into a MutableArray (used for updating labels)
-(void) drawTextBasedVar: (NSString *) outputValue withConcernPosition: (int) concernPos andyValue: (int) yValue andColor: (UIColor*) color to:(UILabel**) label{
    if (label != nil){
        *label = [[UILabel alloc] init];
        (*label).text = outputValue;
        (*label).frame =CGRectMake(concernPos, yValue, 0, 0);
        [*label sizeToFit ];
        (*label).font = [UIFont systemFontOfSize:14.0];
        (*label).textColor = color;
        [_dataWindow addSubview:*label];
    }else
    {
        UILabel *valueLabel = [[UILabel alloc] init];
        valueLabel.text = outputValue;
        valueLabel.frame =CGRectMake(concernPos, yValue, 0, 0);
        [valueLabel sizeToFit ];
        valueLabel.font = [UIFont systemFontOfSize:14.0];
        valueLabel.textColor = color;
        [_dataWindow addSubview:valueLabel];
    }
}

-(void) drawTitles{
    
    int width = 0;
    int visibleIndex = 0;
    for(int i = 0 ; i <_currentConcernRanking.count ; i++){

        AprilTestVariable * currentVar =[sortedArray objectAtIndex:i];
        UILabel * currentVarLabel = [[UILabel alloc] init];
        currentVarLabel.backgroundColor = [scoreColors objectForKey:currentVar.name];
        currentVarLabel.frame = CGRectMake(width, 2, currentVar.widthOfVisualization, 40);
        currentVarLabel.font = [UIFont boldSystemFontOfSize:15.3];
        if([currentVar.name compare: @"publicCost"] == NSOrderedSame){
            currentVarLabel.text = @"  Investment";
        } else if ([currentVar.name compare: @"privateCost"] == NSOrderedSame){
            currentVarLabel.text =@"  Damage Reduction";
        } else if ([currentVar.name compare: @"impactingMyNeighbors"] == NSOrderedSame){
            currentVarLabel.text =@"  Impact on my Neighbors";
        } else if ([currentVar.name compare: @"neighborImpactingMe"] == NSOrderedSame){
            currentVarLabel.text=@"  Rainwater from Neighbors";
        } else if ([currentVar.name compare: @"efficiencyOfIntervention"] == NSOrderedSame){
            currentVarLabel.text =@"  Efficiency of Intervention";
        } else if ([currentVar.name compare:@"puddleTime"] == NSOrderedSame){
            currentVarLabel.text = @"  Water Depth Over Storm";
        } else if( [currentVar.name compare:@"groundwaterInfiltration"] == NSOrderedSame){
            currentVarLabel.text = @"  Groundwater Infiltration";
        } else if( [currentVar.name compare:@"puddleMax"] == NSOrderedSame){
            currentVarLabel.text = @"  Maximum Flooded Area";
        } else if( [currentVar.name compare:@"capacity"] == NSOrderedSame){
            currentVarLabel.text = @"  Intervention Capacity";
        }
        else {
            currentVarLabel = NULL;
        }
        if(currentVar.widthOfVisualization != 0) visibleIndex++;
        
        if(currentVarLabel != NULL){
        [_titleWindow addSubview:currentVarLabel];
        }
        width+= currentVar.widthOfVisualization;
    }
    
    [_dataWindow setContentSize: CGSizeMake(width + 10, _dataWindow.contentSize.height)];
}

//will draw sliders on a scrollview right below the titles of concern rankings
-(void) drawSliders{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setGroupingSeparator:@","];
    
    int width = 0;
    int visibleIndex = 0;
    for(int i = 0 ; i <_currentConcernRanking.count ; i++){
        
        AprilTestVariable * currentVar =[sortedArray objectAtIndex:i];
        UILabel * currentVarLabel = [[UILabel alloc] init];
        currentVarLabel.backgroundColor = [scoreColors objectForKey:currentVar.name];
        currentVarLabel.frame = CGRectMake(width, 2, currentVar.widthOfVisualization, 70);
        currentVarLabel.font = [UIFont boldSystemFontOfSize:15.3];
        
        
        if([currentVar.name compare: @"publicCost"] == NSOrderedSame){
            CGRect frame  = CGRectMake(width + 25, 16, 160, 40);
            BudgetSlider = [[UISlider alloc] initWithFrame:frame];
            [BudgetSlider addTarget:self action:@selector(BudgetChanged:) forControlEvents:UIControlEventValueChanged];
            [BudgetSlider setBackgroundColor:[UIColor clearColor]];
            BudgetSlider.minimumValue = min_budget_limit;
            BudgetSlider.maximumValue = max_budget_limit;
            BudgetSlider.continuous = YES;
            [BudgetSlider setValue:maxBudgetLimit animated:YES];
            //[_SliderWindow addSubview:BudgetSlider];
            
            //draw min/max cost labels under slider
            CGRect minCostFrame = CGRectMake(width + 5, 5, currentVar.widthOfVisualization/3, 15);
            UILabel *minCostLabel = [[UILabel alloc] initWithFrame:minCostFrame];
            minCostLabel.font =  [UIFont boldSystemFontOfSize:14.0];
            minCostLabel.text =  minBudgetLabel;
            
            CGRect maxCostFrame = CGRectMake(width + 160, 5, currentVar.widthOfVisualization/3, 15);
            UILabel *maxCostLabel = [[UILabel alloc] initWithFrame:maxCostFrame];
            maxCostLabel.font = [UIFont boldSystemFontOfSize:14.0];
            maxCostLabel.text = maxBudgetLabel;
            
            CGRect currCostFrame = CGRectMake(width + 35, 50, currentVar.widthOfVisualization, 15);
            investmentBudget = [[UILabel alloc] initWithFrame:currCostFrame];
            investmentBudget.font = [UIFont boldSystemFontOfSize:14.0];
            investmentBudget.text = [NSString stringWithFormat:@"Set Budget: $%@", [formatter stringFromNumber:[NSNumber numberWithInt:maxBudgetLimit]]];
            
            [_SliderWindow addSubview:minCostLabel];
            [_SliderWindow addSubview:maxCostLabel];
            [_SliderWindow addSubview:investmentBudget];
            
        }
        else if ([currentVar.name compare:@"puddleTime"] == NSOrderedSame){
            CGRect frame = CGRectMake(width, 16, currentVar.widthOfVisualization, 40);
            StormPlaybackWater = [[UISlider alloc] initWithFrame:frame];
            [StormPlaybackWater addTarget:self action:@selector(StormHoursChangedOutcome:) forControlEvents:UIControlEventValueChanged];
            [StormPlaybackWater addTarget:self
                              action:@selector(StormHoursChosenOutcome:)
                    forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
            [StormPlaybackWater setBackgroundColor:[UIColor clearColor]];
            StormPlaybackWater.minimumValue = 0.0;
            StormPlaybackWater.maximumValue = 48;
            StormPlaybackWater.continuous = YES;
            StormPlaybackWater.value = hours;

            [_SliderWindow addSubview:StormPlaybackWater];
            
            //draw labels for range of hours
            CGRect minCostFrame = CGRectMake(width + 5, 5, currentVar.widthOfVisualization/5, 15);
            UILabel *minHoursLabel = [[UILabel alloc] initWithFrame:minCostFrame];
            minHoursLabel.font = [UIFont boldSystemFontOfSize:14];
            minHoursLabel.text = [NSString stringWithFormat:@" 0 hrs"];
            
            CGRect maxCostFrame = CGRectMake((width + currentVar.widthOfVisualization) -53, 5, currentVar.widthOfVisualization/4, 15);
            UILabel *maxHoursLabel = [[UILabel alloc] initWithFrame:maxCostFrame];
            maxHoursLabel.font = [UIFont boldSystemFontOfSize:14];
            maxHoursLabel.text = [NSString stringWithFormat:@"48 hrs"];
            
            CGRect currCostFrame = CGRectMake(width + 25, 50, currentVar.widthOfVisualization, 15);
            WaterDepthOverStorm = [[UILabel alloc] initWithFrame:currCostFrame];
            WaterDepthOverStorm.font = [UIFont boldSystemFontOfSize:14.0];
            WaterDepthOverStorm.text = [NSString stringWithFormat:@"Storm Playback: %@ hours", [NSNumber numberWithInt:hours]];
            
            [_SliderWindow addSubview:minHoursLabel];
            [_SliderWindow addSubview:maxHoursLabel];
            [_SliderWindow addSubview:WaterDepthOverStorm];
        }
        else if( [currentVar.name compare:@"capacity"] == NSOrderedSame){
            CGRect frame = CGRectMake(width, 16, currentVar.widthOfVisualization, 40);
            StormPlaybackInterv = [[UISlider alloc] initWithFrame:frame];
            StormPlaybackInterv.minimumValue = 0.0;
            StormPlaybackInterv.maximumValue = 48;
            StormPlaybackInterv.continuous = YES;
            StormPlaybackInterv.value = hours;
            [StormPlaybackInterv setBackgroundColor:[UIColor clearColor]];
            [StormPlaybackInterv addTarget:self action:@selector(StormHoursChangedOutcome:) forControlEvents:UIControlEventValueChanged];
            [StormPlaybackInterv addTarget:self
                               action:@selector(StormHoursChosenOutcome:)
                     forControlEvents:(UIControlEventTouchUpInside| UIControlEventTouchUpOutside)];
            
            [_SliderWindow addSubview:StormPlaybackInterv];
            
            //draw labels for range of hours
            CGRect minCostFrame = CGRectMake(width + 5, 5, currentVar.widthOfVisualization/5, 15);
            UILabel *minHoursLabel = [[UILabel alloc] initWithFrame:minCostFrame];
            minHoursLabel.font = [UIFont boldSystemFontOfSize:14];
            minHoursLabel.text = [NSString stringWithFormat:@" 0 hrs"];
            
            CGRect maxCostFrame = CGRectMake((width + currentVar.widthOfVisualization) -53, 5, currentVar.widthOfVisualization/4, 15);
            UILabel *maxHoursLabel = [[UILabel alloc] initWithFrame:maxCostFrame];
            maxHoursLabel.font = [UIFont boldSystemFontOfSize:14];
            maxHoursLabel.text = [NSString stringWithFormat:@"48 hrs"];
            
            CGRect currCostFrame = CGRectMake(width + 25, 50, currentVar.widthOfVisualization, 15);
            interventionCap = [[UILabel alloc] initWithFrame:currCostFrame];
            interventionCap.font = [UIFont boldSystemFontOfSize:14.0];
            interventionCap.text = [NSString stringWithFormat:@"Storm Playback: %@ hours", [NSNumber numberWithInt:hours]];
            
            [_SliderWindow addSubview:minHoursLabel];
            [_SliderWindow addSubview:maxHoursLabel];
            [_SliderWindow addSubview:interventionCap];
        }
        
        else if ([currentVar.name compare: @"privateCost"] == NSOrderedSame){
            
        } else if ([currentVar.name compare: @"impactingMyNeighbors"] == NSOrderedSame){
            
        } else if ([currentVar.name compare: @"neighborImpactingMe"] == NSOrderedSame){
            
        } else if ([currentVar.name compare: @"efficiencyOfIntervention"] == NSOrderedSame){
            
        } else if( [currentVar.name compare:@"groundwaterInfiltration"] == NSOrderedSame){
            
        } else if( [currentVar.name compare:@"puddleMax"] == NSOrderedSame){
            
        
        }
        else {
            currentVarLabel = NULL;
        }
        if(currentVar.widthOfVisualization != 0) visibleIndex++;
        
        if(currentVarLabel != NULL){
            [_SliderWindow addSubview:currentVarLabel];
        }
        width+= currentVar.widthOfVisualization;
    }
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if([scrollView isEqual:_dataWindow]) {
        CGPoint offset = _mapWindow.contentOffset;
        offset.y = _dataWindow.contentOffset.y;
        CGPoint titleOffset = _titleWindow.contentOffset;
        titleOffset.x = _dataWindow.contentOffset.x;
        [_titleWindow setContentOffset:titleOffset];
        [_SliderWindow setContentOffset:titleOffset];
        [_mapWindow setContentOffset:offset];
    } else {
        CGPoint offset = _dataWindow.contentOffset;
        offset.y = _mapWindow.contentOffset.y;
        [_dataWindow setContentOffset:offset];
    }
    
    NSDate *myDate = [[NSDate alloc] init];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH:mm:ss"];
    NSString *prettyVersion = [dateFormat stringFromDate:myDate];
    
    //NSLog(@"content offset: %f",  _dataWindow.contentOffset.x);
    if(!passFirstThree && _dataWindow.contentOffset.x > 50){
        NSMutableString * content = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%@\tScrolled past three most important variables", prettyVersion]];
        
        [content appendString:@"\n\n"];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile_simResults.txt"];
        
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
        [file seekToEndOfFile];
        [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
        passFirstThree = TRUE;
    }
    if(passFirstThree &&  _dataWindow.contentOffset.x <= 50 ){
        NSMutableString * content = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%@\tReturned to three most important variables", prettyVersion]];
        
        [content appendString:@"\n\n"];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"logfile_simResults.txt"];
        
        //create file if it doesn't exist
        if(![[NSFileManager defaultManager] fileExistsAtPath:fileName])
            [[NSFileManager defaultManager] createFileAtPath:fileName contents:nil attributes:nil];
        
        NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:fileName];
        [file seekToEndOfFile];
        [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
        passFirstThree = FALSE;
    }
}

- (void) handleSort:(int) row{
    
    //depending on what the type of sort it is, sort the mutable array of dictionaries
    if ([arrStatus[row] isEqual: @"Trial Number"]){
        [trialRunSubViews sortUsingDescriptors:@[ [[NSSortDescriptor alloc] initWithKey:@"TrialNum" ascending:YES]]];
    }
    else if ([arrStatus[row] isEqual: @"Best Score"]){
        [trialRunSubViews sortUsingDescriptors:@[ [[NSSortDescriptor alloc] initWithKey:@"PerformanceScore" ascending:NO]]];
    }
    
    else if ([arrStatus[row] isEqual: @"Investment"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            AprilTestSimRun *first  = (AprilTestSimRun*)[obj1 valueForKey:@"TrialRun"];
            AprilTestSimRun *second = (AprilTestSimRun*)[obj2 valueForKey:@"TrialRun"];
            
        
                if (first.publicInstallCost > second.publicInstallCost)
                    return NSOrderedAscending;
                else if (second.publicInstallCost > first.publicInstallCost)
                    return NSOrderedDescending;
                return NSOrderedSame;
                
        }];
    }
    else if ([arrStatus[row] isEqual: @"Damage Reduction"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            AprilTestSimRun *first  = (AprilTestSimRun*)[obj1 valueForKey:@"TrialRun"];
            AprilTestSimRun *second = (AprilTestSimRun*)[obj2 valueForKey:@"TrialRun"];
            

                if (first.privateDamages > second.privateDamages)
                    return NSOrderedAscending;
                else if (second.privateDamages > first.privateDamages)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
        
    else if ([arrStatus[row] isEqual: @"Impact on my Neighbors"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            AprilTestSimRun *first  = (AprilTestSimRun*)[obj1 valueForKey:@"TrialRun"];
            AprilTestSimRun *second = (AprilTestSimRun*)[obj2 valueForKey:@"TrialRun"];
            

                if (first.impactNeighbors > second.impactNeighbors)
                    return NSOrderedAscending;
                else if (second.impactNeighbors > first.impactNeighbors)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
            
        }];
    }
    
    else if ([arrStatus[row] isEqual: @"Intevention Capacity"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSString *key = (_DynamicNormalization.isOn) ? @"TrialDynamic" : @"TrialStatic";
            
            AprilTestNormalizedVariable *first  = (AprilTestNormalizedVariable*)[obj1 valueForKey: key];
            AprilTestNormalizedVariable *second = (AprilTestNormalizedVariable*)[obj2 valueForKey: key];
            

                if (first.efficiency > second.efficiency)
                    return NSOrderedAscending;
                else if (second.efficiency > first.efficiency)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
    
    else if ([arrStatus[row] isEqual: @"Water Depth over Storm"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSString *key = (_DynamicNormalization.isOn) ? @"TrialDynamic" : @"TrialStatic";
            
            AprilTestNormalizedVariable *first  = (AprilTestNormalizedVariable*)[obj1 valueForKey: key];
            AprilTestNormalizedVariable *second = (AprilTestNormalizedVariable*)[obj2 valueForKey: key];
            
            
                if (first.floodedStreets > second.floodedStreets)
                    return NSOrderedAscending;
                else if (second.floodedStreets > first.floodedStreets)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
    
    else if ([arrStatus[row] isEqual: @"Max Flooded Area"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSString *key = (_DynamicNormalization.isOn) ? @"TrialDynamic" : @"TrialStatic";
            
            AprilTestNormalizedVariable *first  = (AprilTestNormalizedVariable*)[obj1 valueForKey: key];
            AprilTestNormalizedVariable *second = (AprilTestNormalizedVariable*)[obj2 valueForKey: key];
            

                if (first.standingWater > second.standingWater)
                    return NSOrderedAscending;
                else if (second.standingWater > first.standingWater)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
    
    else if ([arrStatus[row] isEqual: @"Efficiency of Intervention"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            AprilTestSimRun *first  = (AprilTestSimRun*)[obj1 valueForKey:@"TrialRun"];
            AprilTestSimRun *second = (AprilTestSimRun*)[obj2 valueForKey:@"TrialRun"];
            
            
                if (first.dollarsGallons > second.dollarsGallons)
                    return NSOrderedAscending;
                else if (second.dollarsGallons > first.dollarsGallons)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
        
    else if ([arrStatus[row] isEqual: @"Groundwater Infiltration"]){
        [trialRunSubViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            AprilTestSimRun *first  = (AprilTestSimRun*)[obj1 valueForKey:@"TrialRun"];
            AprilTestSimRun *second = (AprilTestSimRun*)[obj2 valueForKey:@"TrialRun"];
            
            
                if (first.infiltration > second.infiltration)
                    return NSOrderedAscending;
                else if (second.infiltration > first.infiltration)
                    return NSOrderedDescending;
                return NSOrderedSame;
            
        }];
    }
    
    
    //loop through all entries (in sorted order) and update its frame to its new position
    for (int i = 0; i < trialRunSubViews.count; i++) {
        //UILabel *maintenance                  = [[trialRunSubViews objectAtIndex:i] valueForKey:@"Maintenance"];
        //FebTestWaterDisplay *wd               = [[trialRunSubViews objectAtIndex:i] valueForKey:@"WaterDisplay"];
        //FebTestWaterDisplay *mwd              = [[trialRunSubViews objectAtIndex:i] valueForKey:@"MWaterDisplay"];
        //AprilTestEfficiencyView *ev           = [[trialRunSubViews objectAtIndex:i] objectForKey:@"EfficiencyView"];
        UITextField *newTxt                   = [[trialRunSubViews objectAtIndex:i] valueForKey:@"TrialTxTBox"];
        UILabel *Damage                       = [[trialRunSubViews objectAtIndex:i] valueForKey:@"Damage"];
        UILabel *DamageReduced                = [[trialRunSubViews objectAtIndex:i] valueForKey:@"DamageReduced"];
        UILabel *SewerLoad                    = [[trialRunSubViews objectAtIndex:i] valueForKey:@"SewerLoad"];
        UILabel *gw_infiltration              = [[trialRunSubViews objectAtIndex:i] valueForKey:@"WaterInfiltration"];
        UILabel *EfficiencyOfIntervention     = [[trialRunSubViews objectAtIndex:i] valueForKey:@"Efficiency_Interv"];
        UILabel *impactNeighbor               = [[trialRunSubViews objectAtIndex:i] valueForKey:@"ImpactNeighbor"];
        UIImageView *wd                       = [[trialRunSubViews objectAtIndex:i] valueForKey:@"WaterDepthView"];
        UIImageView *mwd                      = [[trialRunSubViews objectAtIndex:i] valueForKey:@"MWaterDepthView"];
        UIImageView *ev                       = [[trialRunSubViews objectAtIndex:i] valueForKey:@"EfficiencyView"];
        UIImageView *InterventionImageView    = [[trialRunSubViews objectAtIndex:i] valueForKey:@"InterventionImgView"];
        UILabel *favoriteLabel                = [[trialRunSubViews objectAtIndex:i] objectForKey:@"FavoriteLabel"];
        FavoriteView *favoriteView            = [[trialRunSubViews objectAtIndex:i] objectForKey:@"FavoriteView"];
        LeastFavoriteView *leastFavoriteView  = [[trialRunSubViews objectAtIndex:i] objectForKey:@"LeastFavoriteView"];
        
        [favoriteView setFrame:CGRectMake(154, i * 175 + 125, 40, 40) andTrialNumber:favoriteView.trialNum];
        
        [leastFavoriteView setFrame:CGRectMake(212, i * 175 + 125, 40, 40) andTrialNumber:leastFavoriteView.trialNum];
        
        [favoriteLabel setFrame:CGRectMake(148, 175 * i + 105, 114, 20)];
        
        [self OffsetView:InterventionImageView toX:InterventionImageView.frame.origin.x andY:175 * (i) + 40];
        
        
        [self OffsetView:ev toX:ev.frame.origin.x andY:175*i + 40];
        //[ev updateViewForHour: StormPlaybackInterv.value];
        
        [self OffsetView:wd toX:wd.frame.origin.x andY:175*i + 40];
        //[wd fastUpdateView: StormPlaybackWater.value];
        
        [self OffsetView:mwd toX:mwd.frame.origin.x andY:175*i + 40];
        //[mwd updateView:48];
        
        //move over the private damage labels
        [self OffsetView:Damage toX:Damage.frame.origin.x andY:(i*175) +40 ];
        [self OffsetView:DamageReduced toX:DamageReduced.frame.origin.x andY:(i*175) +70];
        [self OffsetView:SewerLoad toX:SewerLoad.frame.origin.x andY:(i*175) + 100];
        
        //move over impact on Neighbors
        [self OffsetView:impactNeighbor toX:impactNeighbor.frame.origin.x andY:(i*175) + 40];
        
        //move over groundwater infiltration
        [self OffsetView:gw_infiltration toX:gw_infiltration.frame.origin.x andY:(i*175) + 40];
        
        //move over efficiency of intervention
        [self OffsetView:EfficiencyOfIntervention toX:EfficiencyOfIntervention.frame.origin.x andY:(i*175) + 40];
        
        /*
        //move over maintenance ==> remove maintenance component
        [self OffsetView:maintenance toX:maintenance.frame.origin.x andY:(i*175) + 100];
        */
        
        //Offset the "Trial #" label
        [self OffsetView:newTxt      toX:newTxt.frame.origin.x     andY:175*(i)+5];
    }

    (_DynamicNormalization.isOn) ? ([self normalizeAllandUpdateDynamically]) : ([self normalizaAllandUpdateStatically]);
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    // Handle the selection
    _SortPickerTextField.text = [NSString stringWithFormat:@"%@", arrStatus[row]];
    sortChosen = (int)row;

    //[[self view] endEditing:YES];
    [SortType removeFromSuperview];
    
    //Handle the sort afterwards
    [_loadingIndicator performSelectorInBackground:@selector(startAnimating) withObject:nil];
    [self handleSort:(int)row];
    [_loadingIndicator stopAnimating];
}

// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSUInteger numRows = [arrStatus count];
    
    return numRows;
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view{
    
    UILabel* tView = (UILabel*)view;
    if (!tView){
        tView = [[UILabel alloc] init];
        // Setup label properties - frame, font, colors etc
        tView.frame = CGRectMake(0, 0, 250, 30);
    }
    tView.text = [arrStatus objectAtIndex:row];

    return tView;
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {

    return [arrStatus objectAtIndex:row];
}

// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    int sectionWidth = 150;
    
    return sectionWidth;
}

-(CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component{
    int rowHeight = 20;
    return rowHeight;
}


@end
