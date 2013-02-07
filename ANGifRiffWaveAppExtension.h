//
//  ANGifRiffWaveAppExtension.h
//  VineGifR
//
//  Created by denys on 07.02.13.
//  Copyright (c) 2013 Esten Hurtle. All rights reserved.
//

#import "ANGifAppExtension.h"

@interface ANGifRiffWaveAppExtension : ANGifAppExtension {
    NSData * waveData;
}

@property (readonly) NSData * waveData;

-(id) initWithWaveData:(NSData *) sourceWave;

@end
