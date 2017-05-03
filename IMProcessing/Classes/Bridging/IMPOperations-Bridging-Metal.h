//
//  IMPOperations-Bridging-Metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 23.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#ifndef IMPOperations_Bridgin_Metal_h
#define IMPOperations_Bridgin_Metal_h

#include "IMPConstants-Bridging-Metal.h"

//
// luv sources: https://www.ludd.ltu.se/~torger/dcamprof.html
//
static inline float lab_ft_forward(float t)
{
    if (t >= 8.85645167903563082e-3) {
        return pow(t, 1.0/3.0);
    } else {
        return t * (841.0/108.0) + 4.0/29.0;
    }
}

static inline float lab_ft_inverse(float t)
{
    if (t >= 0.206896551724137931) {
        return t*t*t;
    } else {
        return 108.0 / 841.0 * (t - 4.0/29.0);
    }
}

static inline float3 xyz_2_luv(float3 xyz)
{
    float x = xyz[0], y = xyz[1], z = xyz[2];
    // u' v' and L*
    float up = 4*x / (x + 15*y + 3*z);
    float vp = 9*y / (x + 15*y + 3*z);
    float L = 116*lab_ft_forward(y) - 16;
    if (!isfinite(up)) up = 0;
    if (!isfinite(vp)) vp = 0;
    
    return (float3){ L*0.01, up, vp };
}

static inline float3 luv_2_xyz(float3 lutspace)
{
    float L = lutspace[0]*100.0, up = lutspace[1], vp = lutspace[2];
    float y = (L + 16)/116;
    y = lab_ft_inverse(y);
    float x = y*9*up / (4*vp);
    float z = y * (12 - 3*up - 20*vp) / (4*vp);
    if (!isfinite(x)) x = 0;
    if (!isfinite(z)) z = 0;
    
    return (float3){ x, y, z };
}

//inline float3 rgb_2_HSV(float3 c)
//{
//    constexpr float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
//    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
//    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
//    
//    float d = q.x - min(q.w, q.y);
//    constexpr float e = 1.0e-10;
//    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
//}
//
//inline float3 HSV_2_rgb(float3 c)
//{
//    constexpr float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
//    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
//    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
//}
//

#endif /* IMPOperations_Bridgin_Metal_h */
