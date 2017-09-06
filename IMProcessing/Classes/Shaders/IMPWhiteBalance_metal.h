//
//  IMPWhiteBalance_metal.h
//  Pods
//
//  Created by denis svinarchuk on 06.09.17.
//
//

#ifndef IMPWhiteBalance_metal_h
#define IMPWhiteBalance_metal_h

#ifdef __METAL_VERSION__

#ifdef __cplusplus

#include <metal_stdlib>
#include <simd/simd.h>
#include "IMPSwift-Bridging-Metal.h"

static constant float3 warmFilter = (float3){0.93, 0.54, 0.0};

kernel void kernel_adjustWhiteBalance(texture2d<float, access::sample>        inTexture    [[texture(0)]],
                                      texture2d<float, access::write>         outTexture   [[texture(1)]],
                                      constant float             &temperature [[buffer(0)]],
                                      constant float             &tint        [[buffer(1)]],
                                      constant IMPAdjustment     &adjustment  [[buffer(2)]],
                                      uint2 gid [[thread_position_in_grid]])
{
    const float3x3 RGBtoYIQ = float3x3({0.299, 0.587, 0.114}, {0.596, -0.274, -0.322}, {0.212, -0.523, 0.311});
    const float3x3 YIQtoRGB = float3x3({1.0, 0.956, 0.621},   {1.0, -0.272, -0.647},   {1.0, -1.105, 1.702});
    
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    
    float3 yiq = RGBtoYIQ * inColor.rgb; //adjusting tint
    yiq.b = clamp(yiq.b + tint*0.5226*0.1, -0.5226, 0.5226);
    
    float3 rgb = YIQtoRGB * yiq;
    
    float3 processed = float3(
                              (rgb.r < 0.5 ? (2.0 * rgb.r * warmFilter.r) : (1.0 - 2.0 * (1.0 - rgb.r) * (1.0 - warmFilter.r))), //adjusting temperature
                              (rgb.g < 0.5 ? (2.0 * rgb.g * warmFilter.g) : (1.0 - 2.0 * (1.0 - rgb.g) * (1.0 - warmFilter.g))),
                              (rgb.b < 0.5 ? (2.0 * rgb.b * warmFilter.b) : (1.0 - 2.0 * (1.0 - rgb.b) * (1.0 - warmFilter.b))));
    
    float4 result = float4(mix(rgb, processed, temperature), adjustment.blending.opacity);
    
    if (adjustment.blending.mode == IMPLuminosity)
    result = IMProcessing::blendLuminosity(inColor, result);
    else // only two modes yet
    result = IMProcessing::blendNormal(inColor, result);
    
    outTexture.write(result,gid);
}


#endif
#endif
#endif /* IMPWhiteBalance_metal_h */
