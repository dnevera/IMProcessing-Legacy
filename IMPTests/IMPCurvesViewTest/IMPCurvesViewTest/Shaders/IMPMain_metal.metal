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

inline float4 adjustRGBCurve(
                          float4 inColor,
                          texture1d_array<float, access::sample> curveTexure,
                          constant IMPAdjustment &adjustment
                          )
{
    
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    half red   = curveTexure.sample(s, inColor.r, 0).x;
    half green = curveTexure.sample(s, inColor.g, 1).x;
    half blue  = curveTexure.sample(s, inColor.b, 2).x;
    
    float4 result = float4(red, green, blue, adjustment.blending.opacity);
    
    if (adjustment.blending.mode == 0)
        result = IMProcessing::blendLuminosity(inColor, result);
    else // only two modes yet
        result = IMProcessing::blendNormal(inColor, result);
    
    
    return result;
}

kernel void kernel_adjustRGBWCurve(texture2d<float, access::sample>        inTexture   [[texture(0)]],
                               texture2d<float, access::write>         outTexture  [[texture(1)]],
                               texture1d_array<float, access::sample>  curveTexure [[texture(2)]],
                               constant IMPAdjustment                  &adjustment [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    outTexture.write(adjustRGBCurve(inColor,curveTexure,adjustment),gid);
}
