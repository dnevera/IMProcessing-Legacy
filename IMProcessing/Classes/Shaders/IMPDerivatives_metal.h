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

constexpr sampler cornerSampler(address::clamp_to_edge, filter::linear, coord::normalized);

class LineColors {
    
public:
    
    float3 left;
    float3 center;
    float3 right;
    
    METAL_FUNC LineColors() {}
    
    METAL_FUNC LineColors(texture2d<float, access::sample> texture,
                          const float2 texCoord,
                          float y,
                          float radius
                          ) {
        
        float x = radius/float(texture.get_width());
        
        left   = texture.sample(cornerSampler, texCoord + float2(-x,y)).rgb;
        center = texture.sample(cornerSampler, texCoord + float2( 0,y)).rgb;
        right  = texture.sample(cornerSampler, texCoord + float2( x,y)).rgb;
    }
    
    float leftLuma(){
        //return left.r;
        return IMProcessing::lum(left);
    }
    float centerLuma(){
        //return center.r;
        return IMProcessing::lum(center);
    }
    float rightLuma(){
        //return right.r;
        return IMProcessing::lum(right);
    }
    
};

class CornerColors {
public:
    LineColors top;
    LineColors mid;
    LineColors bottom;
    
    METAL_FUNC CornerColors(texture2d<float, access::sample> texture, const float2 texCoord, float radius){
        float y = radius/float(texture.get_height());
        top    = LineColors(texture,texCoord,-y,radius);
        mid    = LineColors(texture,texCoord, 0,radius);
        bottom = LineColors(texture,texCoord, y,radius);
    };
};

fragment float4 fragment_xyDerivative(
                                      IMPVertexOut in [[stage_in]],
                                      texture2d<float, access::sample> texture [[ texture(0) ]],
                                      const device float &radius [[ buffer(0) ]]
                                      ) {
    
    CornerColors corner(texture,in.texcoord.xy,radius);

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
                                               const device float               &radius     [[ buffer(0) ]],
                                               const device float               &threshold [[ buffer(1) ]]
                                               ) {
    
    CornerColors corner(texture,in.texcoord.xy, radius);
    
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



fragment float4 fragment_harrisCorner(
                                      IMPVertexOut in [[stage_in]],
                                      texture2d<float, access::sample> texture [[ texture(0) ]],
                                      const device float &sensitivity [[ buffer(0)  ]]
                                      ) {
    constexpr float k = 0.04;
    
    // (Ix^2,Iy^2)
    float3 I2 = texture.sample(cornerSampler, in.texcoord.xy).rgb;
    
    float I2S = I2.x + I2.y;
    
    float Ixy2 = (I2.z * 2.0) - 1.0;
    
    // R = Ix^2 * Iy^2 - Ixy * Ixy - k * (Ix^2 + Iy^2)^2
    float cornerness = I2.x * I2.y - Ixy2 * Ixy2 - k * I2S * I2S;
    
    return float4(float3(cornerness * sensitivity), 1.0);
}



#endif // __cplusplus
#endif //__METAL_VERSION__
#endif /*IMPDerivative_metal_h*/