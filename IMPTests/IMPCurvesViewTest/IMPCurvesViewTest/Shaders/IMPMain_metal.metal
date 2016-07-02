//
//  IMPMain_metal.metal
//  ImageMetalling-09
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
#include "IMPStdlib_metal.h"
using namespace metal;

inline float3 adjust_hsvCurve(float  hue,
                              float3 hsv,
                              texture1d_array<float, access::sample> hueCurvesTexure,
                              texture1d_array<float, access::sample> saturationCurvesTexure,
                              texture1d_array<float, access::sample> valueCurvesTexure,
                              texture1d_array<float, access::sample>  weights,
                              uint index)
{
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);

    float scale = IMProcessing::weightOf(hue, weights, index) * pow(hsv.y, 2);
    
    hsv.x = hsv.x + (hueCurvesTexure.sample(s, hsv.x, index).x        - hsv.x) * scale;
    //hsv.y = hsv.y + (saturationCurvesTexure.sample(s, hsv.y, index).x - hsv.y) * scale;
    hsv.y = saturationCurvesTexure.sample(s, hsv.y, index).x;
    hsv.z = hsv.z + (valueCurvesTexure.sample(s, hsv.z, index).x      - hsv.z) * scale;
    
    return hsv;
}



inline float4 adjustHSVCurves(float4 input_color,
                              texture1d_array<float, access::sample> hueWeights,
                              texture1d_array<float, access::sample> hueCurvesTexure,
                              texture1d_array<float, access::sample> saturationCurvesTexure,
                              texture1d_array<float, access::sample> valueCurvesTexure,
                              constant IMPAdjustment                 &adjust
                              ){
    
    float3 hsv = IMProcessing::rgb_2_HSV(input_color.rgb);
    
    float  hue = hsv.x;
    
    for (uint i = 0; i<kIMP_Color_Ramps; i++){
        hsv = adjust_hsvCurve(hue,
                              hsv,
                              hueCurvesTexure,
                              saturationCurvesTexure,
                              valueCurvesTexure,
                              hueWeights,
                              i);
    }

    //
    // Master
    //
    hsv = adjust_hsvCurve(hue,
                          hsv,
                          hueCurvesTexure,
                          saturationCurvesTexure,
                          valueCurvesTexure,
                          hueWeights,
                          kIMP_Color_Ramps);

    float3 rgb(IMProcessing::HSV_2_rgb(hsv));
    
//    if (adjust.blending.mode == 0)
//        return IMProcessing::blendLuminosity(input_color, float4(rgb, adjust.blending.opacity));
//    else
        return IMProcessing::blendNormal(input_color, float4(rgb, adjust.blending.opacity));
}

///
///  @brief Kernel HSV Curves adjustment version
///
kernel void kernel_adjustHSVCurves(texture2d<float, access::sample>        inTexture   [[texture(0)]],
                                   texture2d<float, access::write>         outTexture  [[texture(1)]],
                                   texture1d_array<float, access::sample>  hueWeights  [[texture(2)]],
                                   texture1d_array<float, access::sample>  hueCurvesTexure[[texture(3)]],
                                   texture1d_array<float, access::sample>  saturationCurvesTexure[[texture(4)]],
                                   texture1d_array<float, access::sample>  valueCurvesTexure[[texture(5)]],
                                   constant IMPAdjustment                 &adjustment  [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]]){
    
    
    float4 input_color   = inTexture.read(gid);
    
    float4 result =  adjustHSVCurves(input_color,
                                     hueWeights,
                                     hueCurvesTexure,
                                     saturationCurvesTexure,
                                     valueCurvesTexure,
                                     adjustment);
    
    outTexture.write(result, gid);
}


inline float4 adjustRGBCurves(
                          float4 inColor,
                          texture1d_array<float, access::sample> curvesTexure,
                          constant IMPAdjustment &adjustment
                          )
{
    
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    half red   = curvesTexure.sample(s, inColor.r, 0).x;
    half green = curvesTexure.sample(s, inColor.g, 1).x;
    half blue  = curvesTexure.sample(s, inColor.b, 2).x;
    
    float4 result = float4(red, green, blue, adjustment.blending.opacity);
    
    if (adjustment.blending.mode == 0)
        result = IMProcessing::blendLuminosity(inColor, result);
    else // only two modes yet
        result = IMProcessing::blendNormal(inColor, result);
    
    
    return result;
}

kernel void kernel_adjustRGBWCurves(texture2d<float, access::sample>        inTexture   [[texture(0)]],
                               texture2d<float, access::write>         outTexture  [[texture(1)]],
                               texture1d_array<float, access::sample>  curveTexure [[texture(2)]],
                               constant IMPAdjustment                  &adjustment [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    outTexture.write(adjustRGBCurves(inColor,curveTexure,adjustment),gid);
}
