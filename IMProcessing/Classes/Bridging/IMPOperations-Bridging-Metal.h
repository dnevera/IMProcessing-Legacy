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

//
// LUV
//
static inline float3 IMPxyz_2_luv(float3 xyz)
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

static inline float3 IMPluv_2_xyz(float3 lutspace)
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

//
// HSV
//
static inline float3 IMPrgb_2_HSV(float3 c)
{
    constexpr float4 K = (float4){0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0};
    float  s = vector_step(c.z, c.y);
    float4 p = vector_mix((float4){c.z, c.y, K.w, K.z}, (float4){c.y, c.z, K.x, K.y}, (float4){s,s,s,s});
    s = vector_step(p.x, c.x);
    float4 q = vector_mix((float4){p.x,p.y,p.w, c.x}, (float4){c.x, p.y,p.z,p.x}, (float4){s,s,s,s});
    float d = q.x - fmin(q.w, q.y);
    constexpr float e = 1.0e-10;
    return (vector_float3){(float)fabs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x};
}


static inline float3 IMPHSV_2_rgb(float3 c)
{
    constexpr float4 K = (float4){1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0};
    float3 p0 = (float3){c.x,c.x,c.x} + (float3){K.x,K.y,K.z} ;// * (float3){6.0,6.0,6.0};
    float3 p1 = vector_fract(p0);
    float3 p2 = p1 * (float3){6.0, 6.0, 6.0} - (float3){K.w,K.w,K.w};
    float3 p = fabs(p2);
    return c.z * vector_mix(K.xxx, vector_clamp(p - K.xxx, 0.0, 1.0), c.y);
}


//
// XYZ
//
static inline float3 IMPrgb_2_XYZ(float3 rgb)
{
    float r = rgb.x;
    float g = rgb.y;
    float b = rgb.z;
    
    
    if ( r > 0.04045 ) r = pow((( r + 0.055) / 1.055 ), 2.4);
    else               r = r / 12.92;
    
    if ( g > 0.04045 ) g = pow((( g + 0.055) / 1.055 ), 2.4);
    else               g = g / 12.92;;
    
    if ( b > 0.04045 ) b = pow((( b + 0.055) / 1.055 ), 2.4);
    else               b = b / 12.92;
    
    float3 xyz;
    
    xyz.x = r * 41.24 + g * 35.76 + b * 18.05;
    xyz.y = r * 21.26 + g * 71.52 + b * 7.22;
    xyz.z = r * 1.93  + g * 11.92 + b * 95.05;
    
    return xyz;
}

static inline float3 IMPXYZ_2_rgb (float3 xyz){
    
    float var_X = xyz.x / 100.0;       //X from 0 to  95.047      (Observer = 2°, Illuminant = D65)
    float var_Y = xyz.y / 100.0;       //Y from 0 to 100.000
    float var_Z = xyz.z / 100.0;       //Z from 0 to 108.883
    
    float3 rgb;
    
    rgb.x = var_X *  3.2406 + var_Y * -1.5372 + var_Z * -0.4986;
    rgb.y = var_X * -0.9689 + var_Y *  1.8758 + var_Z *  0.0415;
    rgb.z = var_X *  0.0557 + var_Y * -0.2040 + var_Z *  1.0570;
    
    if ( rgb.x > 0.0031308 ) rgb.x = 1.055 * pow( rgb.x, ( 1.0 / 2.4 ) ) - 0.055;
    else                     rgb.x = 12.92 * rgb.x;
    
    if ( rgb.y > 0.0031308 ) rgb.y = 1.055 * pow( rgb.y, ( 1.0 / 2.4 ) ) - 0.055;
    else                     rgb.y = 12.92 * rgb.y;
    
    if ( rgb.z > 0.0031308 ) rgb.z = 1.055 * pow( rgb.z, ( 1.0 / 2.4 ) ) - 0.055;
    else                     rgb.z = 12.92 * rgb.z;
    
    return rgb;
}


//
// LAB
//

static inline float3 IMPLab_2_XYZ(float3 lab){
    
    float3 xyz;
    
    xyz.y = ( lab.x + 16.0 ) / 116.0;
    xyz.x = lab.y / 500.0 + xyz.y;
    xyz.z = xyz.y - lab.z / 200.0;
    
    if ( pow(xyz.y,3.0) > 0.008856 ) xyz.y = pow(xyz.y,3.0);
    else                             xyz.y = ( xyz.y - 16.0 / 116.0 ) / 7.787;
    
    if ( pow(xyz.x,3.0) > 0.008856 ) xyz.x = pow(xyz.x,3.0);
    else                             xyz.x = ( xyz.x - 16.0 / 116.0 ) / 7.787;
    
    if ( pow(xyz.z,3.0) > 0.008856 ) xyz.z = pow(xyz.z,3.0);
    else                             xyz.z = ( xyz.z - 16.0 / 116.0 ) / 7.787;
    
    xyz.x *= kIMP_Cielab_X;    //     Observer= 2°, Illuminant= D65
    xyz.y *= kIMP_Cielab_Y;
    xyz.z *= kIMP_Cielab_Z;
    
    return xyz;
}

static inline float3 IMPXYZ_2_Lab(float3 xyz)
{
    float var_X = xyz.x / kIMP_Cielab_X;   //   Observer= 2°, Illuminant= D65
    float var_Y = xyz.y / kIMP_Cielab_Y;
    float var_Z = xyz.z / kIMP_Cielab_Z;
    
    float t1 = 1.0/3.0;
    float t2 = 16.0/116.0;
    
    if ( var_X > 0.008856 ) var_X = pow (var_X, t1);
    else                    var_X = ( 7.787 * var_X ) + t2;
    
    if ( var_Y > 0.008856 ) var_Y = pow(var_Y, t1);
    else                    var_Y = ( 7.787 * var_Y ) + t2;
    
    if ( var_Z > 0.008856 ) var_Z = pow(var_Z, t1);
    else                    var_Z = ( 7.787 * var_Z ) + t2;
    
    return (float3){( 116.0 * var_Y ) - 16.0, 500.0 * ( var_X - var_Y ), 200.0 * ( var_Y - var_Z )};
}

#endif /* IMPOperations_Bridgin_Metal_h */
