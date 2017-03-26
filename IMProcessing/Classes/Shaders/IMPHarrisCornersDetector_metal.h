//
//  IMPHarrisCorrnersDetector_metal.h
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 26.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPHarrisCornersDetector_metal_h
#define IMPHarrisCornersDetector_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"


#ifdef __cplusplus

//typedef struct {
//};

inline float2 edgeSlope(texture2d<float, access::sample> source, texture2d<float, access::write> destination, int x, int y ){
    float4 inColor = IMProcessing::sampledColor(source, destination, uint2(x,y));
    return  source.read(uint2(x, y)).rb;
}

inline float2 edgeSlope__(texture2d<float> source, int x, int y )
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
    
    return slope;
}


kernel void kernel_pointsRegionScanner(
                                       texture2d<float, access::sample> suppression      [[texture(0)]],
                                       texture2d<float, access::write>  destination      [[texture(1)]],
                                       texture2d<float, access::sample> source           [[texture(2)]],
                                       
                                       constant float2  *points     [[ buffer(0) ]],
                                       constant uint    &size       [[ buffer(1) ]],
                                       constant uint    &pointsMax  [[ buffer(2) ]],
                                       device   IMPCorner *corners [[ buffer(3) ]],
                                       
                                       uint  pointIndex  [[thread_position_in_grid]]
                                )
{
    uint width  = suppression.get_width();
    uint height = suppression.get_height();
    
    int  regionSize = 32;
    int2 point = int2(points[pointIndex] * float2(width,height));
    
    IMPCorner corner;
    corner.point = points[pointIndex];
    corner.slops = float4(0);

    //
    // scan left half
    //
    //
    float slope_summ = 0;
    float count = 0;
    
    for(int x = -regionSize/2; x<0; x++ ){
        for(int y = -regionSize/2; y<regionSize/2; y++ ){
            
            int2 gid = int2(point+int2(x,y));
            
            float2 slope = edgeSlope(source, destination, gid.x, gid.y);
            
            slope_summ += slope.x;
            count += 1;
            
            destination.write(float4(slope,0,1),uint2(gid));
        }
    }
    
    corner.slops.x = slope_summ;//count;
    
    slope_summ = 0;
    count = 0;
    
    //
    // scan right half
    //
    for(int x = 1; x<=regionSize/2; x++ ){
        for(int y = -regionSize/2; y<=regionSize/2; y++ ){
            
            int2 gid = int2(point+int2(x,y));
            
            float2 slope = edgeSlope(source, destination, gid.x, gid.y);
            
            slope_summ += slope.x;
            count += 1;
            
            destination.write(float4(slope,0,1),uint2(gid));
        }
    }
    
    corner.slops.w = slope_summ;//count;
    
    slope_summ = 0;
    count = 0;
    
    //
    // scan top half
    //
    for(int x = -regionSize/2; x<=regionSize/2; x++ ){
        for(int y = -regionSize/2; y<0; y++ ){
            
            int2 gid = int2(point+int2(x,y));
            
            float2 slope = edgeSlope(source, destination, gid.x, gid.y);
            
            slope_summ += slope.y;
            count += 1;
            
            destination.write(float4(slope,0,1),uint2(gid));
        }
    }
    
    corner.slops.y = slope_summ;//count;

    slope_summ = 0;
    count = 0;
    
    //
    // scan top half
    //
    for(int x = -regionSize/2; x<=regionSize/2; x++ ){
        for(int y = 1; y<=regionSize/2; y++ ){
            
            int2 gid = int2(point+int2(x,y));
            
            float2 slope = edgeSlope(source, destination, gid.x, gid.y);
            
            slope_summ += slope.y;
            count += 1;
            
            //destination.write(float4(slope,0,1),uint2(gid));
        }
    }
    
    corner.slops.z = slope_summ;//count;
    
    if (length(corner.slops)>0){
        corner.slops = normalize(corner.slops);
    }
    
    
    corners[pointIndex] = corner;
}

inline float2 getSlops(int startx, int endx, int starty, int endy, uint2 gid,
                       texture2d<float>  derivative,
                       texture2d<float, access::write>  destination ){
    
    float2 slops = float2(0);
    
    for(int i = startx; i<endx; i++ ){
        for(int j = starty; j<endy; j++ ){
            uint2 gid2 = uint2(int2(gid)+int2(i,j));
            float2 s = derivative.read(gid2).xy;
            //destination.write(float4(s,0,1),gid2);
            slops += s;
        }
    }
    
    //if (length(slops)>0){
    //    slops = normalize(slops);
    //}
    
    return slops.yx;
}

kernel void kernel_pointsScanner(
                                 texture2d<float, access::sample> suppression      [[texture(0)]],
                                 texture2d<float, access::write>  destination      [[texture(1)]],
                                 texture2d<float, access::sample>  derivative      [[texture(2)]],
                                 
                                  device   IMPCorner      *corners   [[ buffer(0) ]],
                                 volatile device   atomic_uint    *count     [[ buffer(1) ]],
                                 constant          uint           &pointsMax [[ buffer(2) ]],
                                 
                                 uint2 groupId   [[threadgroup_position_in_grid]],
                                 uint2 gridSize  [[threadgroups_per_grid]],
                                 uint2 pid [[thread_position_in_grid]]
                                 )
{
    uint width  = destination.get_width();
    uint height = destination.get_height();
    
    uint gw = (width+gridSize.x-1)/gridSize.x;
    uint gh = (height+gridSize.y-1)/gridSize.y;
    

    int regionSize = 24;
    int rs = -regionSize/2;
    int re = regionSize/2+1;
    
    for (uint y=0; y<gh; y+=1){
        
        uint ry = y + groupId.y * gh;
        if (ry > height) break;
        
        for (uint x=0; x<gw; x+=1){
            
            uint rx = x + groupId.x * gw;
            if (rx > width) break;
            
            uint2 gid(rx,ry);
            
            float3 color = suppression.read(gid).rgb;
            
            if (color.r > 0) {
                
                uint index = atomic_fetch_add_explicit(count, 1, memory_order_relaxed);
                if (index > pointsMax) {
                    return;
                }
                IMPCorner corner;
                corner.point = float2(gid)/float2(width,height);
                corner.slops = float4(0);
                
                corner.slops.x  = getSlops(rs, 0,  rs, re,  gid, derivative,destination).x;
                corner.slops.y  = getSlops(rs, re, rs, 0,   gid, derivative,destination).y;
                corner.slops.z  = getSlops(rs, re, 0,  re,  gid, derivative,destination).y;
                corner.slops.w  = getSlops(0,  re, rs, re,  gid, derivative,destination).x;
                //corner.slops.xw += getSlops(rs, 0,  0,  re, gid,derivative,destination).xy;
                
                //corner.slops.z = getSlops(rs,re,1,re,gid,derivative).y;
                //corner.slops.y = getSlops(rs,re,rs,0,gid,derivative).y;

                if (length(corner.slops)){
                    corner.slops = normalize(corner.slops);
                }
                
                //corner.slops.y = getSlops(rs,re,rs,0,gid,derivative).y;
                //corner.slops.z = getSlops(rs,re,0,re,gid,derivative).y;
                
                corners[index] = corner;
            }
        }
    }
}
#endif // __cplusplus
#endif //__METAL_VERSION__
#endif // IMPHarisCorrnersDetector_metal

