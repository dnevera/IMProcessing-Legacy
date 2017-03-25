//
//  IMPSobelEdges_metal.h
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 25.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPSobelEdges_metal_h
#define IMPSobelEdges_metal_h

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

#define THRESHOLD 1
#define EDGELSONLINE 5


inline float3 sobelEdgeGradientIntensity(
                                    texture2d<float> source      [[texture(2)]],
                                    int x, int y
                                    )
{
    float gx =  source.read(uint2(x-1, y-1)).r;
    gx += 2 * source.read(uint2( x, y-1)).r;
    gx += source.read(uint2(x+1, y-1)).r;
    gx -= source.read(uint2(x-1, y+1)).r;
    gx -= 2 * source.read(uint2(x, y+1)).r;
    gx -= source.read(uint2(x+1, y+1)).r;
    
    float gy = source.read(uint2( x-1, y-1)).r;
    gy += 2 * source.read(uint2( x-1, y)).r;
    gy += source.read(uint2( x-1, y+1)).r;
    gy -= source.read(uint2( x+1, y-1)).r;
    gy -= 2 * source.read(uint2( x+1, y)).r;
    gy -= source.read(uint2( x+1, y+1)).r;
    
    float2 slope = float2(gx, gy);
    
    if (gx!=0 && gy!=0){
        slope = normalize(float2(gx, gy));
    }
    
    return float3(0, slope);
}

kernel void kernel_sobelEdges(
                          texture2d<float, access::sample> derivative  [[texture(0)]],
                          texture2d<float, access::write>  destination [[texture(1)]],
                          texture2d<float, access::sample> source      [[texture(2)]],
                          constant uint                   &rasterSize  [[buffer(0)]],
                                                    
                          uint2 groupId   [[threadgroup_position_in_grid]],
                          uint2 gridSize  [[threadgroups_per_grid]],
                          uint2 pid [[thread_position_in_grid]]
                          )
{
    uint width  = destination.get_width();
    uint height = destination.get_height();
    
    uint gw = (width+gridSize.x-1)/gridSize.x;
    uint gh = (height+gridSize.y-1)/gridSize.y;
    
    for (uint y=0; y<gh; y+=1){
        uint ry = y + groupId.y * gh;
        if (ry > height) break;
        for (uint x=0; x<gw; x+=1){
            uint rx = x + groupId.x * gw;
            if (rx > width) break;
            destination.write(float4(0), uint2(rx,ry));
        }
    }
    
    for (uint y=0; y<gh; y+=rasterSize){
        float prev1 =0.0, prev2 = 0.0;
        
        uint ry = y + groupId.y * gh;
        
        if (ry > height) break;
        
        for (uint x=0; x<gw; x+=1){
            
            uint rx = x + groupId.x * gw;
            
            if (rx > width) break;
            
            uint2 gid(rx,ry);
            
            float3 current = derivative.read(gid).rgb;
            
            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
                float3 slope = sobelEdgeGradientIntensity(derivative, rx, ry);
                if (length(slope)>0){
                    destination.write(float4(slope,1),gid-uint2(2));
                }
            }
            prev2 = prev1;
            prev1 = current.r;
        }
    }
    
    for (uint x=0; x<gw; x+=rasterSize){
        float prev1 =0.0, prev2 = 0.0;
        
        uint rx = x + groupId.x * gw;
        
        if (rx > width) break;
        
        for (uint y=0; y<gh; y+=1){
            
            uint ry = y + groupId.y * gh;
            
            if (ry > width) break;
            
            uint2 gid(rx,ry);
            
            float3 current = derivative.read(gid).rgb;
            
            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
                float3 slope = sobelEdgeGradientIntensity(derivative, rx, ry);
                if (length(slope)>0){
                    destination.write(float4(slope,1),gid-uint2(2));
                }
            }
            prev2 = prev1;
            prev1 = current.r;
        }
    }
}

#endif // __cplusplus
#endif // __METAL_VERSION__
#endif // IMPSobelEdges_metal_h

