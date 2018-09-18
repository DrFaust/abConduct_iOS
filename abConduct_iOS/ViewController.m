//
//  ViewController.m
//  abConduct_iOS
//
//  Created by Reinhard Sasse on 16.09.18.
//  Copyright © 2018 Reinhard Sasse. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

#define APP ((AppDelegate *)[[UIApplication sharedApplication] delegate])

@interface ViewController ()

@property NSURL *filepath;
@property NSMutableArray *allVoices;
@property BOOL buttonViewExpanded;
@property NSMutableArray *potentialVoices;
@property BOOL codeHighlighting;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString *file = [[NSBundle mainBundle] pathForResource:@"Hallelujah" ofType:@"abc" inDirectory: @"DefaultFiles"];
    _filepath = [NSURL fileURLWithPath:file];
    NSString *content = [NSString stringWithContentsOfFile:[_filepath path]  encoding:NSUTF8StringEncoding error:NULL];
    _codeHighlighting = YES;
    [self setColouredCodeFromString:content];
    _allVoices = [NSMutableArray array];
    _allVoices = [self getVoicesWithHeader];
    NSString *pdfFile = [[NSBundle mainBundle] pathForResource:@"Hallelujah_Partitur" ofType:@"pdf" inDirectory: @"DefaultFiles"];
    _displayView.displayMode = kPDFDisplaySinglePageContinuous;
    _displayView.displayDirection = kPDFDisplayDirectionHorizontal;
    [self loadPdfFromFilePath:pdfFile];
    self.server = APP.server;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification*)notification {
    CGFloat keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height;
    CGFloat keyboardAnimationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (_displayHeight.constant + 25 > keyboardHeight) {
        [UIView animateWithDuration:keyboardAnimationDuration*1.5 animations:^{
            self->_displayHeight.constant = self->_displayHeight.constant - keyboardHeight;
            [self.view layoutIfNeeded];
        }];
    }
    else {
        CGPoint newContentOffset = CGPointMake(_abcView.contentOffset.x, _abcView.contentOffset.y + keyboardHeight);
        [_abcView setContentOffset:newContentOffset animated:YES];
    }
    _abcView.frame = CGRectMake(_abcView.frame.origin.x, _abcView.frame.origin.y, _abcView.frame.size.width, _abcView.frame.size.height-keyboardHeight);
}


- (void)keyboardWillHide:(NSNotification*)notification {
    CGFloat keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height;
    if (_displayHeight.constant + keyboardHeight < self.view.frame.size.height) {
        CGFloat keyboardAnimationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        [UIView animateWithDuration:keyboardAnimationDuration*1.5 animations:^{
            self->_displayHeight.constant = self->_displayHeight.constant + keyboardHeight;
            [self.view layoutIfNeeded];
        }];
    }
}

- (void) loadPdfFromFilePath: (NSString*) filpath {
    NSURL *file = [NSURL fileURLWithPath:filpath];
    PDFDocument *pdf = [[PDFDocument alloc] initWithURL:file];
    _displayView.document = pdf;
    _displayView.maxScaleFactor = 4.0;
    _displayView.minScaleFactor = _displayView.scaleFactorForSizeToFit;
    _displayView.autoScales = true;
}

- (void) setColouredCodeFromString: (NSString*) code {
    NSMutableAttributedString *string;
    if (_codeHighlighting) {
        
        string = [[NSMutableAttributedString alloc]initWithString:code];
        NSArray *lines = [code componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) {
            if ([line hasPrefix:@"V:"]) {
                //voices
                NSRange range=[code rangeOfString:line];
                [string addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:range];
            }
            else if ([line hasPrefix:@"w:"]) {
                //lyrics
                NSRange range=[code rangeOfString:line];
                [string addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:range];
            }
            else if ([line hasPrefix:@"%%score"] || [line hasPrefix:@"%%staves"]) {
                //here we grab the parts to display
                NSRange range=[code rangeOfString:line];
                [string addAttribute:NSForegroundColorAttributeName value:[UIColor magentaColor] range:range];
            }
            else if ([line hasPrefix:@"%%"]) {
                //format attributes
                NSRange range=[code rangeOfString:line];
                [string addAttribute:NSForegroundColorAttributeName value:[UIColor brownColor] range:range];
            }
            else if ([line hasPrefix:@"%"]) {
                //comments
                NSRange range=[code rangeOfString:line];
                [string addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:range];
            }
            [code enumerateSubstringsInRange:NSMakeRange(0, [string.string length])
                                     options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop){
                                         if ([substring isEqualToString:@"|"] || [substring isEqualToString:@"]"] || [substring isEqualToString:@"["]) {
                                             [string addAttribute:NSForegroundColorAttributeName value: [UIColor blueColor] range:substringRange];
                                         }
                                         if ([substring isEqualToString:@"\""]) {
                                             [string addAttribute:NSForegroundColorAttributeName value: [UIColor greenColor] range:substringRange];
                                         }
                                     }];
        }
    }
    [_abcView setScrollEnabled:NO];
    NSRange cursorPosition = _abcView.selectedRange;
    if (_codeHighlighting) {
        [_abcView setAttributedText:string];
    }
    else _abcView.text = code;
    [_abcView setSelectedRange:cursorPosition];
    [_abcView setTintColor:[UIColor whiteColor]];
    [_abcView setScrollEnabled:YES];
}

- (NSMutableArray*) getVoicesWithHeader {
    NSArray* allLinedStrings = [_abcView.text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *header = [NSMutableArray array];
    BOOL headerRead = false;
    NSString *currentVoice;
    NSMutableArray *currentVoiceString = [NSMutableArray array];
    NSMutableArray *allVoices = [NSMutableArray array];
    NSMutableArray *userScoresAndStaves = [NSMutableArray array];
    for (NSString *line in allLinedStrings) {
        if (line.length > 2 && ![[line substringToIndex:2] isEqualToString:@"V:"] && !headerRead) {
            [header addObject: line];
            if ((line.length > 10) && ([[line substringToIndex:8] isEqualToString:@"%%staves"] || [[line substringToIndex:7] isEqualToString:@"%%score"]))
                [userScoresAndStaves addObject:line];
        }
        else {
            if (line.length > 2 && [[line substringToIndex:2] isEqualToString:@"V:"]){
                if (![line isEqualToString:currentVoice]) {
                    headerRead = true;
                    if (currentVoiceString.count > 0 && currentVoice != nil) {
                        NSArray *voice = [self voiceStringWithNameFromCleanedHeader:header withData:currentVoiceString];
                        [allVoices addObject:voice];
                    }
                    currentVoice = line;
                    [currentVoiceString removeAllObjects];
                }
            }
            [currentVoiceString addObject:line];
        }
    }
    NSArray *voice = [self voiceStringWithNameFromCleanedHeader:header withData:currentVoiceString];
    [allVoices addObject:voice];
    NSMutableArray *combinedVoicesWithName = [NSMutableArray array];
    for (int i = 0; i < userScoresAndStaves.count; i++) {
        NSString *string = userScoresAndStaves[i];
        NSArray *getStaveOrScoreName = [string componentsSeparatedByString:@"%"];
        NSString *staveOrScoreName = [getStaveOrScoreName lastObject];
        NSArray *stavesOrScoreOptions = [staveOrScoreName componentsSeparatedByString:@" "];
        if (stavesOrScoreOptions.count > 1) {
            staveOrScoreName = stavesOrScoreOptions[0];
        }
        NSString *combinedVoices;
        if (getStaveOrScoreName.count > 0) {
            for (int j = 0; j < allVoices.count; j++) {
                NSArray *array = allVoices[j];
                if (j == 0) {
                    NSString *headerToModify = array[1];
                    int incept = (int) [headerToModify rangeOfString:@"\n"].location;
                    combinedVoices = [[[headerToModify substringToIndex:incept] stringByAppendingString:[NSString stringWithFormat:@"\n%@", string]] stringByAppendingString:[headerToModify substringFromIndex:incept]];
                    if (stavesOrScoreOptions.count > 1) {
                        for (int k = 1; k < stavesOrScoreOptions.count; k++) {
                            NSString *option = stavesOrScoreOptions[k];
                            NSArray *optionSep = [option componentsSeparatedByString:@"="];
                            if (optionSep.count != 2) {
                                break;
                            }
                            else combinedVoices = [combinedVoices stringByAppendingString:[[@"\n%%" stringByAppendingString:optionSep[0]] stringByAppendingString:[NSString stringWithFormat:@" %@", optionSep[1]]]];
                        }
                    }
                }
                NSString *name = array[0];
                if ([string rangeOfString:name].location != NSNotFound) {
                    combinedVoices = [combinedVoices stringByAppendingString:[@"\n" stringByAppendingString: array[2]]];
                }
            }
        }
        [combinedVoicesWithName addObject:@[staveOrScoreName, combinedVoices]];
    }
    if (combinedVoicesWithName.count < 1) {
        _potentialVoices = [NSMutableArray array];
        for (NSArray *voice in allVoices) {
            [_potentialVoices addObject:voice[0]];
        }
    }
    return combinedVoicesWithName;
}

- (NSArray*) voiceStringWithNameFromCleanedHeader:(NSMutableArray*) header withData: (NSMutableArray*) currentVoiceString {
    
    NSString *cleanedHeader = header[0];
    NSArray *voiceInfo = [currentVoiceString[0] componentsSeparatedByString:@" "];
    NSString *name = [voiceInfo[0] substringFromIndex:2];
    for (int i = 1; i<header.count; i++) {
        NSString *line = header[i];
        if (line.length < 8) {
            cleanedHeader = [cleanedHeader stringByAppendingString:[NSString stringWithFormat:@"\n%@", line]];
        }
        else if (!([[line substringToIndex:8] isEqualToString:@"%%staves"]) && !([[line substringToIndex:7] isEqualToString:@"%%score"])) {
            cleanedHeader = [cleanedHeader stringByAppendingString:[NSString stringWithFormat:@"\n%@", line]];
        }
    }
    NSString *voice = currentVoiceString[0];
    for (int i = 1; i < currentVoiceString.count; i++) {
        NSString *voiceLine = currentVoiceString[i];
        voice = [voice stringByAppendingString:[NSString stringWithFormat:@"\n%@", voiceLine]];
    }
    return @[name, cleanedHeader, voice];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)moveHorizontalStack:(UIPanGestureRecognizer *)sender {
    if ( [sender locationInView:self.view].y < 23 || [sender locationInView:self.view].y > self.view.frame.size.height-24) {
        return;
    }
    else _displayHeight.constant = [sender locationInView:self.view].y;
}

- (IBAction)buttonViewSizeToggle:(id)sender {
    _buttonViewExpanded = !_buttonViewExpanded;
    _buttonViewHeight.constant = (_buttonViewExpanded) ? 100 : 24;;
}

- (void) loadABCfileFromPath: (NSString*) path {
    _filepath = [NSURL fileURLWithPath:path];
    NSString *content = [NSString stringWithContentsOfFile:[_filepath path]  encoding:NSUTF8StringEncoding error:NULL];
    content = [content stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    [self setColouredCodeFromString:content];
    
    [_allVoices removeAllObjects];
    _allVoices = [self getVoicesWithHeader];
}

- (void) enterFullScoreAndOrParts {
    NSArray *buttons = [NSArray arrayWithObjects:@"create full score only", @"create parts only", @"create full score and parts", nil];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"no rule to create parts or a full score found!" message:@"choose to add full score, parts or both:" preferredStyle:UIAlertControllerStyleAlert];
    for (NSString *title in buttons) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            NSString *addFullScore = @"\n%%score ";
            NSString *addParts = @"";
            for (NSString *name in self->_potentialVoices) {
                addFullScore = [addFullScore stringByAppendingString:[NSString stringWithFormat:@"%@ ", name]];
                NSString *part = @"\n%%staves ";
                addParts = [addParts stringByAppendingString:[[part stringByAppendingString:[NSString stringWithFormat:@"%@ ", name]] stringByAppendingString:[@"%" stringByAppendingString:[NSString stringWithFormat:@"%@ scale=0.7 barsperstaff=8", name]]]];
            }
            addFullScore = [addFullScore stringByAppendingString:@"%Partitur scale=0.6 barsperstaff=4"];
            NSMutableString *orig = [NSMutableString stringWithString:self->_abcView.text];
            NSRange location = [orig rangeOfString:@"\n"];
            NSString *inserted = [[[[orig substringToIndex:location.location] stringByAppendingString:([title isEqualToString:@"create full score only"] || [title isEqualToString:@"create full score and parts"]) ? addFullScore : @"" ] stringByAppendingString:([title isEqualToString:@"create parts only"] || [title isEqualToString:@"create full score and parts"]) ? addParts : @""] stringByAppendingString:[orig substringFromIndex:location.location]];
            [self setColouredCodeFromString:inserted];
            [self->_allVoices removeAllObjects];
            self->_allVoices = [self getVoicesWithHeader];
        }];
        [alert addAction:action];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)buttonPressed:(UIButton *)sender {
    if (sender.tag == 0) {
        //load
        NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSArray *directory = [fileManager contentsOfDirectoryAtPath:docsPath error:nil];
        NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.abc'"];
        NSArray *abcFiles = [directory filteredArrayUsingPredicate:fltr];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"load abc-Tune:" message:@"to add tunes put them in the apps Shared Folder with iTunes." preferredStyle:UIAlertControllerStyleAlert];
        for (NSString *fileName in abcFiles){
            UIAlertAction *action = [UIAlertAction actionWithTitle:fileName style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self loadABCfileFromPath:[docsPath stringByAppendingPathComponent:fileName]];
            }];
            [alert addAction:action];
        }
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else if (sender.tag == 1) {
            //store
        NSError *error;
        BOOL write = [_abcView.text writeToURL:_filepath atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (!write) {
            NSLog(@"could not write file: %@", error);
        }
    }
    else if (sender.tag == 2) {
        //display
        _allVoices = [self getVoicesWithHeader]; //refresh from input
        if (_allVoices.count < 1) {
            [self enterFullScoreAndOrParts];
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"display voice" message:@"choose the voice to display" preferredStyle:UIAlertControllerStyleAlert];
        for (NSArray *voice in _allVoices) {
            NSString *voiceName = voice[0];
            UIAlertAction *action = [UIAlertAction actionWithTitle:voiceName style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                NSLog(@"display voice: %@", voice);
                NSString *fileName = [[self->_filepath lastPathComponent] substringToIndex:[self->_filepath lastPathComponent].length-4];
                [self loadPdfFromFilePath:[[NSBundle mainBundle] pathForResource:[fileName stringByAppendingString:[NSString stringWithFormat:@"_%@", voiceName]] ofType:@"pdf" inDirectory: @"DefaultFiles"]];
            }];
            [alert addAction:action];
        }
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else if (sender.tag == 3) {
        //refresh:
        [self setColouredCodeFromString:_abcView.text];
    }
}

- (IBAction)zoomText:(UIPinchGestureRecognizer *)sender {
    float scale = ((sender.scale <=2) ? sender.scale : 2) - 1;
    CGFloat size = _abcView.font.pointSize + (scale * 0.5);
    _abcView.font = [UIFont systemFontOfSize:size];
}

- (IBAction)startHTTPserver:(UISwitch *)sender {
    if (sender.isOn) {
        if(![self.server start]) {
            [_serverSwitch setOn:NO];
            return;
        }
        [self performSelector:@selector(updateServerLabel) withObject:self afterDelay:1.0];
    }
    else {
        [self.server stop];
        _serverLabel.text = @"start http-server";
    }
}

- (IBAction)codeHighlightingEnabled:(UISwitch*)sender {
    _codeHighlighting = sender.isOn;
    [self setColouredCodeFromString:_abcView.text];
    _codeHighlightingLabel.text = (_codeHighlighting) ? @"abc-code highlighting enabled" : @"enable abc-code highlighting";
}

-(void) updateServerLabel {
    [self.serverLabel setText: [NSString stringWithFormat:@"connect to: http://%@.local:%d", self.server.hostName, self.server.port]];
}
- (IBAction)hideKeyboard:(id)sender {
    [_abcView endEditing:YES];
}

@end
