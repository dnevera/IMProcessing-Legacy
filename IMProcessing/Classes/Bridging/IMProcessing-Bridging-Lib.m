//
//  IMProcessing-Bridg-Lib.m
//  Pods
//
//  Created by denis svinarchuk on 03.05.17.
//
//

#import "IMProcessing-Bridging-Lib.h"
#import "IMPOperations-Bridging-Metal.h"

@implementation IMPBridge
+ (float3) xyz_2_luv:(float3)xyz {
    return IMPxyz_2_luv(xyz);
}
+ (float3) luv_2_xyz:(float3) luv{
    return IMPluv_2_xyz(luv);
}

+ (float3) rgb_2_hsv:(float3)rgb {
    return IMPrgb_2_HSV(rgb);
}

+ (float3) hsv_2_rgb:(float3)hsv{
    return IMPHSV_2_rgb(hsv);
}

+ (float3) rgb_2_xyz:(float3)rgb {
    return IMPrgb_2_XYZ(rgb);
}

+ (float3) xyz_2_rgb:(float3)xyz {
    return IMPXYZ_2_rgb(xyz);
}

+ (float3) lab_2_xyz:(float3)lab {
    return IMPLab_2_XYZ(lab);
}

+ (float3) xyz_2_lab:(float3)xyz {
    return IMPXYZ_2_Lab(xyz);
}

+ (float3) lab_2_lch:(float3)lab {
    return IMPLab_2_Lch(lab);
}

+ (float3) lch_2_lab:(float3)lch {
    return IMPLch_2_Lab(lch);
}

+ (float3) rgb_2_hsl:(float3)rgb {
    return IMPrgb_2_HSL(rgb);
}

+ (float3) hsl_2_rgb:(float3)hsl{
    return IMPHSL_2_rgb(hsl);
}

+ (float3) rgb_2_ycbcrHD:(float3)rgb{
    return IMPrgb_2_YCbCrHD(rgb);
}

+ (float3) ycbcrHD_2_rgb:(float3)ycbcr{
    return IMPYCbCrHD_2_rgb(ycbcr);
}


@end
