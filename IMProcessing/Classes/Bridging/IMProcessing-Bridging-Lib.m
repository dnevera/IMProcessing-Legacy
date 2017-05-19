//
//  IMProcessing-Bridg-Lib.m
//  Pods
//
//  Created by denis svinarchuk on 03.05.17.
//
//

#import "IMProcessing-Bridging-Lib.h"
#import "IMPColorSpaces-Bridging-Metal.h"

@implementation IMPBridge

+ (float3) rgb2xyz:(float3)color     { return IMPrgb2xyz(color); }
+ (float3) rgb2lab:(float3)color     { return IMPrgb2lab(color); }
+ (float3) rgb2lch:(float3)color     { return IMPrgb2lch(color); }
+ (float3) rgb2luv:(float3)color     { return IMPrgb2luv(color); }
+ (float3) rgb2hsv:(float3)color     { return IMPrgb2hsv(color); }
+ (float3) rgb2hsl:(float3)color     { return IMPrgb2hsl(color); }
+ (float3) rgb2ycbcrHD:(float3)color { return IMPrgb2ycbcrHD(color); }

+ (float3) srgb2xyz:(float3)color     { return IMPsrgb2xyz(color); }
+ (float3) srgb2lab:(float3)color     { return IMPsrgb2lab(color); }
+ (float3) srgb2lch:(float3)color     { return IMPsrgb2lch(color); }
+ (float3) srgb2luv:(float3)color     { return IMPsrgb2luv(color); }
+ (float3) srgb2hsv:(float3)color     { return IMPsrgb2hsv(color); }
+ (float3) srgb2hsl:(float3)color     { return IMPsrgb2hsl(color); }
+ (float3) srgb2ycbcrHD:(float3)color { return IMPsrgb2ycbcrHD(color); }

+ (float3) hsv2rgb:(float3)color     { return IMPhsv2rgb(color); }
+ (float3) hsv2srgb:(float3)color     { return IMPhsv2srgb(color); }
+ (float3) hsv2xyz:(float3)color     { return IMPhsv2xyz(color); }
+ (float3) hsv2lab:(float3)color     { return IMPhsv2lab(color); }
+ (float3) hsv2lch:(float3)color     { return IMPhsv2lch(color); }
+ (float3) hsv2luv:(float3)color     { return IMPhsv2luv(color); }
+ (float3) hsv2ycbcrHD:(float3)color { return IMPhsv2ycbcrHD(color); }
+ (float3) hsv2hsl:(float3)color     { return IMPhsv2hsl(color); }

+ (float3) hsl2rgb:(float3)color     { return IMPhsl2rgb(color); }
+ (float3) hsl2srgb:(float3)color     { return IMPhsl2srgb(color); }
+ (float3) hsl2hsv:(float3)color     { return IMPhsl2hsv(color); }
+ (float3) hsl2lab:(float3)color     { return IMPhsl2lab(color); }
+ (float3) hsl2lch:(float3)color     { return IMPhsl2lch(color); }
+ (float3) hsl2luv:(float3)color     { return IMPhsl2luv(color); }
+ (float3) hsl2xyz:(float3)color     { return IMPhsl2xyz(color); }
+ (float3) hsl2ycbcrHD:(float3)color { return IMPhsl2ycbcrHD(color); }

+ (float3) xyz2rgb:(float3)color     { return IMPxyz2rgb(color); }
+ (float3) xyz2srgb:(float3)color     { return IMPxyz2srgb(color); }
+ (float3) xyz2lab:(float3)color     { return IMPxyz2lab(color); }
+ (float3) xyz2lch:(float3)color     { return IMPxyz2lch(color); }
+ (float3) xyz2luv:(float3)color     { return IMPxyz2luv(color); }
+ (float3) xyz2hsv:(float3)color     { return IMPxyz2hsv(color); }
+ (float3) xyz2hsl:(float3)color     { return IMPxyz2hsl(color); }
+ (float3) xyz2ycbcrHD:(float3)color { return IMPxyz2ycbcrHD(color); }

+ (float3) lab2rgb:(float3)color     { return IMPlab2rgb(color); }
+ (float3) lab2srgb:(float3)color     { return IMPlab2srgb(color); }
+ (float3) lab2lch:(float3)color     { return IMPlab2lch(color); }
+ (float3) lab2luv:(float3)color     { return IMPlab2luv(color); }
+ (float3) lab2hsv:(float3)color     { return IMPlab2hsv(color); }
+ (float3) lab2hsl:(float3)color     { return IMPlab2hsl(color); }
+ (float3) lab2xyz:(float3)color     { return IMPlab2xyz(color); }
+ (float3) lab2ycbcrHD:(float3)color { return IMPlab2ycbcrHD(color); }

+ (float3) luv2rgb:(float3)color     { return IMPluv2rgb(color); }
+ (float3) luv2srgb:(float3)color     { return IMPluv2srgb(color); }
+ (float3) luv2lab:(float3)color     { return IMPluv2lab(color); }
+ (float3) luv2lch:(float3)color     { return IMPluv2lch(color); }
+ (float3) luv2hsv:(float3)color     { return IMPluv2hsv(color); }
+ (float3) luv2hsl:(float3)color     { return IMPluv2hsl(color); }
+ (float3) luv2xyz:(float3)color     { return IMPluv2xyz(color); }
+ (float3) luv2ycbcrHD:(float3)color { return IMPluv2ycbcrHD(color); }

+ (float3) lch2rgb:(float3)color     { return IMPlch2rgb(color); }
+ (float3) lch2srgb:(float3)color     { return IMPlch2srgb(color); }
+ (float3) lch2lab:(float3)color     { return IMPlch2lab(color); }
+ (float3) lch2luv:(float3)color     { return IMPlch2luv(color); }
+ (float3) lch2hsv:(float3)color     { return IMPlch2hsv(color); }
+ (float3) lch2hsl:(float3)color     { return IMPlch2hsv(color); }
+ (float3) lch2xyz:(float3)color     { return IMPlch2xyz(color); }
+ (float3) lch2ycbcrHD:(float3)color { return IMPlch2ycbcrHD(color); }

+ (float3) ycbcrHD2rgb:(float3)color     { return IMPycbcrHD2rgb(color); }
+ (float3) ycbcrHD2srgb:(float3)color     { return IMPycbcrHD2srgb(color); }
+ (float3) ycbcrHD2lab:(float3)color     { return IMPycbcrHD2lab(color); }
+ (float3) ycbcrHD2lch:(float3)color     { return IMPycbcrHD2lch(color); }
+ (float3) ycbcrHD2luv:(float3)color     { return IMPycbcrHD2luv(color); }
+ (float3) ycbcrHD2hsv:(float3)color     { return IMPycbcrHD2hsv(color); }
+ (float3) ycbcrHD2hsl:(float3)color     { return IMPycbcrHD2hsl(color); }
+ (float3) ycbcrHD2xyz:(float3)color     { return IMPycbcrHD2xyz(color); }

+ (float3) convert:(IMPColorSpaceIndex)from to:(IMPColorSpaceIndex)to value:(vector_float3)value {
    return IMPConvertColor(from, to, value);
}

@end
