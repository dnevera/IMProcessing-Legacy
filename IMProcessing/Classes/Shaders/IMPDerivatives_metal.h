//
//  IMPDerivative_metal.h
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPDerivative_metal_h
#define IMPDerivative_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

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
                                      const device float &radius [[ buffer(0) ]]
                                      ) {
    
    IMProcessing::CornerColors corner(texture,in.texcoord.xy,radius);
    
    float vd = - corner.top.leftLuma() - corner.top.centerLuma() - corner.top.rightLuma() \
    + corner.bottom.leftLuma() + corner.bottom.centerLuma() + corner.bottom.rightLuma();
    
    float hd = - corner.bottom.leftLuma() - corner.mid.leftLuma() - corner.top.leftLuma() \
    + corner.bottom.rightLuma() + corner.mid.rightLuma() + corner.top.rightLuma();
    
    //
    // corner
    //
    float x = hd * hd;                 // I2.x
    float y = vd * vd;                 // I2.y
    float z = ((vd * hd) + 1.0) / 2.0; // Ixy2
    
    return float4(x,y,z,1);
}

fragment float4 fragment_nonMaximumSuppression(
                                               IMPVertexOut in [[stage_in]],
                                               texture2d<float, access::sample> texture    [[ texture(0)]],
                                               const device float               &radius    [[ buffer(0) ]],
                                               const device float               &threshold [[ buffer(1) ]]
                                               ) {
    
    IMProcessing::CornerColors corner(texture,in.texcoord.xy, radius);
    
    // Use a tiebreaker for pixels to the left and immediately above this one
    
    float centerColor = corner.mid.centerLuma();
    
    float multiplier = 1.0 - step(centerColor, corner.top.centerLuma());
    multiplier = multiplier * (1.0 - step(centerColor, corner.top.leftLuma()));
    multiplier = multiplier * (1.0 - step(centerColor, corner.mid.leftLuma()));
    multiplier = multiplier * (1.0 - step(centerColor, corner.bottom.leftLuma()));
    
    float maxValue = max(centerColor, corner.bottom.centerLuma());
    maxValue = max(maxValue, corner.bottom.rightLuma());
    maxValue = max(maxValue, corner.mid.rightLuma());
    maxValue = max(maxValue, corner.top.rightLuma());
    
    float finalValue = centerColor * step(maxValue, centerColor) * multiplier;
    
    finalValue = step(threshold, finalValue);
    
    return float4(finalValue, finalValue, finalValue, 1.0);
    
}

fragment float4 fragment_directionalSobelEdge(
                                              IMPVertexOut in [[stage_in]],
                                              texture2d<float, access::sample> texture [[ texture(0) ]],
                                              const device float &radius [[ buffer(0) ]]
                                              ) {
    
    IMProcessing::CornerColors corner(texture,in.texcoord.xy,radius);
    
    float2 gradientDirection;
    gradientDirection.x = -corner.bottom.leftLuma() - 2.0 * corner.mid.leftLuma() \
    - corner.top.leftLuma() + corner.bottom.rightLuma() + 2.0 * corner.mid.rightLuma() + corner.top.rightLuma();
    
    gradientDirection.y = -corner.top.leftLuma() - 2.0 * corner.top.centerLuma() \
    - corner.top.rightLuma() + corner.bottom.leftLuma() + 2.0 * corner.bottom.centerLuma() + corner.bottom.rightLuma();
    
    float gradientMagnitude = length(gradientDirection);
    float2 normalizedDirection = normalize(gradientDirection);
    
    // Offset by 1-sin(pi/8) to set to 0 if near axis, 1 if away
    normalizedDirection = sign(normalizedDirection) * floor(abs(normalizedDirection) + 0.617316);
    
    // Place -1.0 - 1.0 within 0 - 1.0
    normalizedDirection = (normalizedDirection + 1.0) * 0.5;
    
    return float4(gradientMagnitude, normalizedDirection.x, normalizedDirection.y, 1.0);
}


fragment float4 fragment_harrisCorner(
                                      IMPVertexOut in [[stage_in]],
                                      texture2d<float, access::sample> texture [[ texture(0) ]],
                                      const device float &sensitivity [[ buffer(0)  ]]
                                      ) {
    constexpr float k = 0.04;
    
    // (Ix^2,Iy^2)
    float3 I2 = texture.sample(IMProcessing::cornerSampler, in.texcoord.xy).rgb;
    
    float I2S = I2.x + I2.y;
    
    float Ixy2 = (I2.z * 2.0) - 1.0;
    
    // R = Ix^2 * Iy^2 - Ixy * Ixy - k * (Ix^2 + Iy^2)^2
    float cornerness = I2.x * I2.y - Ixy2 * Ixy2 - k * I2S * I2S;
    
    return float4(float3(cornerness * sensitivity), 1.0);
}

fragment float4 fragment_directionalNonMaximumSuppression(
                                                          IMPVertexOut in [[stage_in]],
                                                          texture2d<float, access::sample> texture    [[ texture(0)]],
                                                          const device float               &radius    [[ buffer(0) ]],
                                                          const device float               &upperThreshold [[ buffer(1) ]],
                                                          const device float               &lowerThreshold [[ buffer(2) ]]
                                                          ) {
    
    float3 gradient = texture.sample(IMProcessing::cornerSampler, in.texcoord.xy).rgb;
    
    float2 texel(1/float(texture.get_width()), 1/float(texture.get_height()));
    
    float2 gradientDirection = ((gradient.gb * 2.0) - 1.0) * texel;
    
    float firstMagnitude  = texture.sample(IMProcessing::cornerSampler, in.texcoord.xy + gradientDirection).r;
    float secondMagnitude = texture.sample(IMProcessing::cornerSampler, in.texcoord.xy - gradientDirection).r;
    
    float multiplier = step(firstMagnitude, gradient.r);
    multiplier = multiplier * step(secondMagnitude, gradient.r);
    
    float thresholdCompliance = smoothstep(lowerThreshold, upperThreshold, gradient.r);
    multiplier = multiplier * thresholdCompliance;
    
    return float4(multiplier, multiplier, multiplier, 1.0);
    
}

fragment float4 fragment_weakPixelInclusion(
                                            IMPVertexOut in [[stage_in]],
                                            texture2d<float, access::sample> texture [[ texture(0) ]],
                                            const device float &radius [[ buffer(0) ]]
                                            ) {
    
    IMProcessing::CornerColors corner(texture,in.texcoord.xy,radius);
    
    float sum = corner.bottom.leftLuma() + corner.top.rightLuma() + corner.top.leftLuma() + \
    corner.bottom.rightLuma() + corner.mid.leftLuma() + corner.mid.rightLuma() + corner.bottom.centerLuma() +\
    corner.top.centerLuma() + corner.mid.centerLuma();
    
    float sumTest = step(1.5, sum);
    float pixelTest = step(0.01, corner.mid.centerLuma());
    
    return float4(float3(sumTest * pixelTest), 1.0);
}

inline float gaussianDerivativeComponent(
                                         texture2d<float, access::sample> source,
                                         float2 texCoord,
                                         float2 texelSize,
                                         const int offset,
                                         const int pitch ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    float3 rgb = source.sample(s, (texCoord + texelSize * float2( offset * pitch))).rgb;
    return IMProcessing::max_component(rgb);
}

inline float gaussianDerivative(
                                texture2d<float, access::sample> source,
                                texture2d<float, access::write> destination,
                                const uint2 gid,
                                float2 texelSize,
                                const int pitch ) {
    
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    
    float2 texCoord  = float2(gid) / float2(destination.get_width(),destination.get_height());
    
    float color;
    color  = -3 * gaussianDerivativeComponent(source, texCoord, texelSize, -2, pitch);
    color += -5 * gaussianDerivativeComponent(source, texCoord, texelSize, -1, pitch);
    color +=  5 * gaussianDerivativeComponent(source, texCoord, texelSize,  1, pitch);
    color +=  3 * gaussianDerivativeComponent(source, texCoord, texelSize,  2, pitch);
    
    return abs(color);
}

kernel void kernel_gaussianDerivativeEdge(
                                          texture2d<float, access::sample> source     [[texture(0)]],
                                          texture2d<float, access::write> destination [[texture(1)]],
                                          constant uint                   &pitch  [[buffer(0)]],
                                          
                                          uint2 pid [[thread_position_in_grid]]
                                          ){
    
    float2 texelSizeX = float2(1,0)/float2(destination.get_width(),1);
    float2 texelSizeY = float2(0,1)/float2(1,destination.get_height());
    //constexpr uint pitch = 5;
    
    float gx   = gaussianDerivative(source,destination,pid, texelSizeX, pitch);
    float gy   = gaussianDerivative(source,destination,pid, texelSizeY, pitch);
    
    float gx1 = gaussianDerivative(source,destination, uint2(pid.x-1,pid.y), texelSizeX, pitch);
    float gx2 = gaussianDerivative(source,destination, uint2(pid.x+1,pid.y), texelSizeX, pitch);
    
    float gy1 = gaussianDerivative(source,destination,uint2(pid.x,pid.y-1), texelSizeY, pitch);
    float gy2 = gaussianDerivative(source,destination,uint2(pid.x,pid.y+1), texelSizeY, pitch);
    
    
    float3 color = float3(0);
    
    if (gx > 1 && gx1 > 1 && gx2 > 1){
        color.rgb = float3(1);
    }
    
    if (gy > 1 && gy1 > 1 && gy2 > 1){
        color.rgb = float3(1);
    }
    
    destination.write(float4(color,1),pid - uint2(pitch-1));
}


#endif // __cplusplus
#endif //__METAL_VERSION__
#endif /*IMPDerivative_metal_h*/
