//
//  IMPMain_metal.metal
//  ImageMetalling-09
//
//  Created by denis svinarchuk on 01.01.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

#include <metal_stdlib>
#include "IMPStdlib_metal.h"
using namespace metal;

kernel void kernel_adjustRGBCurve(texture2d<float, access::sample>        inTexture   [[texture(0)]],
                               texture2d<float, access::write>         outTexture  [[texture(1)]],
                               texture1d_array<float, access::sample>  curveTexure [[texture(2)]],
                               constant IMPAdjustment                  &adjustment [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    outTexture.write(IMProcessing::adjustCurve(inColor,curveTexure,adjustment),gid);
}
