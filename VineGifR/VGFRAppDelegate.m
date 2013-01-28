//
//  VGFRAppDelegate.m
//  VineGifR
//
//  Created by Esten Hurtle on 1/27/13.
//  Copyright (c) 2013 Esten Hurtle. All rights reserved.
//

#import "VGFRAppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "ANGifEncoder.h"
#import "ANCutColorTable.h"
#import "NSImagePixelSource.h"
#import "ANGifNetscapeAppExtension.h"
#define kExportSampleCount 2056
#define kDelayTime 0.2

@implementation VGFRAppDelegate

@synthesize urlField,gifitButton, statusLabel;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}
- (void) handleCleanup
{
    [gifitButton setEnabled:YES];
    [urlField setEditable:YES];
}
- (IBAction)doGif:(id)sender
{
    [gifitButton setEnabled:NO];
    [urlField setEditable:NO];
    NSURL *vineURL = [NSURL URLWithString:urlField.stringValue];
    if (vineURL && vineURL.scheme && vineURL.host && [vineURL.host isEqualToString:@"vine.co"] ) {
        // Seems legit, get save location
        NSSavePanel *saveObj = [NSSavePanel savePanel];
        [saveObj setAllowedFileTypes:@[@"gif"]];
        NSInteger respInt = [saveObj runModal];
        NSURL *saveFile;
        if (respInt == NSOKButton) {
            saveFile = [saveObj URL];
        }
        else {
            [self handleCleanup];
            return;
        }
        NSDictionary *options = @{@"URL": vineURL, @"saveFile": saveFile};
        [self performSelectorInBackground:@selector(renderGifWithOptions:) withObject:options];
    }
    else {
        [statusLabel setStringValue:@"That isn't a Vine URL"];
        [self handleCleanup];
        return;
    }
    
}

- (void)renderGifWithOptions:(NSDictionary *) options
{
    NSURL *saveFile = [options objectForKey:@"saveFile"];
    NSURL *vineURL = [options objectForKey:@"URL"];
    NSData *vineData = [NSData dataWithContentsOfURL:vineURL];
    TFHpple *vineDoc = [[TFHpple alloc] initWithHTMLData:vineData];
    NSArray *videoStuff = [vineDoc searchWithXPathQuery:@"//video"];
    if (videoStuff.count != 1) {
        [statusLabel setStringValue:@"Vine page had unexpected content"];
        [self handleCleanup];
        return;
    }
    TFHppleElement *element = [videoStuff objectAtIndex:0];
    element = [[element children] objectAtIndex:0];
    NSString *videoURLString =  [element objectForKey:@"src"];
    NSURL *videoURL = [NSURL URLWithString:videoURLString];
    [statusLabel setStringValue:@"Downloading video"];
    AVURLAsset *videoData = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    NSMutableArray *gifImages = [[NSMutableArray alloc] init];
    int32_t timeScale = 24;
    Float64 seconds = 0.0;
    CMTime currentTime = CMTimeMakeWithSeconds(seconds, timeScale);
    AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:videoData];
    NSSize gifSize;
    gen.requestedTimeToleranceAfter = kCMTimeZero;
    gen.requestedTimeToleranceBefore = kCMTimeZero;
    gen.appliesPreferredTrackTransform = YES;
    [statusLabel setStringValue:@"Extracting images"];
    while (CMTimeCompare(currentTime, videoData.duration) < 0){
        CGImageRef img = [gen copyCGImageAtTime:currentTime actualTime:nil error:nil];
        NSSize tempSize = NSMakeSize(CGImageGetWidth(img), CGImageGetHeight(img));
        NSImage *fullImage = [[NSImage alloc] initWithCGImage:img size:tempSize];
        if (fullImage.size.height == 0 || fullImage.size.width == 0) {
            seconds += 0.2;
            currentTime = CMTimeMakeWithSeconds(seconds, timeScale);
            continue;
        }
        int newWidth = fullImage.size.width / 2;
        int newHeight = fullImage.size.height / 2;
        NSImage *frameImage = [[NSImage alloc] initWithSize:NSMakeSize(newWidth, newHeight)];
        [frameImage lockFocus];
        [fullImage drawInRect:NSMakeRect(0, 0, newWidth, newHeight) fromRect:NSMakeRect(0, 0, fullImage.size.width, fullImage.size.height) operation:NSCompositeSourceOver fraction:1.0];
        [frameImage unlockFocus];
        [gifImages addObject:frameImage];
        gifSize = frameImage.size;
        seconds += 0.2;
        currentTime = CMTimeMakeWithSeconds(seconds, timeScale);
        img = nil;
    }
    [statusLabel setStringValue:@"Saving gif"];
    ANGifEncoder *enc = [[ANGifEncoder alloc] initWithOutputFile:[saveFile path] size:gifSize globalColorTable:nil];
    [enc addApplicationExtension:[[ANGifNetscapeAppExtension alloc] initWithRepeatCount:0xffff]];
    for (NSImage *img in gifImages){
        [enc addImageFrame:[self imageFrameWithImage:img]];
    }
    [enc closeFile];
    [statusLabel setStringValue:@"Done"];
    [urlField setStringValue:@""];
    [self handleCleanup];
}
// Via Giraffe
- (ANGifImageFrame *)imageFrameWithImage:(NSImage *)anImage  {
	NSImage * scaledImage = anImage;
	NSImagePixelSource * pixelSource = [[NSImagePixelSource alloc] initWithImage:scaledImage];
	ANCutColorTable * colorTable = [[ANCutColorTable alloc] initWithTransparentFirst:YES pixelSource:pixelSource];
	ANGifImageFrame * frame = [[ANGifImageFrame alloc] initWithPixelSource:pixelSource colorTable:colorTable delayTime:0.2];
#if !__has_feature(objc_arc)
	[colorTable release];
	[pixelSource release];
	[frame autorelease];
#endif
	return frame;
}
@end
