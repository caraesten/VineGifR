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
#import "ANGifRiffWaveAppExtension.h"
#define kExportSampleCount 2056
#define kDelayTime 0.2

#define waveHeader      "RIFF    WAVE" \
                        "fmt \x10\x0\x0\x0" \
                        "\x1\x0\x1\x0\x80\x3e\x0\x0\x0\x7D\x0\x0\x2\x0\x10\x0" \
                        "data    "

@implementation VGFRAppDelegate

@synthesize urlField,gifitButton, statusLabel, qualitySelector, soundCheckbox;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}
- (void) handleCleanup
{
    [qualitySelector setEnabled:YES];
    [gifitButton setEnabled:YES];
    [urlField setEditable:YES];
}
- (IBAction)doGif:(id)sender
{
    [gifitButton setEnabled:NO];
    [urlField setEditable:NO];
    [qualitySelector setEnabled:NO];
    NSURL *vineURL = [NSURL URLWithString:[urlField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
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
- (NSData *)getWaveDataFromAVAsset:(AVAsset *) asset
{
    // load first audio track, exit if asset contain no audio tracks
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if ([audioTracks count] == 0)
        return nil;
    AVAssetTrack *audioTrack = [audioTracks objectAtIndex:0];
    
    // create asset reader
    NSError *assetError = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        NSLog(@"Asset error: %@", assetError);
        return nil;
    }
    
    // riff wave format
    // linear PCM, 16000hz, solo, 16 bits per sample, little endian (default for riff)
    NSDictionary *waveAudioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                       [NSNumber numberWithFloat:16000.0], AVSampleRateKey,
                                       [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                       [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                       [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                       [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                       nil];
    AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack
                                                                             outputSettings:waveAudioSettings];
    if (! [assetReader canAddOutput:output]) {
        NSLog(@"Can't add output");
    }
    [assetReader addOutput:output];
   
    NSMutableData * waveData = [NSMutableData dataWithBytes:waveHeader length:44];
    
    [assetReader startReading];
    CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
    while (sampleBuffer) {
        AudioBufferList  audioBufferList;
        CMBlockBufferRef blockBuffer;
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                NULL, &audioBufferList,
                                                                sizeof(audioBufferList),
                                                                NULL, NULL, 0,
                                                                &blockBuffer);
        
        for (int y = 0; y < audioBufferList.mNumberBuffers; y++) {
            AudioBuffer audioBuffer = audioBufferList.mBuffers[y];
            [waveData appendBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        }
        
        sampleBuffer = [output copyNextSampleBuffer];
    }
    
    // write file size to header
    UInt32 fileLength = (unsigned int) [waveData length] - 8;
    [waveData replaceBytesInRange:NSMakeRange(4, 4) withBytes:&fileLength];
    UInt32 dataLength = fileLength - 36;
    [waveData replaceBytesInRange:NSMakeRange(40, 4) withBytes:&dataLength];
    
    // [waveData writeToFile:@"/Users/dp/Documents/test.wav" atomically:YES];
	return [NSData dataWithData:waveData];
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

    // load file to temp folder
    // extracting stream works only with local assets
    [statusLabel setStringValue:@"Downloading video"];
    NSData *data = [NSData dataWithContentsOfURL:videoURL];
    // TODO: could fail if more than one copy would launched
    NSString *localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vinegifer.mp4"];
    [data writeToFile:localFilePath atomically:YES];
    NSURL *localVideoUrl = [NSURL fileURLWithPath:localFilePath];
    
    AVURLAsset *videoData = [AVURLAsset URLAssetWithURL:localVideoUrl options:nil];
    
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
    
    NSInteger qualityOption = [qualitySelector selectedSegment];
    
    double secondIncrement = qualityOption == 0 ? 0.22 : 0.1;

    while (CMTimeCompare(currentTime, videoData.duration) < 0){
        CGImageRef img = [gen copyCGImageAtTime:currentTime actualTime:nil error:nil];
        NSSize tempSize = NSMakeSize(CGImageGetWidth(img), CGImageGetHeight(img));
        NSImage *fullImage = [[NSImage alloc] initWithCGImage:img size:tempSize];
        if (fullImage.size.height == 0 || fullImage.size.width == 0) {
            seconds += secondIncrement;
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
        seconds += secondIncrement;
        currentTime = CMTimeMakeWithSeconds(seconds, timeScale);
        img = nil;
    }
    
    NSData * waveData;
    if ([soundCheckbox state]) {
        [statusLabel setStringValue:@"Extracting sound"];
        waveData = [self getWaveDataFromAVAsset:videoData];
    }
    
    [statusLabel setStringValue:@"Saving gif"];
    ANGifEncoder *enc = [[ANGifEncoder alloc] initWithOutputFile:[saveFile path] size:gifSize globalColorTable:nil];
    [enc addApplicationExtension:[[ANGifNetscapeAppExtension alloc] initWithRepeatCount:0xffff]];
    
    if (waveData) {
        [enc addApplicationExtension:[[ANGifRiffWaveAppExtension alloc] initWithWaveData:waveData]];
    }
    
    for (NSImage *img in gifImages){
        [enc addImageFrame:[self imageFrameWithImage:img increment:secondIncrement]];
    }
    [enc closeFile];
    [statusLabel setStringValue:@"Done"];
    [urlField setStringValue:@""];
    [self handleCleanup];
}
// Via Giraffe
- (ANGifImageFrame *)imageFrameWithImage:(NSImage *)anImage increment:(double) inc {
	NSImage * scaledImage = anImage;
	NSImagePixelSource * pixelSource = [[NSImagePixelSource alloc] initWithImage:scaledImage];
	ANCutColorTable * colorTable = [[ANCutColorTable alloc] initWithTransparentFirst:NO pixelSource:pixelSource];
	ANGifImageFrame * frame = [[ANGifImageFrame alloc] initWithPixelSource:pixelSource colorTable:colorTable delayTime:inc];
#if !__has_feature(objc_arc)
	[colorTable release];
	[pixelSource release];
	[frame autorelease];
#endif
	return frame;
}
@end
