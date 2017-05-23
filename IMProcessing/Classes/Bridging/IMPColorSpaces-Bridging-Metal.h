//
//  IMPColorSpaces-Bridging-Metal.h
//  Pods
//
//  Created by denis svinarchuk on 05.05.17.
//
//

#ifndef IMPColorSpaces_Bridging_Metal_h
#define IMPColorSpaces_Bridging_Metal_h

#include "IMPConstants-Bridging-Metal.h"
#include "IMPTypes-Bridging-Metal.h"

//
// IMPRgbSpace = 0,
// IMPLabSpace = 1,
// IMPLchSpace = 2,
// IMPXyzSpace = 3,
// IMPLuvSpace = 4,
// IMPHsvSpace = 5,
// IMPHslSpace = 6,
// IMPYcbcrHDSpace = 7 // Full-range type
//

#define kIMP_STD_GAMMA 2.2

static constant float2 kIMP_ColorSpaceRanges[9][3] = {
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPRgbSpace
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPsRgbSpace
    { (float2){0,100},     (float2){-128,127},  (float2){-128,127} },  // IMPLabSpace https://en.wikipedia.org/wiki/Lab_color_space#Range_of_coordinates
    { (float2){0,100},     (float2){0,200},     (float2){0,360} },     // IMPLchSpace
    { (float2){0,95.047},  (float2){0,100},     (float2){0,108.883} }, // IMPXyzSpace http://www.easyrgb.com/en/math.php#text22
    //
    // TODO: Luv - is not a real Luv, it is a LutSpace from dcampof
    //
    // { (float2){0,100},     (float2){-134,220},  (float2){-140,122} },  // IMPLuvSpace http://cs.haifa.ac.il/hagit/courses/ist/Lectures/Demos/ColorApplet/me/
    { (float2){0,6},       (float2){0,1},       (float2){0,1} },
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPHsvSpace
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPHslSpace
    { (float2){0,255},     (float2){0,255},     (float2){0,255} }      // IMPYcbcrHDSpace  http://www.equasys.de/colorconversion.html
};


static inline float2 IMPgetColorSpaceRange (IMPColorSpaceIndex space, int channel) {
    return kIMP_ColorSpaceRanges[(int)(space)][channel];
}

static inline float rgb_gamma_correct(float c, float gamma)
{
//    constexpr float a = 0.055;
//    if(c < 0.0031308)
//        return 12.92*c;
//    else
//        return (1.0+a)*pow(c, 1.0/gamma) - a;
    return pow(c, 1.0/gamma);
}

static inline float3 rgb_gamma_correct_r3 (float3 rgb, float gamma) {
    return (float3){
        rgb_gamma_correct(rgb.x,gamma),
        rgb_gamma_correct(rgb.y,gamma),
        rgb_gamma_correct(rgb.z,gamma)
    };
}


//
// capces sources: http://www.easyrgb.com/index.php?X=MATH&H=02#text2
// luv sources:    https://www.ludd.ltu.se/~torger/dcamprof.html
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
static inline float3 IMPXYZ_2_Luv(float3 xyz)
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

static inline float3 IMPLuv_2_XYZ(float3 lutspace)
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
// HSL
//
static inline float3 IMPrgb_2_HSL(float3 color)
{
    float3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)
    
#ifdef __METAL_VERSION__
    float _fmin = min(min(color.x, color.y), color.z);    //Min. value of RGB
    float _fmax = max(max(color.x, color.y), color.z);    //Max. value of RGB
#else
    float _fmin = fmin(fmin(color.x, color.y), color.z);    //Min. value of RGB
    float _fmax = fmax(fmax(color.x, color.y), color.z);    //Max. value of RGB
#endif
    float delta = _fmax - _fmin;             //Delta RGB value
    
    hsl.z = vector_clamp((_fmax + _fmin) * 0.5, 0.0, 1.0); // Luminance
    
    if (delta == 0.0)   //This is a gray, no chroma...
    {
        hsl.x = 0.0;	// Hue
        hsl.y = 0.0;	// Saturation
    }
    else                //Chromatic data...
    {
        if (hsl.z < 0.5)
            hsl.y = delta / (_fmax + _fmin); // Saturation
        else
            hsl.y = delta / (2.0 - _fmax - _fmin); // Saturation
        
        float deltaR = (((_fmax - color.x) / 6.0) + (delta * 0.5)) / delta;
        float deltaG = (((_fmax - color.y) / 6.0) + (delta * 0.5)) / delta;
        float deltaB = (((_fmax - color.z) / 6.0) + (delta * 0.5)) / delta;
        
        if (color.x == _fmax )     hsl.x = deltaB - deltaG; // Hue
        else if (color.y == _fmax) hsl.x = 1.0/3.0 + deltaR - deltaB; // Hue
        else if (color.z == _fmax) hsl.x = 2.0/3.0 + deltaG - deltaR; // Hue
        
        if (hsl.x < 0.0)       hsl.x += 1.0; // Hue
        else if (hsl.x > 1.0)  hsl.x -= 1.0; // Hue
    }
    
    return hsl;
}

static inline float hue_2_rgb(float f1, float f2, float hue)
{
    if (hue < 0.0)      hue += 1.0;
    else if (hue > 1.0) hue -= 1.0;
    
    float res;
    
    if ((6.0 * hue) < 1.0)      res = f1 + (f2 - f1) * 6.0 * hue;
    else if ((2.0 * hue) < 1.0) res = f2;
    else if ((3.0 * hue) < 2.0) res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
    else                        res = f1;
    
    res = vector_clamp((float3){res,res,res}, (float3){0.0,0.0,0.0}, (float3){1.0,1.0,1.0}).x;
    
    return res;
}

static inline float3 IMPHSL_2_rgb(float3 hsl)
{
    float3 rgb;
    
    if (hsl.y == 0.0) {
        rgb = vector_clamp((float3){hsl.z,hsl.z,hsl.z}, (float3){0.0,0.0,0.0}, (float3){1.0,1.0,1.0}); // Luminance
    }
    else
    {
        float f2;
        
        if (hsl.z < 0.5) f2 = hsl.z * (1.0 + hsl.y);
        else             f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
        
        float f1 = 2.0 * hsl.z - f2;
        
        constexpr float tk = 1.0/3.0;
        
        rgb.x = hue_2_rgb(f1, f2, hsl.x + tk);
        rgb.y = hue_2_rgb(f1, f2, hsl.x);
        rgb.z = hue_2_rgb(f1, f2, hsl.x - tk);
    }
    
    return rgb;
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

//
// Lch
//
static inline float3 IMPLab_2_Lch(float3 xyz) {
    // let l = x
    // let a = y
    // let b = z, lch = xyz
    
    float h = atan2(xyz.z, xyz.y);
    if (h > 0)  { h = ( h / M_PI_F ) * 180; }
#ifdef __METAL_VERSION__
    else        { h = 360 - (  abs( h ) / M_PI_F ) * 180; }
#else
    else        { h = 360 - ( fabs( h ) / M_PI_F ) * 180; }
#endif
    
    float c = sqrt(xyz.y * xyz.y + xyz.z * xyz.z);
    
    return (float3){xyz.x, c, h};
}

static inline float3 IMPLch_2_Lab(float3 xyz) {
    // let l = x
    // let c = y
    // let h = z
    float h = xyz.z *  M_PI_F / 180;
    return (float3){xyz.x, cos(h) * xyz.y, sin(h) * xyz.y};
}

//
// YCbCr
//
// https://msdn.microsoft.com/en-us/library/ff635643.aspx
//

#define yCbCrHD_2_rgb_offset ((float3){0,128,128})

// HD matrix YCbCr: 0-255
#define yCbCrHD_2_rgb_Y  ((float3){ 0.299 * 255,  -0.168935 * 255,  0.499813 * 255})
#define yCbCrHD_2_rgb_Cb ((float3){ 0.587 * 255,  -0.331665 * 255, -0.418531 * 255})
#define yCbCrHD_2_rgb_Cr ((float3){ 0.114 * 255,   0.50059 * 255,  -0.081282 * 255})

#define yCbCrHD_2_rgb_YI  ((float3){0.003921568627451,   0.003921555147863,  0.003921638035507})
#define yCbCrHD_2_rgb_CbI ((float3){-0.0,               -0.001347958833295,  0.006940805571438})
#define yCbCrHD_2_rgb_CrI ((float3){0.005500096251684,  -0.002801572617586, -0.0})

//#define yCbCrHD_2_rgb_Y  ((float3){ 76.2450,  -43.0784,   127.4523 })
//#define yCbCrHD_2_rgb_Cb ((float3){ 149.6850, -84.5746,  -106.7254})
//#define yCbCrHD_2_rgb_Cr ((float3){ 29.0700,   127.6504, -20.7269})

// STD matrix Y:16-235, Cb,Cr:16-240
//#define yCbCr_2_rgb_Y  ((float3){ 65.481,  128.553, 24.966})
//#define yCbCr_2_rgb_Cb ((float3){-37.797, -74.203,  112.0 })
//#define yCbCr_2_rgb_Cr ((float3){ 112.0,  -93.786, -18.214})

// YUV
//#define yuv_2_rgb_Y ((float3){ ( 0.299),  ( 0.587), ( 0.114) })
//#define yuv_2_rgb_U ((float3){ (-0.147),  (-0.289), ( 0.436) })
//#define yuv_2_rgb_V ((float3){ ( 0.615),  (-0.515), (-0.100) })

#define yCbCrHD_M  (float3x3){ yCbCrHD_2_rgb_Y,  yCbCrHD_2_rgb_Cb,  yCbCrHD_2_rgb_Cr }
#define yCbCrHD_MI (float3x3){ yCbCrHD_2_rgb_YI, yCbCrHD_2_rgb_CbI, yCbCrHD_2_rgb_CrI}

static inline float3 IMPrgb_2_YCbCrHD(float3 rgb){
#ifdef __METAL_VERSION__
    return float3(yCbCrHD_M * rgb + yCbCrHD_2_rgb_offset);
#else
    return (matrix_multiply(yCbCrHD_M,rgb) + yCbCrHD_2_rgb_offset);
#endif
}

static inline float3 IMPYCbCrHD_2_rgb(float3 YCbCr){
#ifdef __METAL_VERSION__
    return float3(yCbCrHD_MI * float3(YCbCr - yCbCrHD_2_rgb_offset));
#else
    return matrix_multiply(yCbCrHD_MI,(float3)(YCbCr - yCbCrHD_2_rgb_offset));
#endif
}

//
// Paired Convertors
//

//
// RGB
//
static inline float3 IMPrgb2srgb(float3 color){
    return rgb_gamma_correct_r3(color, kIMP_STD_GAMMA);
}
static inline float3 IMPrgb2xyz(float3 color){
    return IMPrgb_2_XYZ(color);
}
static inline float3 IMPrgb2hsv(float3 color){
    return IMPrgb_2_HSV(color);
}
static inline float3 IMPrgb2hsl(float3 color){
    return IMPrgb_2_HSL(color);
}
static inline float3 IMPrgb2lab(float3 color){
    return IMPXYZ_2_Lab(IMPrgb_2_XYZ(color));
}
static inline float3 IMPrgb2lch(float3 color){
    return IMPLab_2_Lch(IMPrgb2lab(color));
}
static inline float3 IMPrgb2luv(float3 color){
    return IMPXYZ_2_Luv(IMPrgb_2_XYZ(color));
}
static inline float3 IMPrgb2ycbcrHD(float3 color){
    return IMPrgb_2_YCbCrHD(color);
}


//
// Lab
//
static inline float3 IMPlab2xyz(float3 color){
    return IMPLab_2_XYZ(color);
}
static inline float3 IMPlab2lch(float3 color){
    return IMPLab_2_Lch(color);
}
static inline float3 IMPlab2rgb(float3 color){
    return IMPXYZ_2_rgb(IMPlab2xyz(color));
}
static inline float3 IMPlab2hsv(float3 color){
    return IMPrgb2hsv(IMPlab2rgb(color));
}
static inline float3 IMPlab2hsl(float3 color){
    return IMPrgb2hsl(IMPlab2rgb(color));
}
static inline float3 IMPlab2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPlab2rgb(color));
}
static inline float3 IMPlab2luv(float3 color){
    return IMPXYZ_2_Luv(IMPlab2xyz(color));
}

static inline float3 IMPlab2srgb(float3 color){
    return IMPrgb2srgb(IMPlab2rgb(color));
}



//
// XYZ
//
static inline float3 IMPxyz2lab(float3 color){
    return IMPXYZ_2_Lab(color);
}
static inline float3 IMPxyz2lch(float3 color){
    return IMPLab_2_Lch(IMPxyz2lab(color));
}
static inline float3 IMPxyz2rgb(float3 color){
    return IMPXYZ_2_rgb(color);
}
static inline float3 IMPxyz2hsv(float3 color){
    return IMPrgb2hsv(IMPxyz2rgb(color));
}
static inline float3 IMPxyz2hsl(float3 color){
    return IMPrgb2hsl(IMPxyz2rgb(color));
}
static inline float3 IMPxyz2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPxyz2rgb(color));
}
static inline float3 IMPxyz2luv(float3 color){
    return IMPXYZ_2_Luv(color);
}

static inline float3 IMPxyz2srgb(float3 color){
    return IMPrgb2srgb(IMPxyz2rgb(color));
}

//
// LCH
//
static inline float3 IMPlch2lab(float3 color){
    return IMPLch_2_Lab(color);
}
static inline float3 IMPlch2rgb(float3 color){
    return IMPlab2rgb(IMPlch2lab(color));
}
static inline float3 IMPlch2hsv(float3 color){
    return IMPrgb2hsv(IMPlch2rgb(color));
}
static inline float3 IMPlch2hsl(float3 color){
    return IMPrgb2hsl(IMPlch2rgb(color));
}
static inline float3 IMPlch2xyz(float3 color){
    return IMPlab2xyz(IMPlch2lab(color));
}
static inline float3 IMPlch2luv(float3 color){
    return IMPXYZ_2_Luv(IMPlch2xyz(color));
}
static inline float3 IMPlch2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPlch2rgb(color));
}

static inline float3 IMPlch2srgb(float3 color){
    return IMPrgb2srgb(IMPlch2rgb(color));
}

//
// HSV
//
static inline float3 IMPhsv2lab(float3 color){
    return IMPrgb2lab(IMPHSV_2_rgb(color));
}
static inline float3 IMPhsv2rgb(float3 color){
    return IMPHSV_2_rgb(color);
}
static inline float3 IMPhsv2lch(float3 color){
    return IMPrgb2lch(IMPhsv2rgb(color));
}
static inline float3 IMPhsv2hsl(float3 color){
    return IMPrgb2hsl(IMPhsv2rgb(color));
}
static inline float3 IMPhsv2xyz(float3 color){
    return IMPrgb2xyz(IMPhsv2rgb(color));
}
static inline float3 IMPhsv2luv(float3 color){
    return IMPXYZ_2_Luv(IMPhsv2xyz(color));
}
static inline float3 IMPhsv2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPhsv2rgb(color));
}

static inline float3 IMPhsv2srgb(float3 color){
    return IMPrgb2srgb(IMPhsv2rgb(color));
}

//
// HSL
//
static inline float3 IMPhsl2lab(float3 color){
    return IMPrgb2lab(IMPHSL_2_rgb(color));
}
static inline float3 IMPhsl2rgb(float3 color){
    return IMPHSL_2_rgb(color);
}
static inline float3 IMPhsl2lch(float3 color){
    return IMPrgb2lch(IMPhsl2rgb(color));
}
static inline float3 IMPhsl2hsv(float3 color){
    return IMPrgb2hsv(IMPhsl2rgb(color));
}
static inline float3 IMPhsl2xyz(float3 color){
    return IMPrgb2xyz(IMPhsl2rgb(color));
}
static inline float3 IMPhsl2luv(float3 color){
    return IMPXYZ_2_Luv(IMPhsl2xyz(color));
}
static inline float3 IMPhsl2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPhsl2rgb(color));
}

static inline float3 IMPhsl2srgb(float3 color){
    return IMPrgb2srgb(IMPhsl2rgb(color));
}


//
// Luv
//
static inline float3 IMPluv2rgb(float3 color){
    return IMPXYZ_2_rgb(IMPLuv_2_XYZ(color));
}
static inline float3 IMPluv2lab(float3 color){
    return IMPxyz2lab(IMPLuv_2_XYZ(color));
}
static inline float3 IMPluv2lch(float3 color){
    return IMPlab2lch(IMPluv2lab(color));
}
static inline float3 IMPluv2hsv(float3 color){
    return IMPrgb2hsv(IMPluv2rgb(color));
}
static inline float3 IMPluv2hsl(float3 color){
    return IMPrgb2hsl(IMPluv2rgb(color));
}
static inline float3 IMPluv2xyz(float3 color){
    return IMPLuv_2_XYZ(color);
}
static inline float3 IMPluv2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPluv2rgb(color));
}

static inline float3 IMPluv2srgb(float3 color){
    return IMPrgb2srgb(IMPluv2rgb(color));
}


//
// YCbCrHD
//
static inline float3 IMPycbcrHD2rgb(float3 color){
    return IMPYCbCrHD_2_rgb(color);
}
static inline float3 IMPycbcrHD2lab(float3 color){
    return IMPrgb2lab(IMPYCbCrHD_2_rgb(color));
}
static inline float3 IMPycbcrHD2lch(float3 color){
    return IMPlab2lch(IMPycbcrHD2lab(color));
}
static inline float3 IMPycbcrHD2hsv(float3 color){
    return IMPrgb2hsv(IMPycbcrHD2rgb(color));
}
static inline float3 IMPycbcrHD2hsl(float3 color){
    return IMPrgb2hsl(IMPycbcrHD2rgb(color));
}
static inline float3 IMPycbcrHD2xyz(float3 color){
    return  IMPrgb_2_XYZ(IMPycbcrHD2rgb(color));
}
static inline float3 IMPycbcrHD2luv(float3 color){
    return IMPrgb2luv(IMPycbcrHD2rgb(color));
}

static inline float3 IMPycbcrHD2srgb(float3 color){
    return IMPrgb2srgb(IMPycbcrHD2rgb(color));
}

//
//sRGB
//
static inline float3 IMPsrgb2rgb(float3 color){
    return rgb_gamma_correct_r3(color, 1/kIMP_STD_GAMMA);
}
static inline float3 IMPsrgb2lab(float3 color){
    return IMPrgb2lab(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2xyz(float3 color){
    return IMPrgb2xyz(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2lch(float3 color){
    return IMPrgb2lch(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2hsv(float3 color){
    return IMPrgb2hsv(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2hsl(float3 color){
    return IMPrgb2hsl(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2luv(float3 color){
    return IMPrgb2luv(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPsrgb2rgb(color));
}



static inline float3 IMPConvertColor(IMPColorSpaceIndex from_cs, IMPColorSpaceIndex to_cs, float3 value) {
    switch (to_cs) {
            
        case IMPRgbSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return value;
                case IMPsRgbSpace:
                    return IMPrgb2srgb(value);
                case IMPLabSpace:
                    return IMPlab2rgb(value);
                case IMPLchSpace:
                    return IMPlch2rgb(value);
                case IMPHsvSpace:
                    return IMPhsv2rgb(value);
                case IMPHslSpace:
                    return IMPhsl2rgb(value);
                case IMPXyzSpace:
                    return IMPxyz2rgb(value);
                case IMPLuvSpace:
                    return IMPluv2rgb(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2rgb(value);
            }
            break;
            
        case IMPsRgbSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2srgb(value);
                case IMPsRgbSpace:
                    return value;
                case IMPLabSpace:
                    return IMPlab2srgb(value);
                case IMPLchSpace:
                    return IMPlch2srgb(value);
                case IMPHsvSpace:
                    return IMPhsv2srgb(value);
                case IMPHslSpace:
                    return IMPhsl2srgb(value);
                case IMPXyzSpace:
                    return IMPxyz2srgb(value);
                case IMPLuvSpace:
                    return IMPluv2srgb(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2srgb(value);
            }
            break;
          
        case IMPLabSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2lab(value);
                case IMPsRgbSpace:
                    return IMPsrgb2lab(value);
                case IMPLabSpace:
                    return value;
                case IMPLchSpace:
                    return IMPlch2lab(value);
                case IMPHsvSpace:
                    return IMPhsv2lab(value);
                case IMPHslSpace:
                    return IMPhsl2lab(value);
                case IMPXyzSpace:
                    return IMPxyz2lab(value);
                case IMPLuvSpace:
                    return IMPluv2lab(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2lab(value);
            }
            
        case IMPLuvSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2luv(value);
                case IMPsRgbSpace:
                    return IMPsrgb2luv(value);
                case IMPLabSpace:
                    return IMPlab2luv(value);
                case IMPLchSpace:
                    return IMPlch2luv(value);
                case IMPHsvSpace:
                    return IMPhsv2luv(value);
                case IMPHslSpace:
                    return IMPhsl2luv(value);
                case IMPXyzSpace:
                    return IMPxyz2luv(value);
                case IMPLuvSpace:
                    return value;
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2luv(value);
            }
            
        case IMPXyzSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2xyz(value);
                case IMPsRgbSpace:
                    return IMPsrgb2xyz(value);
                case IMPLabSpace:
                    return IMPlab2xyz(value);
                case IMPLchSpace:
                    return IMPlch2xyz(value);
                case IMPHsvSpace:
                    return IMPhsv2xyz(value);
                case IMPHslSpace:
                    return IMPhsl2xyz(value);
                case IMPXyzSpace:
                    return value;
                case IMPLuvSpace:
                    return IMPluv2xyz(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2xyz(value);
            }
            
        case IMPHsvSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2hsv(value);
                case IMPsRgbSpace:
                    return IMPsrgb2hsv(value);
                case IMPLabSpace:
                    return IMPlab2hsv(value);
                case IMPLchSpace:
                    return IMPlch2hsv(value);
                case IMPHsvSpace:
                    return value;
                case IMPHslSpace:
                    return IMPhsl2hsv(value);
                case IMPXyzSpace:
                    return IMPxyz2hsv(value);
                case IMPLuvSpace:
                    return IMPluv2hsv(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2hsv(value);
            }
            
        case IMPHslSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2hsl(value);
                case IMPsRgbSpace:
                    return IMPsrgb2hsl(value);
                case IMPLabSpace:
                    return IMPlab2hsl(value);
                case IMPLchSpace:
                    return IMPlch2hsl(value);
                case IMPHsvSpace:
                    return IMPhsv2hsl(value);
                case IMPHslSpace:
                    return value;
                case IMPXyzSpace:
                    return IMPxyz2hsl(value);
                case IMPLuvSpace:
                    return IMPluv2hsl(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2hsl(value);
            }
            
        case IMPLchSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2lch(value);
                case IMPsRgbSpace:
                    return IMPsrgb2lch(value);
                case IMPLabSpace:
                    return IMPlab2lch(value);
                case IMPLchSpace:
                    return value;
                case IMPHsvSpace:
                    return IMPhsv2lch(value);
                case IMPHslSpace:
                    return IMPhsl2lch(value);
                case IMPXyzSpace:
                    return IMPxyz2lch(value);
                case IMPLuvSpace:
                    return IMPluv2lch(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2lch(value);
            }
            
        case IMPYcbcrHDSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2ycbcrHD(value);
                case IMPsRgbSpace:
                    return IMPsrgb2ycbcrHD(value);
                case IMPLabSpace:
                    return IMPlab2ycbcrHD(value);
                case IMPLchSpace:
                    return IMPlch2ycbcrHD(value);
                case IMPHsvSpace:
                    return IMPhsv2ycbcrHD(value);
                case IMPHslSpace:
                    return IMPhsl2ycbcrHD(value);
                case IMPXyzSpace:
                    return IMPxyz2ycbcrHD(value);
                case IMPLuvSpace:
                    return IMPluv2ycbcrHD(value);
                case IMPYcbcrHDSpace:
                    return value;
            }
    }
    return value;;
}


#endif /* IMPColorSpaces_Bridging_Metal_h */
