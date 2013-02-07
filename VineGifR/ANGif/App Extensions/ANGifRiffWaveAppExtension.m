//
//  ANGifRiffWaveAppExtension.m
//  VineGifR
//
//  Created by denys on 07.02.13.
//  Copyright (c) 2013 Esten Hurtle. All rights reserved.
//

#import "ANGifRiffWaveAppExtension.h"
#import "ANGifDataSubblock.h"

@implementation ANGifRiffWaveAppExtension

@synthesize waveData;

-(id) initWithWaveData:(NSData *)sourceWave {
	if ((self = [super init])) {
        // get data length without header
        UInt32 rawDataLength;
        [sourceWave getBytes:&rawDataLength range:NSMakeRange(4, 4)];
        rawDataLength = rawDataLength - 4;
        
        NSRange rawDataRange = NSMakeRange(12, rawDataLength);
        NSData * rawData = [sourceWave subdataWithRange:rawDataRange];
        
        NSMutableData * appData = [NSMutableData data];
        // split data to subblocks
        // should be moved to ANGifAppExtension
        NSArray * subBlocks = [ANGifDataSubblock dataSubblocksForData:rawData];
        for (ANGifDataSubblock * subBlock in subBlocks) {
            [appData appendData:[subBlock encodeBlock]];
        }
		
		self.applicationData = [NSData dataWithData:appData];
		self.applicationIdentifier = [NSData dataWithBytes:"RIFFWAVE" length:8];
		self.applicationAuthCode = [NSData dataWithBytes:"\x0\x0\x0 " length:3];
	}
	return self;
}

@end
