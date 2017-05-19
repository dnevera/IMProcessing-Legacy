//
//  IMProcessing-Bridg-Lib.h
//  Pods
//
//  Created by denis svinarchuk on 03.05.17.
//
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

#include "IMPConstants-Bridging-Metal.h"
#include "IMPTypes-Bridging-Metal.h"

@interface IMPBridge : NSObject

+ (float3) rgb2xyz:(float3)color;     // 1
+ (float3) rgb2lab:(float3)color;     // 2
+ (float3) rgb2lch:(float3)color;     // 3
+ (float3) rgb2luv:(float3)color;     // 4
+ (float3) rgb2hsv:(float3)color;     // 5
+ (float3) rgb2hsl:(float3)color;     // 6
+ (float3) rgb2ycbcrHD:(float3)color; // 7

+ (float3) srgb2xyz:(float3)color;     // 1
+ (float3) srgb2lab:(float3)color;     // 2
+ (float3) srgb2lch:(float3)color;     // 3
+ (float3) srgb2luv:(float3)color;     // 4
+ (float3) srgb2hsv:(float3)color;     // 5
+ (float3) srgb2hsl:(float3)color;     // 6
+ (float3) srgb2ycbcrHD:(float3)color; // 7

+ (float3) hsv2rgb:(float3)color;     // 1
+ (float3) hsv2srgb:(float3)color;     // 1
+ (float3) hsv2xyz:(float3)color;     // 2
+ (float3) hsv2lab:(float3)color;     // 3
+ (float3) hsv2lch:(float3)color;     // 4
+ (float3) hsv2luv:(float3)color;     // 5
+ (float3) hsv2ycbcrHD:(float3)color; // 6
+ (float3) hsv2hsl:(float3)color;     // 7

+ (float3) hsl2rgb:(float3)color;
+ (float3) hsl2srgb:(float3)color;
+ (float3) hsl2hsv:(float3)color;
+ (float3) hsl2lab:(float3)color;
+ (float3) hsl2lch:(float3)color;
+ (float3) hsl2luv:(float3)color;
+ (float3) hsl2xyz:(float3)color;
+ (float3) hsl2ycbcrHD:(float3)color;  // 7

+ (float3) xyz2rgb:(float3)color;
+ (float3) xyz2srgb:(float3)color;
+ (float3) xyz2lab:(float3)color;
+ (float3) xyz2lch:(float3)color;
+ (float3) xyz2luv:(float3)color;
+ (float3) xyz2hsv:(float3)color;
+ (float3) xyz2hsl:(float3)color;
+ (float3) xyz2ycbcrHD:(float3)color;  // 7

+ (float3) lab2rgb:(float3)color;
+ (float3) lab2srgb:(float3)color;
+ (float3) lab2lch:(float3)color;
+ (float3) lab2luv:(float3)color;
+ (float3) lab2hsv:(float3)color;
+ (float3) lab2hsl:(float3)color;
+ (float3) lab2xyz:(float3)color;
+ (float3) lab2ycbcrHD:(float3)color; // 7

+ (float3) luv2rgb:(float3)color;
+ (float3) luv2srgb:(float3)color;
+ (float3) luv2lab:(float3)color;
+ (float3) luv2lch:(float3)color;
+ (float3) luv2hsv:(float3)color;
+ (float3) luv2hsl:(float3)color;
+ (float3) luv2xyz:(float3)color;
+ (float3) luv2ycbcrHD:(float3)color; // 7

+ (float3) lch2rgb:(float3)color;
+ (float3) lch2srgb:(float3)color;
+ (float3) lch2lab:(float3)color;
+ (float3) lch2luv:(float3)color;
+ (float3) lch2hsv:(float3)color;
+ (float3) lch2hsl:(float3)color;
+ (float3) lch2xyz:(float3)color;
+ (float3) lch2ycbcrHD:(float3)color;

+ (float3) ycbcrHD2rgb:(float3)color;
+ (float3) ycbcrHD2srgb:(float3)color;
+ (float3) ycbcrHD2lab:(float3)color;
+ (float3) ycbcrHD2lch:(float3)color;
+ (float3) ycbcrHD2luv:(float3)color;
+ (float3) ycbcrHD2hsv:(float3)color;
+ (float3) ycbcrHD2hsl:(float3)color;
+ (float3) ycbcrHD2xyz:(float3)color;

+ (float3) convert:(IMPColorSpaceIndex)from to:(IMPColorSpaceIndex)to value:(float3)value;

@end
