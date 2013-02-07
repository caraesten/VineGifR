//
//  VGFRAppDelegate.h
//  VineGifR
//
//  Created by Esten Hurtle on 1/27/13.
//  Copyright (c) 2013 Esten Hurtle. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TFHpple.h"

@interface VGFRAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *gifitButton;
@property (assign) IBOutlet NSTextField *urlField;
@property (assign) IBOutlet NSTextField *statusLabel;
@property (assign) IBOutlet NSSegmentedControl *qualitySelector;
@property (assign) IBOutlet NSButton *soundCheckbox;

-(IBAction)doGif:(id)sender;

@end
