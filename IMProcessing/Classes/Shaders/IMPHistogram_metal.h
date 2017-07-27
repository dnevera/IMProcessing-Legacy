//
//  IMPHistogram_metal.h
//  Pods
//
//  Created by denis svinarchuk on 27.07.17.
//
//

#ifndef IMPHistogram_metal_h
#define IMPHistogram_metal_h

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
    
    static constant float3 Im(kIMP_HistogramSize - 1);
    
    
    ///  @brief Test is there pixel inside in a box or not
    ///
    ///  @param v          pixel coordinate
    ///  @param bottomLeft offset from bottom-left conner
    ///  @param topRight   offset from top-right conner
    ///
    ///  @return 0 or 1
    ///
    //inline  float coordsIsInsideBox(float2 v, float2 bottomLeft, float2 topRight) {
    //    float2 s =  step(bottomLeft, v) - step(topRight, v);
    //    return s.x * s.y;
   // }
    
    inline float4 histogramSampledColor(
                                        texture2d<float, access::sample>  inTexture,
                                        constant IMPRegion               &regionIn,
                                        uint2 gid){
        
        float w = float(inTexture.get_width());
        float h = float(inTexture.get_height());
        
        float2 coords  = float2(gid) * float2(1.0/w,1.0/h);
        //
        // для всех пикселей за пределами расчета возвращаем чорную точку с прозрачным альфа-каналом
        //
        float  isBoxed = coordsIsInsideBox(coords, float2(regionIn.left,regionIn.bottom), float2(1.0-regionIn.right,1.0-regionIn.top));
        return IMProcessing::sampledColor(inTexture,1,gid) * isBoxed;
    }
    
    
    ///  @brief Compute bin index of a color in input texture.
    ///
    ///  @param inTexture       input texture
    ///  @param regionIn        idents region which explore for the histogram calculation
    ///  @param scale           scale factor
    ///  @param gid             position thread in grrid, equal x,y coordiant position of pixel in texure
    ///
    ///  @return bin index
    ///
    inline uint4 channel_binIndex(
                                  texture2d<float, access::sample>  inTexture,
                                  constant IMPRegion               &regionIn,
                                  uint2 gid
                                  ){
        
        float4 inColor = histogramSampledColor(inTexture,regionIn,gid);
        uint   Y       = uint(dot(inColor.rgb, kIMP_Y_YCbCr_factor) * inColor.a * Im.x);
        
        return uint4(uint3(inColor.rgb * Im), Y);
    }
    
    //
    // https://devblogs.nvidia.com/parallelforall/gpu-pro-tip-fast-histograms-using-shared-atomics-maxwell/
    //
    
    kernel void kernel_accumHistogram(
                                      texture2d<float, access::sample> inTexture    [[texture(0)]],
                                      texture2d<float, access::write>  destination  [[texture(1)]],
                                      device   IMPHistogramBuffer      *in          [[ buffer(0)]],
                                      device   IMPHistogramBuffer      &out         [[ buffer(1)]],
                                      constant uint                    &numParts    [[ buffer(2)]],
                                      constant uint                    &channels    [[ buffer(3)]],
                                      
                                      uint2 blockIdx  [[threadgroup_position_in_grid]],
                                      uint2 threadIdx [[thread_position_in_threadgroup]]
                                      )
    {
        
        if (blockIdx.x>=channels) return;
        
        uint total = 0;
        
        for (uint j = 0; j < numParts; j++)
        total += in[j].channels[blockIdx.x][threadIdx.x];
        
        out.channels[blockIdx.x][threadIdx.x] = total;
    }
    
    kernel void kernel_partialHistogram(
                                        texture2d<float, access::sample> inTexture    [[texture(0)]],
                                        texture2d<float, access::write>  destination  [[texture(1)]],
                                        device   IMPHistogramBuffer      *out         [[ buffer(0)]],
                                        constant IMPRegion               &regionIn    [[ buffer(1)]],
                                        constant uint                    &channels    [[ buffer(2)]],
                                        
                                        uint2 gridDim   [[threadgroups_per_grid]],
                                        uint2 blockDim  [[threads_per_threadgroup]],
                                        uint2 blockIdx  [[threadgroup_position_in_grid]],
                                        uint2 threadIdx [[thread_position_in_threadgroup]]
                                        )
    {
        // pixel coordinates
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        
        // grid dimensions
        int nx = blockDim.x * gridDim.x;
        int ny = blockDim.y * gridDim.y;
        
        // linear thread index within 2D block
        int t = threadIdx.x + threadIdx.y * blockDim.x;
        
        // total threads in 2D block
        int nt = blockDim.x * blockDim.y;
        
        // linear block index within 2D grid
        uint g = blockIdx.x + blockIdx.y * gridDim.x;
        
        threadgroup atomic_uint temp[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
        
        for (uint c=0; c<kIMP_HistogramMaxChannels && c < channels; c++){
            for (int i = t; i < kIMP_HistogramSize; i += nt)
            atomic_store_explicit(&(temp[c][i]),0,memory_order_relaxed);
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        uint width  = destination.get_width();
        uint height = destination.get_height();
        
        // process pixels
        // updates our block's partial histogram in shared memory
        for (uint col = x; col < width; col += nx){
            for (uint row = y; row < height; row += ny) {
                
                uint2 gid = uint2(col,row);
                uint4 rgby  = channel_binIndex(inTexture,regionIn,gid);
                
                for (uint c = 0; c < kIMP_HistogramMaxChannels && c < channels; c++) {
                    atomic_fetch_add_explicit(&(temp[c][rgby[c]]), 1, memory_order_relaxed);
                }
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        // write partial histogram into the global memory
        for (int i = t; i < kIMP_HistogramSize; i += nt) {
            for (uint c = 0; c < kIMP_HistogramMaxChannels && c < channels; c++) {
                out[g].channels[c][i] = atomic_load_explicit(&(temp[c][i]), memory_order_relaxed);
            }
        }
    }
 
    
}

#endif

#endif

#endif /* IMPHistogram_metal_h */
