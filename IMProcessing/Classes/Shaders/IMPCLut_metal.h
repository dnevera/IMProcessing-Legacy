//
//  IMPCubeLut_metal.h
//  Pods
//
//  Created by denis svinarchuk on 26.08.17.
//
//

#ifndef IMPCubeLut_metal_h
#define IMPCubeLut_metal_h

#ifdef __METAL_VERSION__

#ifdef __cplusplus

#include <metal_stdlib>
#include <simd/simd.h>
#include "IMPSwift-Bridging-Metal.h"

///
/// @brief Kernel optimized 3D LUT
///
kernel void kernel_make3DLut(
                             texture3d<float, access::write>         d3DLut     [[texture(0)]],
                             uint3 gid [[thread_position_in_grid]]){
    
    float3 denom = float3(d3DLut.get_width()-1,d3DLut.get_height()-1,d3DLut.get_depth()-1);
    float4 input_color  = float4(float3(gid)/denom,1);
    d3DLut.write(input_color, gid);
}


kernel void kernel_make2DLut(
                             texture2d<float, access::write>         d2DLut     [[texture(0)]],
                             constant uint  &clevel [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]){
    
    float qsize = float(clevel*clevel);
    float denom = qsize-1;
    
    uint  bindex = (floor(float(gid.x) / denom) + float(clevel) * floor( float(gid.y)/qsize));
    float b = bindex/denom;
    
    float xindex = floor(float(gid.x) / qsize);
    float yindex = floor(float(gid.y) / qsize);
    float r = (float(gid.x)-xindex*(qsize))/(qsize-1);
    float g = (float(gid.y)-yindex*(qsize))/(qsize-1);
    
    d2DLut.write(float4(r,g,b,1),gid.xy);
}


///
/// @brief Kernel optimized 1D LUT
///
kernel void kernel_make1DLut(
                             texture1d<float, access::write>   d1DLut     [[texture(0)]],
                             uint gid [[thread_position_in_grid]]){
    
    float3 denom = float3(d1DLut.get_width()-1);
    float4 input_color  = float4(float3(gid)/denom,1);
    d1DLut.write(input_color, gid);
}



#endif
#endif
#endif /* IMPCubeLut_metal_h */
