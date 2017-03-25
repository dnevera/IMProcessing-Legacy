//
//  IMPSegmentsDetector_metal.h
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 26.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPSegmentsDetector_metal_h
#define IMPSegmentsDetector_metal_h

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


kernel void kernel_segmentsDetector(
                                        texture2d<float, access::sample> derivative  [[texture(0)]],
                                        texture2d<float, access::write>  destination [[texture(1)]],
                                        //constant uint                   &rasterSize  [[buffer(0)]],
                                        
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
    
    uint region = gridSize.x;

    for (uint y=0; y<gh; y+=1){
        
        uint ry = y + groupId.y * gh;
        if (ry > height) break;
        
        for (uint x=0; x<gw; x+=region){
        
            uint rx = x + groupId.x * gw;
            if (rx > width) break;
            
            uint2 gid(rx,ry);

            float3 slope = derivative.read(gid).rgb;

            if (length(slope)>0){
                if (slope.y>=1 && slope.y > slope.z){
                    destination.write(float4(slope,1),gid-uint2(region/2,0));
                    for (int i = -int(region); i < int(region); i++){
                        if (i<0){ i=0 ;}
                        uint2 gid2(uint(int(rx)+i),ry);
                                                
                        destination.write(float4(slope,1),gid2-uint2(region/2,0));
                    }
                }
            }
        }
    }
    
    region = gridSize.y;

    for (uint x=0; x<gw; x+=1){

        uint rx = x + groupId.x * gw;
        if (rx > width) break;

        for (uint y=0; y<gh; y+=region){
            
            uint ry = y + groupId.y * gh;
            if (ry > height) break;
            
            uint2 gid(rx,ry);
            
            float3 slope = derivative.read(gid).rgb;
            
            if (length(slope)>0){
                if (slope.z>=1 && slope.z > slope.y){
                    destination.write(float4(slope,1),gid-uint2(0,region/2));
                    for (int i = -int(region); i < int(region); i++){
                        if (i<0){ i=0 ;}
                        
                        uint2 gid2(rx,uint(int(ry)+i));
                        
                        destination.write(float4(slope,1),gid2-uint2(0,region/2));
                    }
                }
            }
        }
    }

    
//    for (uint y=0; y<gh; y+=5){
//        float prev1 =0.0, prev2 = 0.0;
//        
//        uint ry = y + groupId.y * gh;
//        
//        if (ry > height) break;
//        
//        for (uint x=0; x<gw; x+=1){
//            
//            uint rx = x + groupId.x * gw;
//            
//            if (rx > width) break;
//            
//            uint2 gid(rx,ry);
//            
//            float3 current = derivative.read(gid).rgb;
//            
//            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
//                if (length(slope)>0){
//                    if (slope.y>=1 || slope.z>=1)
//                    destination.write(float4(slope,1),gid-uint2(5));
//                }
//            }
//            prev2 = prev1;
//            prev1 = current.r;
//        }
//    }
//    
//
//    for (uint x=0; x<gw; x+=rasterSize){
//        float prev1 =0.0, prev2 = 0.0;
//        
//        uint rx = x + groupId.x * gw;
//        
//        if (rx > width) break;
//        
//        for (uint y=0; y<gh; y+=1){
//            
//            uint ry = y + groupId.y * gh;
//            
//            if (ry > width) break;
//            
//            uint2 gid(rx,ry);
//            
//            float3 current = derivative.read(gid).rgb;
//            
//            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
//                float3 slope = sobelEdgeGradientIntensity(derivative, rx, ry);
//                if (length(slope)>0){
//                    if (slope.y>1 || slope.z>=1)
//                    destination.write(float4(slope,1),gid-uint2(rasterSize));
//                }
//            }
//            prev2 = prev1;
//            prev1 = current.r;
//        }
//    }
}


#endif // __cplusplus
#endif // __METAL_VERSION__
#endif // IMPSegmentsDetector_metal_h


