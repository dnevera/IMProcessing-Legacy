//
//  IMPHuoghTransform_metal.metal
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 13/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPHuoghTransform_metal_h
#define IMPHuoghTransform_metal_h


#include <metal_stdlib>
using namespace metal;


#ifdef __METAL_VERSION__

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

typedef struct {
    atomic_uint channels[kIMP_HistogramMaxChannels][kIMP_HistogramSize];
}IMPHistogramAtomicBuffer;

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
                                        uint2 gid [[thread_position_in_grid]],
                                        uint tid [[thread_index_in_threadgroup]]
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
    
    outTexture.write(inColor,gid);
}




#endif // __cplusplus
#endif //__METAL_VERSION__
#endif /*IMPHuoghTransform_metal_h*/
