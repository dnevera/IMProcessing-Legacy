//
//  IMPCamera_main.metal
//  IMPCameraManager
//
//  Created by denis svinarchuk on 18.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "IMProcessing_metal.h"

kernel void kernel_EV(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                      metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                      constant float    &value [[buffer(0)]],
                      metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    outTexture.write(inColor * pow(2 , value), gid);
}


kernel void kernel_Red(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                      metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                      constant float    &value [[buffer(0)]],
                      metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
    inColor.rgb.r = 0;
    outTexture.write(inColor, gid);
}
