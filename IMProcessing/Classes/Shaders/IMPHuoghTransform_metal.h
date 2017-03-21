//
//  IMPHuoghTransform_metal.metal
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 13/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPHuoghTransform_metal_h
#define IMPHuoghTransform_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"


#ifdef __cplusplus

kernel void kernel_houghTransformAtomic(
                                        texture2d<float, access::sample>   inTexture   [[texture(0)]],
                                        texture2d<float, access::write>    outTexture  [[texture(1)]],
                                        volatile device   atomic_uint      *accum      [[ buffer(0)]],
                                        constant uint                      &numrho     [[ buffer(1)]],
                                        constant uint                      &numangle   [[ buffer(2)]],
                                        constant float                     &rhoStep    [[ buffer(3)]],
                                        constant float                     &thetaStep  [[ buffer(4)]],
                                        constant float                     &minTheta   [[ buffer(5)]],
                                        constant IMPRegion                 &regionIn   [[ buffer(6)]],
                                        uint2 gid [[thread_position_in_grid]]
                                        )
{
    
    float4 inColor = IMProcessing::sampledColor(inTexture,regionIn,1,gid);
    
    if (inColor.a>0 && inColor.r > 0){
        
        float angle = minTheta;
        float irho  = 1/rhoStep;
        for (uint n=0; n<numangle; n++) {
            
            float r = round( float(gid.x) * cos(angle) * irho + float(gid.y) * sin(angle) * irho);
            r += (numrho - 1) / 2;
            angle += thetaStep;
            
            int index = int((n+1) * (numrho+2) + r+1);
            
            atomic_fetch_add_explicit(&accum[index], 1, memory_order_relaxed);
        }
    }
}


kernel void kernel_houghSpaceLocalMaximums(
                                           constant uint      *accum     [[ buffer(0)]],
                                           device uint2       *maximums  [[ buffer(1)]],
                                           device atomic_uint *count     [[ buffer(2)]],
                                           constant uint      &numrho    [[ buffer(3)]],
                                           constant uint      &numangle  [[ buffer(4)]],
                                           constant uint      &threshold [[ buffer(5)]],
                                           uint2 gid [[thread_position_in_grid]]
                                           )
{
    uint base = (gid.y+1) * (numrho+2) + gid.x + 1;
    uint bins = accum[base];
    
    if (bins == 0) { return; }
    
    if(bins > threshold &&
       bins > accum[base - 1] && bins >= accum[base + 1] &&
       bins > accum[base - numrho - 2] && bins >= accum[base + numrho + 2] ){
        
        uint index = atomic_fetch_add_explicit(count, 1, memory_order_relaxed);
        maximums[index] = uint2(base,bins);
    }
}


/**
 * Релизация kernel-функции MSL с оптимизацией по flow-control
 */
kernel void kernel_bitonicSortUInt2(
                                    device uint2      *array       [[buffer(0)]],
                                    const device uint &stage       [[buffer(1)]],
                                    const device uint &passOfStage [[buffer(2)]],
                                    const device uint &direction   [[buffer(3)]],
                                    uint tid [[thread_index_in_threadgroup]],
                                    uint gid [[threadgroup_position_in_grid]],
                                    uint threads [[threads_per_threadgroup]]
                                    )
{
    uint sortIncreasing = direction;
    
    uint pairDistance = 1 << (stage - passOfStage);
    uint blockWidth   = 2 * pairDistance;
    
    uint globalPosition = threads * gid;
    uint threadId = tid + globalPosition;
    uint leftId = (threadId % pairDistance) + (threadId / pairDistance) * blockWidth;
    
    uint rightId = leftId + pairDistance;
    
    float leftElement  = array[leftId].y;
    float rightElement = array[rightId].y;
    
    uint sameDirectionBlockWidth = 1 << stage;
    
    if((threadId/sameDirectionBlockWidth) % 2 == 1) sortIncreasing = 1 - sortIncreasing;
    
    float greater = mix(leftElement,rightElement,step(leftElement,rightElement));
    float lesser  = mix(leftElement,rightElement,step(rightElement,leftElement));
    
    //
    // Заменяет if/else, но потенциально быстрее в силу того, что не блокирует блок ветвлений.
    // Особенно это хорошо заметно для старых типов GPU (A7, к примеру).
    // Однако, в современных реализациях производительность обработки ветвлений в GPU приблизилась
    // к эквивалентам CPU. Но, в целом, на больших массивах, разница все еще остается заметной.
    //
    array[leftId]  = mix(lesser,greater,step(sortIncreasing,0.5));
    array[rightId] = mix(lesser,greater,step(0.5,float(sortIncreasing)));
    
}


#endif // __cplusplus
#endif //__METAL_VERSION__
#endif /*IMPHuoghTransform_metal_h*/
