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

///
/// @brief Kernel optimized 1D LUT
///
kernel void kernel_make1DLut(
                             texture1d<float, access::write>         d1DLut     [[texture(0)]],
                             uint gid [[thread_position_in_grid]]){
    
    float3 denom = float3(d1DLut.get_width()-1);
    float4 input_color  = float4(float3(gid)/denom,1);
    d1DLut.write(input_color, gid);
}



#endif
#endif
#endif /* IMPCubeLut_metal_h */
