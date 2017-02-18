//
//  IMPCoreImage.metal
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 05.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

static constant float3 kIMP_Y_YCbCr_factor = {0.299, 0.587, 0.114};

template<typename T> METAL_FUNC T lum(vec<T, 3> c) {
    return dot(c, kIMP_Y_YCbCr_factor);
}

inline float3 clipcolor(float3 c) {
    float l = lum(c);
    float n = min(min(c.r, c.g), c.b);
    float x = max(max(c.r, c.g), c.b);
    
    if (n < 0.0) {
        c.r = l + ((c.r - l) * l) / (l - n);
        c.g = l + ((c.g - l) * l) / (l - n);
        c.b = l + ((c.b - l) * l) / (l - n);
    }
    if (x > 1.0) {
        c.r = l + ((c.r - l) * (1.0 - l)) / (x - l);
        c.g = l + ((c.g - l) * (1.0 - l)) / (x - l);
        c.b = l + ((c.b - l) * (1.0 - l)) / (x - l);
    }
    
    return c;
}

inline float3 setlum(float3 c, float l) {
    float d = l - lum(c);
    c = c + float3(d);
    return clipcolor(c);
}


inline  float4 blendLuminosity(float4 baseColor, float4 overlayColor)
{
    return float4(baseColor.rgb * (1.0 - overlayColor.a) + setlum(baseColor.rgb, lum(overlayColor.rgb)) * overlayColor.a, baseColor.a);
}


inline float when_eq(float x, float y) {
    return 1.0 - abs(sign(x - y));
}

inline float3 rgb_2_HSV(float3 c)
{
    constexpr float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    constexpr float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

inline float3 HSV_2_rgb(float3 c)
{
    constexpr float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


inline float3 rgb_2_HSL(float3 color)
{
    float3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)
    
    float fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
    float fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB
    float delta = fmax - fmin;             //Delta RGB value
    
    hsl.z = clamp((fmax + fmin) * 0.5, 0.0, 1.0); // Luminance
    
    if (delta == 0.0)   //This is a gray, no chroma...
    {
        hsl.x = 0.0;	// Hue
        hsl.y = 0.0;	// Saturation
    }
    else                //Chromatic data...
    {
        if (hsl.z < 0.5)
            hsl.y = delta / (fmax + fmin); // Saturation
        else
            hsl.y = delta / (2.0 - fmax - fmin); // Saturation
        
        float deltaR = (((fmax - color.r) / 6.0) + (delta * 0.5)) / delta;
        float deltaG = (((fmax - color.g) / 6.0) + (delta * 0.5)) / delta;
        float deltaB = (((fmax - color.b) / 6.0) + (delta * 0.5)) / delta;
        
        if (color.r == fmax )     hsl.x = deltaB - deltaG; // Hue
        else if (color.g == fmax) hsl.x = 1.0/3.0 + deltaR - deltaB; // Hue
        else if (color.b == fmax) hsl.x = 2.0/3.0 + deltaG - deltaR; // Hue
        
        if (hsl.x < 0.0)       hsl.x += 1.0; // Hue
        else if (hsl.x > 1.0)  hsl.x -= 1.0; // Hue
    }
    
    return hsl;
}

inline float hue_2_rgb(float f1, float f2, float hue)
{
    if (hue < 0.0)      hue += 1.0;
    else if (hue > 1.0) hue -= 1.0;
    
    float res;
    
    if ((6.0 * hue) < 1.0)      res = f1 + (f2 - f1) * 6.0 * hue;
    else if ((2.0 * hue) < 1.0) res = f2;
    else if ((3.0 * hue) < 2.0) res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
    else                        res = f1;
    
    res = clamp(res, 0.0, 1.0);
    
    return res;
}

inline float3 HSL_2_rgb(float3 hsl)
{
    float3 rgb;
    
    if (hsl.y == 0.0) rgb = clamp(float3(hsl.z), float3(0.0), float3(1.0)); // Luminance
    else
    {
        float f2;
        
        if (hsl.z < 0.5) f2 = hsl.z * (1.0 + hsl.y);
        else             f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
        
        float f1 = 2.0 * hsl.z - f2;
        
        constexpr float tk = 1.0/3.0;
        
        rgb.r = hue_2_rgb(f1, f2, hsl.x + tk);
        rgb.g = hue_2_rgb(f1, f2, hsl.x);
        rgb.b = hue_2_rgb(f1, f2, hsl.x - tk);
    }
    
    return rgb;
}



inline float4 sampledColor(
                           texture2d<float, access::sample> inTexture,
                           texture2d<float, access::write> outTexture,
                           uint2 gid
                           ){
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    float w = outTexture.get_width();
    return mix(inTexture.sample(s, float2(gid) * float2(1.0/w, 1.0/outTexture.get_height())),
               inTexture.read(gid),
               when_eq(inTexture.get_width(), w) // whe equal read exact texture color
               );
}


kernel void kernel_view(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                        metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                        metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = sampledColor(inTexture,outTexture,gid);
    outTexture.write(inColor, gid);
}


kernel void kernel_EV(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                       metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                       constant float    &value [[buffer(0)]],
                       metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = sampledColor(inTexture,outTexture,gid);
    outTexture.write(inColor * pow(2 , value), gid);
}

kernel void kernel_red(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                       metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                       constant float    &value [[buffer(0)]],
                       metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = sampledColor(inTexture,outTexture,gid);
    inColor.rgb.r = inColor.rgb.r * value;
    outTexture.write(inColor, gid);
}

kernel void kernel_green(metal::texture2d<float, metal::access::sample> inTexture [[texture(0)]],
                         metal::texture2d<float, metal::access::write> outTexture [[texture(1)]],
                         metal::uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = sampledColor(inTexture,outTexture,gid);
    inColor.rgb.g = 0.5;
    outTexture.write(inColor, gid);
}

typedef struct {
    packed_float3 position;
    packed_float3 texcoord;
} IMPVertex;

typedef struct {
    float4 position [[position]];
    float2 texcoord;
} IMPVertexOut;

/**
 * View rendering vertex
 */
vertex IMPVertexOut vertex_passthrough(
                                       const device IMPVertex*   vertex_array [[ buffer(0) ]],
                                       unsigned int vid [[ vertex_id ]]) {
    
    
    IMPVertex in = vertex_array[vid];
    float3 position = float3(in.position);
    
    IMPVertexOut out;
    out.position = float4(position,1);
    out.texcoord = float2(float3(in.texcoord).xy);
    
    return out;
}

/**
 *  Pass through fragment
 *
 */
fragment float4 fragment_passthrough(
                                     IMPVertexOut in [[stage_in]],
                                     texture2d<float, access::sample> texture [[ texture(0) ]]
                                     ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    return texture.sample(s, in.texcoord.xy);
}

typedef struct {
    packed_float2 position;
    packed_float2 texcoord;
} VertexIn;

typedef struct {
    float4 position [[position]];
    float2 texcoord;
} VertexOut;


/**
 * View rendering vertex
 */
vertex VertexOut vertex_passview(
                                 device VertexIn*   verticies [[ buffer(0) ]],
                                 unsigned int        vid       [[ vertex_id ]]
                                 ) {
    VertexOut out;
    
    device VertexIn& v = verticies[vid];
    
    float3 position = float3(float2(v.position) , 0.0);
    
    out.position = float4(position, 1.0);
    
    out.texcoord = float2(v.texcoord);
    
    return out;
}

/**
 *  Pass through fragment
 *
 */
fragment float4 fragment_passview(
                                  VertexOut in [[ stage_in ]],
                                  texture2d<float, access::sample> texture [[ texture(0) ]]
                                  ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
    float3 rgb = texture.sample(s, in.texcoord).rgb;
    return float4(rgb, 1.0);
}

