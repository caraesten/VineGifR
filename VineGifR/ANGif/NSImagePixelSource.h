//
//  UIImagePixelSource.h
//  Giraffe
//
//  Created by Alex Nichol on 11/5/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ANGifImageFramePixelSource.h"
#import "ANImageBitmapRep.h"

@interface NSImagePixelSource : NSObject <ANGifImageFramePixelSource> {
	ANImageBitmapRep * imageRep;
}

- (id)initWithImage:(NSImage *)anImage;
+ (NSImagePixelSource *)pixelSourceWithImage:(NSImage *)anImage;

@end
