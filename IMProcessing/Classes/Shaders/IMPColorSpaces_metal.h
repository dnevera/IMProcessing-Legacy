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

    inline float rgb_2_L(float3 color)
    {
        float fmin = min_component(color); //Min. value of RGB
        float fmax = max_component(color); //Max. value of RGB
        
        return (fmax + fmin) * 0.5; // Luminance
    }

    inline float3 rgb_2_HSV(float3 c) {
        return IMPrgb_2_HSV(c);
    }

    inline float3 HSV_2_rgb(float3 c) {
        return IMPHSV_2_rgb(c);
    }

    
    inline float3 rgb_2_HSL(float3 color)
    {
        float3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)
        
        float fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
        float fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB
        float delta = fmax - fmin;             //Delta RGB value
        
        hsl.z = clamp((fmax + fmin) * 0.5, 0.0, 1.0); // Luminance
        
        if (delta == 0.0)   //This is a gray, no chroma...
        {
            hsl.x = 0.0;	// Hue
            hsl.y = 0.0;	// Saturation
        }
        else                //Chromatic data...
        {
            if (hsl.z < 0.5)
                hsl.y = delta / (fmax + fmin); // Saturation
            else
                hsl.y = delta / (2.0 - fmax - fmin); // Saturation
            
            float deltaR = (((fmax - color.r) / 6.0) + (delta * 0.5)) / delta;
            float deltaG = (((fmax - color.g) / 6.0) + (delta * 0.5)) / delta;
            float deltaB = (((fmax - color.b) / 6.0) + (delta * 0.5)) / delta;
            
            if (color.r == fmax )     hsl.x = deltaB - deltaG; // Hue
            else if (color.g == fmax) hsl.x = 1.0/3.0 + deltaR - deltaB; // Hue
            else if (color.b == fmax) hsl.x = 2.0/3.0 + deltaG - deltaR; // Hue
            
            if (hsl.x < 0.0)       hsl.x += 1.0; // Hue
            else if (hsl.x > 1.0)  hsl.x -= 1.0; // Hue
        }
        
        return hsl;
    }
    
    inline float hue_2_rgb(float f1, float f2, float hue)
    {
        if (hue < 0.0)      hue += 1.0;
        else if (hue > 1.0) hue -= 1.0;
        
        float res;
        
        if ((6.0 * hue) < 1.0)      res = f1 + (f2 - f1) * 6.0 * hue;
        else if ((2.0 * hue) < 1.0) res = f2;
        else if ((3.0 * hue) < 2.0) res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
        else                        res = f1;
        
        res = clamp(res, 0.0, 1.0);
        
        return res;
    }
    
    inline float3 HSL_2_rgb(float3 hsl)
    {
        float3 rgb;
        
        if (hsl.y == 0.0) rgb = clamp(float3(hsl.z), float3(0.0), float3(1.0)); // Luminance
        else
        {
            float f2;
            
            if (hsl.z < 0.5) f2 = hsl.z * (1.0 + hsl.y);
            else             f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
            
            float f1 = 2.0 * hsl.z - f2;
            
            constexpr float tk = 1.0/3.0;
            
            rgb.r = hue_2_rgb(f1, f2, hsl.x + tk);
            rgb.g = hue_2_rgb(f1, f2, hsl.x);
            rgb.b = hue_2_rgb(f1, f2, hsl.x - tk);
        }
        
        return rgb;
    }
    
    
    //
    // http://www.easyrgb.com/index.php?X=MATH&H=02#text2
    //
    inline float3 rgb_2_XYZ(float3 rgb)
    {
        return IMPrgb_2_XYZ(rgb);
    }
    
    inline float3 Lab_2_XYZ(float3 lab){
        
        float3 xyz;
        
        xyz.y = ( lab.x + 16.0 ) / 116.0;
        xyz.x = lab.y / 500.0 + xyz.y;
        xyz.z = xyz.y - lab.z / 200.0;
        
        if ( pow(xyz.y,3.0) > 0.008856 ) xyz.y = pow(xyz.y,3.0);
        else                             xyz.y = ( xyz.y - 16.0 / 116.0 ) / 7.787;
        
        if ( pow(xyz.x,3.0) > 0.008856 ) xyz.x = pow(xyz.x,3.0);
        else                             xyz.x = ( xyz.x - 16.0 / 116.0 ) / 7.787;
        
        if ( pow(xyz.z,3.0) > 0.008856 ) xyz.z = pow(xyz.z,3.0);
        else                             xyz.z = ( xyz.z - 16.0 / 116.0 ) / 7.787;
        
        xyz.x *= kIMP_Cielab_X;    //     Observer= 2°, Illuminant= D65
        xyz.y *= kIMP_Cielab_Y;
        xyz.z *= kIMP_Cielab_Z;
        
        return xyz;
    }
    
    inline float3 XYZ_2_rgb (float3 xyz){
        return IMPXYZ_2_rgb(xyz);
    }
    
    inline float3 XYZ_2_Lab(float3 xyz)
    {
        float var_X = xyz.x / kIMP_Cielab_X;   //   Observer= 2°, Illuminant= D65
        float var_Y = xyz.y / kIMP_Cielab_Y;
        float var_Z = xyz.z / kIMP_Cielab_Z;
        
        float t1 = 1.0/3.0;
        float t2 = 16.0/116.0;
        
        if ( var_X > 0.008856 ) var_X = pow (var_X, t1);
        else                    var_X = ( 7.787 * var_X ) + t2;
        
        if ( var_Y > 0.008856 ) var_Y = pow(var_Y, t1);
        else                    var_Y = ( 7.787 * var_Y ) + t2;
        
        if ( var_Z > 0.008856 ) var_Z = pow(var_Z, t1);
        else                    var_Z = ( 7.787 * var_Z ) + t2;
        
        return float3(( 116.0 * var_Y ) - 16.0, 500.0 * ( var_X - var_Y ), 200.0 * ( var_Y - var_Z ));
    }
    
    inline float3 Lab_2_rgb(float3 lab) {
        float3 xyz = Lab_2_XYZ(lab);
        return XYZ_2_rgb(xyz);
    }
    
    inline float3 rgb_2_Lab(float3 rgb) {
        float3 xyz = rgb_2_XYZ(rgb);
        return XYZ_2_Lab(xyz);
    }
    
    inline float3 rgb_2_YCbCr(float3 rgb){
        float3x3 tv = float3x3(
                               float3( 0.299,  0.587,  0.114),
                               float3(-0.169, -0.331,  0.5),
                               float3( 0.5,   -0.419, -0.081)
                               );
        constexpr float3 offset (0,128,128);
        
        return (tv * rgb*255 + offset)/255;
    }
    
    inline float3 YCbCr_2_rgb(float3 YCbCr){
        float3x3 ti = float3x3(
                               float3(1.0,  0.0,    1.4),
                               float3(1.0, -0.343, -0.711),
                               float3(1.0,  1.765,  0.0)
                               );
        constexpr float3 offset (0,128,128);
        
        return (ti * float3(YCbCr*255 - offset))/255;
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
