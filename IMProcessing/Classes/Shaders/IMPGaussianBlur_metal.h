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
    
    kernel void kernel_gaussianSampledBlur(
                                           texture2d<float, access::sample> source       [[ texture(0) ]],
                                           texture2d<float, access::write>  destination  [[ texture(1) ]],
                                           texture1d<float, access::read>   weights      [[ texture(2) ]],
                                           texture1d<float, access::read>   offsets      [[ texture(3) ]],
                                           const device   float2           &texelSize    [[ buffer(0)  ]],
                                           uint2 gid [[thread_position_in_grid]]
                                           ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);

        float2 texCoord = float2(gid)/float2(source.get_width(),source.get_height());
        
        float3 color  = source.sample(s, texCoord).rgb * weights.read(uint(0)).x;
        
        for( uint i = 1; i < weights.get_width(); i++ ){
            
            float2 texCoordOffset =  texelSize * offsets.read(i).x;
            
            color += source.sample(s, (texCoord + texCoordOffset)).rgb * weights.read(i).x;
            color += source.sample(s, (texCoord - texCoordOffset)).rgb * weights.read(i).x;
            
        }
        
        destination.write(float4(color,1), gid);
    }
    

    kernel void kernel_blendSource(texture2d<float, access::sample> source      [[texture(0)]],
                                   texture2d<float, access::write>  destination [[texture(1)]],
                                   texture2d<float, access::sample> background  [[texture(2)]],
                                   constant IMPAdjustment           &adjustment  [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]])
    {
        float4 inColor = IMProcessing::sampledColor(background,destination,gid);
        float3 rgb     = IMProcessing::sampledColor(source,destination,gid).rgb;
        
        if (adjustment.blending.mode == 0)
            inColor = IMProcessing::blendLuminosity(inColor, float4(rgb,adjustment.blending.opacity));
        else // only two modes yet
            inColor = IMProcessing::blendNormal(inColor, float4(rgb,adjustment.blending.opacity));
        
        destination.write(inColor, gid);
    }
    
    
    fragment float4 fragment_gaussianSampledBlur(
                                                 IMPVertexOut in [[stage_in]],
                                                 texture2d<float, access::sample> texture    [[ texture(0) ]],
                                                 texture1d<float, access::read>   weights    [[ texture(1) ]],
                                                 texture1d<float, access::read>   offsets    [[ texture(2) ]],
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
    
    fragment float4 fragment_blendSource(
                                         IMPVertexOut in [[stage_in]],
                                         texture2d<float, access::sample> texture [[ texture(0) ]],
                                         texture2d<float, access::sample> source [[ texture(1) ]],
                                         constant IMPAdjustment           &adjustment  [[buffer(0)]]
                                         
                                         ) {
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        float4 inColor = source.sample(s, in.texcoord.xy);
        float3 rgb = texture.sample(s, in.texcoord.xy).rgb;
        
        if (adjustment.blending.mode == 0)
            inColor = IMProcessing::blendLuminosity(inColor, float4(rgb,adjustment.blending.opacity));
        else // only two modes yet
            inColor = IMProcessing::blendNormal(inColor, float4(rgb,adjustment.blending.opacity));
        
        return  inColor;
    }

}

#endif

#endif

#endif /* IMPGaussianBlur_metal_h */
