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



kernel void kernel_segmentsDetectorY(
                                     texture2d<float, access::sample> derivative       [[texture(0)]],
                                     texture2d<float, access::write>  destination [[texture(1)]],
                                     //texture2d<float, access::sample> source  [[texture(2)]],
                                     
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
            
            uint2 gid(rx,ry);

            float3 slope = derivative.read(gid).rgb;

            //destination.write(float4(slope,1), uint2(rx,ry));
            destination.write(float4(0), uint2(rx,ry));
        }
    }

    
    float3 prev_slope = float3(0);
    uint2  start = uint2(0);
    uint2  end = uint2(0);
    uint   sum_x = 0;
    uint   cout = 0 ;
    
    for (uint x=0; x<gw; x+=1){
        
        uint rx = x + groupId.x * gw;
        
        if (rx > width) break;
        
        for (uint y=0; x<gh; y+=1){
            
            uint ry = y + groupId.y * gh;
            if (ry > height) break;
            
            uint2 gid(rx,ry);
            
            float3 slope = derivative.read(gid).rgb;
            
            if (length(slope)>0){
                if (slope.z>=1 && slope.z > slope.y){
                    prev_slope = slope;
                    if (start.x == 0 && start.y == 0 ) {
                        start = gid;
                    }
                    end = gid;
                    
                    sum_x += end.x;
                    cout++;
                }
            }
        }
    }
    
    uint rx = sum_x/cout;
    
    for (uint y=start.y; y<end.y; y+=1){
        uint2 gid = uint2(rx,y);
        destination.write(float4(float3(1,0.6,1),1),gid);
    }
}


kernel void kernel_segmentsDetectorX(
                                     texture2d<float, access::sample> derivative  [[texture(0)]],
                                     texture2d<float, access::write>  destination [[texture(1)]],
                                     
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
            
            uint2 gid(rx,ry);

            float3 slope = derivative.read(gid).rgb;
            float4 color = float4(0);
            if (length(slope)>0){
                if (slope.z>=1 && slope.z > slope.y){
                    color.rgb = slope;
                }
            }
            destination.write(color, uint2(rx,ry));
        }
    }
    
    float3 prev_slope = float3(0);
    uint2  start = uint2(0);
    uint2  end = uint2(0);
    uint   sum_y = 0;
    uint   cout = 0 ;
    
    for (uint y=0; y<gh; y+=1){
        
        uint ry = y + groupId.y * gh;
        
        if (ry > height) break;
        
        for (uint x=0; x<gw; x+=1){
            
            uint rx = x + groupId.x * gw;
            if (rx > width) break;
            
            uint2 gid(rx,ry);
            
            float3 slope = derivative.read(gid).rgb;
            
            if (length(slope)>0){
                if (slope.y>=1 && slope.y > slope.z){
                    prev_slope = slope;
                    if (start.x == 0 && start.y == 0 ) {
                        start = gid;
                    }
                    end = gid;
                    
                    sum_y += end.y;
                    cout++;
                }
            }
        }
    }
    
    uint ry = sum_y/cout;
    //uint ry = groupId.y * gh + gh/2;
    
    for (uint x=start.x; x<end.x; x+=1){
        uint2 gid = uint2(x,ry);
        
        //float3 slope = derivative.read(gid).rgb;
        
        //float3 f = mix(float3(0,0.5,0),slope,float3(1));
        destination.write(float4(float3(0.2,1,0.2),1),gid);
    }
    
    
    
    
    //    uint region = gridSize.x;
    //    int redispatchSize = int(region * gridSize.y);
    //
    //
    //    for (uint y=0; y<gh; y+=2){
    //
    //        uint ry = y + groupId.y * gh;
    //        if (ry > height) break;
    //
    //        float start = -1;
    //        float end   = -1;
    //
    //        for (uint x=0; x<gw; x+=region){
    //
    //            uint rx = x + groupId.x * gw;
    //            if (rx > width) break;
    //
    //            uint2 gid(rx,ry);
    //
    //            float3 slope = derivative.read(gid).rgb;
    //
    //
    //            if (length(slope)>0){
    //                if (slope.y>=1 && slope.y > slope.z){
    //
    //                    for (int i = -redispatchSize; i < redispatchSize; i++){
    //
    //                        if (i<0){ i=0 ;}
    //
    //                        uint2 gid2(uint(int(rx)+i),ry);
    //
    //                        if (start < 0) {
    //                            start = gid2.x -3;
    //                            end = start+region;
    //                        }
    //                        else {
    //                            //end = gid2.x;
    //                        }
    //
    //                        float3 slope = derivative.read(gid2).rgb;
    //
    //                        if (slope.y>=1){
    //                            end = gid2.x;
    //                        }
    //
    //                        destination.write(float4(slope,1), gid2 - uint2(3,3));
    //
    //                        //end = gid2.x;
    //                    }
    //                }
    //            }
    //        }
    //
    //        if (start >= 0 /*&& end >= 0 && end > start*/) {
    //            for (uint yy=ry-4; yy<ry+4; yy+=1){
    //                for (uint x=end-1; x<end+1; x+=1){
    //                    destination.write(float4(0,1,0.4,1),uint2(x,yy-3));
    //                }
    //                for (uint x=start-1; x<start+1; x+=1){
    //                    destination.write(float4(1,0.3,0,1),uint2(x,yy-3));
    //                }
    //            }
    //        }
    //    }
    //
    //    region = gridSize.y;
    //    redispatchSize = int(region * gridSize.x);
    //
    //    for (uint x=0; x<gw; x+=1){
    //
    //        uint rx = x + groupId.x * gw;
    //        if (rx > width) break;
    //
    //        for (uint y=0; y<gh; y+=region){
    //
    //            uint ry = y + groupId.y * gh;
    //            if (ry > height) break;
    //
    //            uint2 gid(rx,ry);
    //
    //            float3 slope = derivative.read(gid).rgb;
    //
    //            if (length(slope)>0){
    //                if (slope.z>=1 && slope.z > slope.y){
    //
    //                    for (int i = -redispatchSize; i < redispatchSize; i++){
    //                        if (i<0){ i=0 ;}
    //
    //                        uint2 gid2(rx,uint(int(ry)+i));
    //                        
    //                        float3 slope = derivative.read(gid2).rgb;
    //
    //                        destination.write(float4(slope,1),gid2-uint2(3,3));
    //                    }
    //                }
    //            }
    //        }
    //    }
}


#endif // __cplusplus
#endif // __METAL_VERSION__
#endif // IMPSegmentsDetector_metal_h


