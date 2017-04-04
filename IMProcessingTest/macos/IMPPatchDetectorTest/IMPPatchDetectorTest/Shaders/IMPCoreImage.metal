//
//  IMPCoreImage.metal
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 05.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#include <metal_stdlib>
#include "IMProcessing_metal.h"
using namespace metal;

inline float3 getAvrgColor(int startx, int endx, int starty, int endy, uint2 gid,
                           texture2d<float>  source,
                           texture2d<float,access::write>  destination
                           ){
    float3 color(0);
    float3 c(0);
    
    for(int i = startx; i<endx; i++ ){
        for(int j = starty; j<endy; j++ ){
            uint2 gid2 = uint2(int2(gid)+int2(i,j));
            float3 s = source.read(gid2).rgb;
            color += s;
            c+=float3(1);
        }
    }
    
    return color/c;
}

//inline void drawAvrgColor(int startx, int endx, int starty, int endy, uint2 gid, float3 color, texture2d<float,access::write>  destination){
//    
//    for(int i = startx; i<endx; i++ ){
//        for(int j = starty; j<endy; j++ ){
//            int2 gid2 = int2(gid)+int2(i,j);
//            destination.write(float4(color,1),uint2(gid2));
//        }
//    }
//}

kernel void kernel_patchScanner(
                                metal::texture2d<float, metal::access::sample> source [[texture(0)]],
                                metal::texture2d<float, metal::access::write>  destination [[texture(1)]],
                                metal::texture2d<float, metal::access::sample> source2 [[texture(2)]],
                                device    IMPCorner *corners  [[ buffer(0) ]],
                                constant  uint      &count    [[ buffer(1) ]],
                                constant  uint3     *pacthColors    [[ buffer(2) ]],
                                constant  uint2     &pacthDimension [[ buffer(3) ]],
                                uint2 tid [[thread_position_in_grid]]
                                )
{
    uint width  = destination.get_width();
    uint height = destination.get_height();
    float2 size = float2(width,height);
    
    IMPCorner corner = corners[tid.x];
    float2 point = corner.point;
    float4 slope = corner.slope;
    
    int regionSize = 64;
    int rs = -regionSize/2;
    int re =  regionSize/2+1;
    float2 shift = (float2(-slope.x,-slope.y) + float2(slope.z,slope.w)) / size;
    uint2 gid = uint2((float2(point.x,point.y) + 4 * shift) * size);
    
    float3 color  = getAvrgColor(rs * slope.x, re * slope.w,  rs * slope.y, re * slope.z,  gid , source2, destination);
    corners[tid.x].color = float4(color,1);
}

