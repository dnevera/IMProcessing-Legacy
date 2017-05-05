//
//  IMPColorSpaces_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPColorSpaces_metal_h
#define IMPColorSpaces_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;
#ifdef __cplusplus

namespace IMProcessing
{
#include "IMPOperations-Bridging-Metal.h"
    
    //
    // luv sources: https://www.ludd.ltu.se/~torger/dcamprof.html
    //

    inline float3 rgb_2_HSV(float3 c) {
        return IMPrgb_2_HSV(c);
    }

    inline float3 HSV_2_rgb(float3 c) {
        return IMPHSV_2_rgb(c);
    }

    
    inline float3 rgb_2_HSL(float3 color)
    {
        return IMPrgb_2_HSL(color);
    }
    
    inline float3 HSL_2_rgb(float3 hsl)
    {
        return IMPHSL_2_rgb(hsl);
    }
    
    inline float3 rgb_2_XYZ(float3 rgb)
    {
        return IMPrgb_2_XYZ(rgb);
    }
    
    inline float3 XYZ_2_rgb (float3 xyz){
        return IMPXYZ_2_rgb(xyz);
    }
    
    inline float3 Lab_2_XYZ(float3 lab){
        return IMPLab_2_XYZ(lab);
    }
    
    inline float3 XYZ_2_Lab(float3 xyz)
    {
        return IMPXYZ_2_Lab(xyz);
    }
    
    inline float3 Lab_2_rgb(float3 lab) {
        float3 xyz = Lab_2_XYZ(lab);
        return XYZ_2_rgb(xyz);
    }
    
    inline float3 rgb_2_Lab(float3 rgb) {
        float3 xyz = rgb_2_XYZ(rgb);
        return XYZ_2_Lab(xyz);
    }
    
    inline float3 rgb_2_YCbCrHD(float3 rgb){
        return IMPrgb_2_YCbCrHD(rgb);
    }
    
    inline float3 YCbCrHD_2_rgb(float3 YCbCr){
        return IMPYCbCrHD_2_rgb(YCbCr);
    }
    
   
    inline float rgb_gamma_correct(float c, float gamma)
    {
        const float a = 0.055;
        if(c < 0.0031308)
            return 12.92*c;
        else
            return (1.0+a)*pow(c, 1.0/gamma) - a;
    }
    
    inline float3 rgb_gamma_correct (float3 rgb, float gamma) {
        return float3(
                      rgb_gamma_correct(rgb.x,gamma),
                      rgb_gamma_correct(rgb.y,gamma),
                      rgb_gamma_correct(rgb.z,gamma)
                      );
    }
}
#endif

#endif
#endif /* IMPColorSpaces_metal_h */
