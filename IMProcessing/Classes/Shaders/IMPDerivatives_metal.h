//
//  IMPDerivative_metal.h
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPDerivative_metal_h
#define IMPDerivative_metal_h


#include <metal_stdlib>
using namespace metal;


#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

fragment float4 fragment_xyDerivative(
                                             IMPVertexOut in [[stage_in]],
                                             texture2d<float, access::sample> texture [[ texture(0) ]],
                                             const device IMPGradientCoords   &coords [[ buffer(0)  ]]
                                             ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    float2 texCoord = in.texcoord.xy;
    
    float c1  = texture.sample(s, texCoord + coords.point[0][0]).r; // tl
    float c2  = texture.sample(s, texCoord + coords.point[0][1]).r; // t
    float c3  = texture.sample(s, texCoord + coords.point[0][2]).r; // tr
    
    float c4  = texture.sample(s, texCoord + coords.point[1][0]).r; // l
    float c5  = texture.sample(s, texCoord + coords.point[1][2]).r; // r
    
    float c6  = texture.sample(s, texCoord + coords.point[2][0]).r; // bl
    float c7  = texture.sample(s, texCoord + coords.point[2][1]).r; // b
    float c8  = texture.sample(s, texCoord + coords.point[2][2]).r; // br
    
    float vd = -c1 - c2 - c3 + c6 + c7 + c8;
    float hd = -c6 - c4 - c1 + c8 + c5 + c3;

    float x = ((vd * hd) + 1.0) / 2.0;
    float y = vd * vd;
    float z = hd * hd;
    
    return float4(x,y,z,1);
}

fragment float4 fragment_nonMaximumSuppression(
                                               IMPVertexOut in [[stage_in]],
                                               texture2d<float, access::sample> texture    [[ texture(0)]],
                                               const device IMPGradientCoords   &coords    [[ buffer(0) ]],
                                               const device float               &threshold [[ buffer(1) ]]
                                               ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    float2 texCoord = in.texcoord.xy;
    
    float4 c0  = texture.sample(s, texCoord + coords.point[1][1]);   // c
 
    float c1  = texture.sample(s, texCoord + coords.point[0][0]).r; // tl
    float c2  = texture.sample(s, texCoord + coords.point[0][1]).r; // t
    float c3  = texture.sample(s, texCoord + coords.point[0][2]).r; // tr
    
    float c4  = texture.sample(s, texCoord + coords.point[1][0]).r; // l
    float c5  = texture.sample(s, texCoord + coords.point[1][2]).r; // r
    
    float c6  = texture.sample(s, texCoord + coords.point[2][0]).r; // bl
    float c7  = texture.sample(s, texCoord + coords.point[2][1]).r; // b
    float c8  = texture.sample(s, texCoord + coords.point[2][2]).r; // br
    
    float multiplier = 1.0 - step(c0.r, c2);
    multiplier = multiplier * (1.0 - step(c0.r, c1));
    multiplier = multiplier * (1.0 - step(c0.r, c4));
    multiplier = multiplier * (1.0 - step(c0.r, c6));
    
    float maxValue = max(c0.r,c7);
    maxValue = max(maxValue, c8);
    maxValue = max(maxValue, c5);
    maxValue = max(maxValue, c3);
    
    float finalValue = c0.r * step(maxValue, c0.r) * multiplier;
    finalValue = step(threshold, finalValue);
    
    return float4(finalValue, finalValue, finalValue, 1.0);
}



fragment float4 fragment_harrisCorner(
                                      IMPVertexOut in [[stage_in]],
                                      texture2d<float, access::sample> texture [[ texture(0) ]],
                                      const device float &sensitivity [[ buffer(0)  ]]
                                      ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    constexpr float harrisConstant = 0.04;
    
    float2 texCoord = in.texcoord.xy;
    
    float4 derivativeElements = texture.sample(s, texCoord);
    
    float derivativeSum = derivativeElements.x + derivativeElements.y;
    
    float zElement = (derivativeElements.z * 2.0) - 1.0;
    
    // R = Ix^2 * Iy^2 - Ixy * Ixy - k * (Ix^2 + Iy^2)^2
    float cornerness = derivativeElements.x * derivativeElements.y - (zElement * zElement) - harrisConstant * derivativeSum * derivativeSum;
    
    return float4(float3(cornerness * sensitivity), 1.0);
}



#endif // __cplusplus
#endif //__METAL_VERSION__
#endif /*IMPDerivative_metal_h*/
