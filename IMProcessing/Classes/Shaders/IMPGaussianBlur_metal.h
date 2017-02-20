//
//  IMPGaussianBlur_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 14.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#ifndef IMPGaussianBlur_metal_h
#define IMPGaussianBlur_metal_h

#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

namespace IMProcessing
{
    
    
    fragment float4 fragment_gaussianSampledBlur(
                                                 IMPVertexOut in [[stage_in]],
                                                 texture2d<float, access::sample> texture    [[ texture(0) ]],
                                                 texture1d<float, access::sample> weights    [[ texture(1) ]],
                                                 texture1d<float, access::sample> offsets    [[ texture(2) ]],
                                                 const device   float2           &texelSize  [[ buffer(0)  ]]
                                                 ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        float2 texCoord = in.texcoord.xy;

        float3 color  = texture.sample(s, texCoord).rgb * weights.read(uint(0)).x;
        
        for( uint i = 1; i < weights.get_width(); i++ ){
            
            float2 texCoordOffset =  texelSize * offsets.read(i).x;
            
            color += texture.sample(s, (texCoord + texCoordOffset)).rgb * weights.read(i).x;
            color += texture.sample(s, (texCoord - texCoordOffset)).rgb * weights.read(i).x;
            
        }
        
        return float4(color,1);
    }
}

#endif

#endif

#endif /* IMPGaussianBlur_metal_h */
