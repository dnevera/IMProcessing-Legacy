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
// IMPRgbSpace  = 0,
// IMPaRgbSpace = 1,
// IMPLabSpace  = 2,
// IMPLchSpace  = 3,
// IMPXyzSpace  = 4,
// IMPDCProfLutSpace = 5,
// IMPHsvSpace  = 6,
// IMPHslSpace  = 7,
// IMPYcbcrHDSpace = 8 // Full-range type
// IMPHspSpace  = 9
//

static constant float2 kIMP_ColorSpaceRanges[10][3] = {
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPRgbSpace
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPsRgbSpace
    { (float2){0,100},     (float2){-128,127},  (float2){-128,127} },  // IMPLabSpace       https://en.wikipedia.org/wiki/Lab_color_space#Range_of_coordinates
    { (float2){0,100},     (float2){0,141.421}, (float2){0,360} },     // IMPLchSpace
    { (float2){0,95.047},  (float2){0,100},     (float2){0,108.883} }, // IMPXyzSpace       http://www.easyrgb.com/en/math.php#text22
    { (float2){0,6},       (float2){0,1},       (float2){0,1} },       // IMPDCProfLutSpace https://www.ludd.ltu.se/~torger/dcamprof.html
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPHsvSpace
    { (float2){0,1},       (float2){0,1},       (float2){0,1} },       // IMPHslSpace
    { (float2){0,255},     (float2){0,255},     (float2){0,255} },     // IMPYcbcrHDSpace   http://www.equasys.de/colorconversion.html
    { (float2){0,1},       (float2){0,1},       (float2){0,1} }        // IMPHspSpace       http://alienryderflex.com/hsp.html
};


static inline float2 IMPgetColorSpaceRange (IMPColorSpaceIndex space, int channel) {
    return kIMP_ColorSpaceRanges[(int)(space)][channel];
}

#define IMPGetColorSpaceRange IMPgetColorSpaceRange

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
// sources: http://www.easyrgb.com/index.php?X=MATH&H=02#text2
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
// dcproflut sources:    https://www.ludd.ltu.se/~torger/dcamprof.html
//
static inline float3 IMPXYZ_2_dcproflut(float3 xyz)
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

static inline float3 IMPdcproflut_2_XYZ(float3 lutspace)
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
// HSP  http://alienryderflex.com/hsp.html
//
#define  Pr  .299
#define  Pg  .587
#define  Pb  .114

//
//  public domain function by Darel Rex Finley, 2006
//
//  This function expects the passed-in values to be on a scale
//  of 0 to 1, and uses that same scale for the return values.
//
//  See description/examples at alienryderflex.com/hsp.html

static inline float3 RGBtoHSP( float  R, float  G, float  B) {
    
    float H, S, P;
    
    //  Calculate the Perceived brightness.
    P=sqrt(R*R*Pr+G*G*Pg+B*B*Pb);
    
    //  Calculate the Hue and Saturation.  (This part works
    //  the same way as in the HSV/B and HSL systems???.)
    if      (R==G && R==B) {
        H=0.; S=0.;
        return (float3){H,S,P};
    }
    
    if      (R>=G && R>=B) {   //  R is largest
        if    (B>=G) {
            H=6./6.-1./6.*(B-G)/(R-G); S=1.-G/R; }
        else         {
            H=0./6.+1./6.*(G-B)/(R-B); S=1.-B/R; }}
    else if (G>=R && G>=B) {   //  G is largest
        if    (R>=B) {
            H=2./6.-1./6.*(R-B)/(G-B); S=1.-B/G; }
        else         {
            H=2./6.+1./6.*(B-R)/(G-R); S=1.-R/G; }}
    else                   {   //  B is largest
        if    (G>=R) {
            H=4./6.-1./6.*(G-R)/(B-R); S=1.-R/B; }
        else         {
            H=4./6.+1./6.*(R-G)/(B-G); S=1.-G/B;
        }
    }
    
    return (float3){H,S,P};
}


//  public domain function by Darel Rex Finley, 2006
//
//  This function expects the passed-in values to be on a scale
//  of 0 to 1, and uses that same scale for the return values.
//
//  Note that some combinations of HSP, even if in the scale
//  0-1, may return RGB values that exceed a value of 1.  For
//  example, if you pass in the HSP color 0,1,1, the result
//  will be the RGB color 2.037,0,0.
//
//  See description/examples at alienryderflex.com/hsp.html

static inline float3 HSPtoRGB(float H, float  S, float  P) {
    
    float R, G, B;

    float  part, minOverMax=1.-S ;
    
    if (minOverMax>0.) {
        if      ( H<1./6.) {   //  R>G>B
            H= 6.*( H-0./6.); part=1.+H*(1./minOverMax-1.);
            B=P/sqrt(Pr/minOverMax/minOverMax+Pg*part*part+Pb);
            R=(B)/minOverMax; G=(B)+H*((R)-(B)); }
        else if ( H<2./6.) {   //  G>R>B
            H= 6.*(-H+2./6.); part=1.+H*(1./minOverMax-1.);
            B=P/sqrt(Pg/minOverMax/minOverMax+Pr*part*part+Pb);
            G=(B)/minOverMax; R=(B)+H*((G)-(B)); }
        else if ( H<3./6.) {   //  G>B>R
            H= 6.*( H-2./6.); part=1.+H*(1./minOverMax-1.);
            R=P/sqrt(Pg/minOverMax/minOverMax+Pb*part*part+Pr);
            G=(R)/minOverMax; B=(R)+H*((G)-(R)); }
        else if ( H<4./6.) {   //  B>G>R
            H= 6.*(-H+4./6.); part=1.+H*(1./minOverMax-1.);
            R=P/sqrt(Pb/minOverMax/minOverMax+Pg*part*part+Pr);
            B=(R)/minOverMax; G=(R)+H*((B)-(R)); }
        else if ( H<5./6.) {   //  B>R>G
            H= 6.*( H-4./6.); part=1.+H*(1./minOverMax-1.);
            G=P/sqrt(Pb/minOverMax/minOverMax+Pr*part*part+Pg);
            B=(G)/minOverMax; R=(G)+H*((B)-(G)); }
        else               {   //  R>B>G
            H= 6.*(-H+6./6.); part=1.+H*(1./minOverMax-1.);
            G=P/sqrt(Pr/minOverMax/minOverMax+Pb*part*part+Pg);
            R=(G)/minOverMax; B=(G)+H*((R)-(G)); }}
    else {
        if      ( H<1./6.) {   //  R>G>B
            H= 6.*( H-0./6.); R=sqrt(P*P/(Pr+Pg*H*H)); G=(R)*H; B=0.; }
        else if ( H<2./6.) {   //  G>R>B
            H= 6.*(-H+2./6.); G=sqrt(P*P/(Pg+Pr*H*H)); R=(G)*H; B=0.; }
        else if ( H<3./6.) {   //  G>B>R
            H= 6.*( H-2./6.); G=sqrt(P*P/(Pg+Pb*H*H)); B=(G)*H; R=0.; }
        else if ( H<4./6.) {   //  B>G>R
            H= 6.*(-H+4./6.); B=sqrt(P*P/(Pb+Pg*H*H)); G=(B)*H; R=0.; }
        else if ( H<5./6.) {   //  B>R>G
            H= 6.*( H-4./6.); B=sqrt(P*P/(Pb+Pr*H*H)); R=(B)*H; G=0.; }
        else               {   //  R>B>G
            H= 6.*(-H+6./6.); R=sqrt(P*P/(Pr+Pb*H*H)); B=(R)*H; G=0.; }
    }
    
    return (float3){R,G,B};
}

static inline float3 IMPrgb_2_HSP(float3 color) {
    return RGBtoHSP(color.x, color.y, color.z);
}

static inline float3 IMPHSP_2_rgb(float3 hsp) {
    return HSPtoRGB(hsp.x, hsp.y, hsp.z);
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
// https://web.archive.org/web/20030212204955/http://www.srgb.com:80/basicsofsrgb.htm
// The linear RGB values are transformed to nonlinear sR'G'B' values as follows:
//
// If  R,G, B <= 0.0031308
// RsRGB = 12.92 * R
// GsRGB = 12.92 * G
// BsRGB = 12.92 * B
//
// else if  R,G, B > 0.0031308
// RsRGB = 1.055 * R(1.0/2.4) - 0.055
// GsRGB = 1.055 * G(1.0/2.4) - 0.055
// BsRGB = 1.055 * B(1.0/2.4) - 0.055
//

static inline float rgb2srgb_transform(float c, float gamma)
{
    constexpr float a = 0.055;
    if(c <= 0.0031308)
        return 12.92*c;
    else
        return (1.0+a)*pow(c, 1.0/gamma) - a;
}

static inline float3 rgb2srgb_transform_r3 (float3 rgb, float gamma) {
    return (float3){
        rgb2srgb_transform(rgb.x,gamma),
        rgb2srgb_transform(rgb.y,gamma),
        rgb2srgb_transform(rgb.z,gamma)
    };
}

static inline float3 IMPrgb2srgb(float3 color){
    return rgb2srgb_transform_r3(color, kIMP_RGB2SRGB_Gamma);
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
static inline float3 IMPrgb2hsp(float3 color){
    return IMPrgb_2_HSP(color);
}
static inline float3 IMPrgb2lab(float3 color){
    return IMPXYZ_2_Lab(IMPrgb_2_XYZ(color));
}
static inline float3 IMPrgb2lch(float3 color){
    return IMPLab_2_Lch(IMPrgb2lab(color));
}
static inline float3 IMPrgb2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPrgb_2_XYZ(color));
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
static inline float3 IMPlab2hsp(float3 color){
    return IMPrgb2hsp(IMPlab2rgb(color));
}
static inline float3 IMPlab2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPlab2rgb(color));
}
static inline float3 IMPlab2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPlab2xyz(color));
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
static inline float3 IMPxyz2hsp(float3 color){
    return IMPrgb2hsp(IMPxyz2rgb(color));
}
static inline float3 IMPxyz2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPxyz2rgb(color));
}
static inline float3 IMPxyz2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(color);
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
static inline float3 IMPlch2hsp(float3 color){
    return IMPrgb2hsp(IMPlch2rgb(color));
}
static inline float3 IMPlch2xyz(float3 color){
    return IMPlab2xyz(IMPlch2lab(color));
}
static inline float3 IMPlch2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPlch2xyz(color));
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
static inline float3 IMPhsv2hsp(float3 color){
    return IMPrgb2hsp(IMPhsv2rgb(color));
}
static inline float3 IMPhsv2xyz(float3 color){
    return IMPrgb2xyz(IMPhsv2rgb(color));
}
static inline float3 IMPhsv2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPhsv2xyz(color));
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
static inline float3 IMPhsl2hsp(float3 color){
    return IMPrgb2hsp(IMPhsl2rgb(color));
}
static inline float3 IMPhsl2xyz(float3 color){
    return IMPrgb2xyz(IMPhsl2rgb(color));
}
static inline float3 IMPhsl2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPhsl2xyz(color));
}
static inline float3 IMPhsl2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPhsl2rgb(color));
}

static inline float3 IMPhsl2srgb(float3 color){
    return IMPrgb2srgb(IMPhsl2rgb(color));
}

//
// HSP
//
static inline float3 IMPhsp2lab(float3 color){
    return IMPrgb2lab(IMPHSP_2_rgb(color));
}
static inline float3 IMPhsp2rgb(float3 color){
    return IMPHSP_2_rgb(color);
}
static inline float3 IMPhsp2lch(float3 color){
    return IMPrgb2lch(IMPhsp2rgb(color));
}
static inline float3 IMPhsp2hsv(float3 color){
    return IMPrgb2hsv(IMPhsp2rgb(color));
}
static inline float3 IMPhsp2hsl(float3 color){
    return IMPrgb2hsl(IMPhsp2rgb(color));
}
static inline float3 IMPhsp2xyz(float3 color){
    return IMPrgb2xyz(IMPhsp2rgb(color));
}
static inline float3 IMPhsp2dcproflut(float3 color){
    return IMPXYZ_2_dcproflut(IMPhsp2xyz(color));
}
static inline float3 IMPhsp2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPhsp2rgb(color));
}

static inline float3 IMPhsp2srgb(float3 color){
    return IMPrgb2srgb(IMPhsp2rgb(color));
}



//
// dcproflut
//
static inline float3 IMPdcproflut2rgb(float3 color){
    return IMPXYZ_2_rgb(IMPdcproflut_2_XYZ(color));
}
static inline float3 IMPdcproflut2lab(float3 color){
    return IMPxyz2lab(IMPdcproflut_2_XYZ(color));
}
static inline float3 IMPdcproflut2lch(float3 color){
    return IMPlab2lch(IMPdcproflut2lab(color));
}
static inline float3 IMPdcproflut2hsv(float3 color){
    return IMPrgb2hsv(IMPdcproflut2rgb(color));
}
static inline float3 IMPdcproflut2hsl(float3 color){
    return IMPrgb2hsl(IMPdcproflut2rgb(color));
}
static inline float3 IMPdcproflut2hsp(float3 color){
    return IMPrgb2hsp(IMPdcproflut2rgb(color));
}
static inline float3 IMPdcproflut2xyz(float3 color){
    return IMPdcproflut_2_XYZ(color);
}
static inline float3 IMPdcproflut2ycbcrHD(float3 color){
    return IMPrgb2ycbcrHD(IMPdcproflut2rgb(color));
}

static inline float3 IMPdcproflut2srgb(float3 color){
    return IMPrgb2srgb(IMPdcproflut2rgb(color));
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
static inline float3 IMPycbcrHD2hsp(float3 color){
    return IMPrgb2hsp(IMPycbcrHD2rgb(color));
}
static inline float3 IMPycbcrHD2xyz(float3 color){
    return  IMPrgb_2_XYZ(IMPycbcrHD2rgb(color));
}
static inline float3 IMPycbcrHD2dcproflut(float3 color){
    return IMPrgb2dcproflut(IMPycbcrHD2rgb(color));
}

static inline float3 IMPycbcrHD2srgb(float3 color){
    return IMPrgb2srgb(IMPycbcrHD2rgb(color));
}

//
//sRGB
//
//
//
// The nonlinear sR'G'B' values are transformed to linear R,G, B values by:
//
// If  RsRGB,GsRGB, BsRGB <= 0.04045
// R =  RsRGB * 12.92
// G =  GsRGB * 12.92
// B =  BsRGB * 12.92
//
// else if  RsRGB,GsRGB, BsRGB > 0.04045
// R = ((RsRGB + 0.055) / 1.055)^2.4
// G = ((GsRGB + 0.055) / 1.055)^2.4
// B = ((BsRGB + 0.055) / 1.055)^2.4

static inline float srgb2rgb_transform(float c, float gamma)
{
    constexpr float a = 0.055;
    if(c <= 0.04045)
        return c/12.92;
    else
        return pow(((c + a)/(1+a)),gamma);
}

static inline float3 srgb2rgb_transform_r3 (float3 rgb, float gamma) {
    return (float3){
        srgb2rgb_transform(rgb.x,gamma),
        srgb2rgb_transform(rgb.y,gamma),
        srgb2rgb_transform(rgb.z,gamma)
    };
}

static inline float3 IMPsrgb2rgb(float3 color){
    return srgb2rgb_transform_r3(color, kIMP_RGB2SRGB_Gamma);
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
static inline float3 IMPsrgb2hsp(float3 color){
    return IMPrgb2hsp(IMPsrgb2rgb(color));
}
static inline float3 IMPsrgb2dcproflut(float3 color){
    return IMPrgb2dcproflut(IMPsrgb2rgb(color));
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
                    return IMPsrgb2rgb(value);
                case IMPLabSpace:
                    return IMPlab2rgb(value);
                case IMPLchSpace:
                    return IMPlch2rgb(value);
                case IMPHsvSpace:
                    return IMPhsv2rgb(value);
                case IMPHslSpace:
                    return IMPhsl2rgb(value);
                case IMPHspSpace:
                    return IMPhsp2rgb(value);
                case IMPXyzSpace:
                    return IMPxyz2rgb(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2rgb(value);
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
                case IMPHspSpace:
                    return IMPhsp2srgb(value);
                case IMPXyzSpace:
                    return IMPxyz2srgb(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2srgb(value);
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
                case IMPHspSpace:
                    return IMPhsp2lab(value);
                case IMPXyzSpace:
                    return IMPxyz2lab(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2lab(value);
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2lab(value);
            }
            
        case IMPDCProfLutSpace:
            switch (from_cs) {
                case IMPRgbSpace:
                    return IMPrgb2dcproflut(value);
                case IMPsRgbSpace:
                    return IMPsrgb2dcproflut(value);
                case IMPLabSpace:
                    return IMPlab2dcproflut(value);
                case IMPLchSpace:
                    return IMPlch2dcproflut(value);
                case IMPHsvSpace:
                    return IMPhsv2dcproflut(value);
                case IMPHslSpace:
                    return IMPhsl2dcproflut(value);
                case IMPHspSpace:
                    return IMPhsp2dcproflut(value);
                case IMPXyzSpace:
                    return IMPxyz2dcproflut(value);
                case IMPDCProfLutSpace:
                    return value;
                case IMPYcbcrHDSpace:
                    return IMPycbcrHD2dcproflut(value);
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
                case IMPHspSpace:
                    return IMPhsp2xyz(value);
                case IMPXyzSpace:
                    return value;
                case IMPDCProfLutSpace:
                    return IMPdcproflut2xyz(value);
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
                case IMPHspSpace:
                    return IMPhsp2hsv(value);
                case IMPXyzSpace:
                    return IMPxyz2hsv(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2hsv(value);
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
            case IMPHspSpace:
            return IMPhsv2hsp(value);
            case IMPXyzSpace:
            return IMPxyz2hsl(value);
            case IMPDCProfLutSpace:
            return IMPdcproflut2hsl(value);
            case IMPYcbcrHDSpace:
            return IMPycbcrHD2hsl(value);
        }
        
        case IMPHspSpace:
        switch (from_cs) {
            case IMPRgbSpace:
            return IMPrgb2hsp(value);
            case IMPsRgbSpace:
            return IMPsrgb2hsp(value);
            case IMPLabSpace:
            return IMPlab2hsp(value);
            case IMPLchSpace:
            return IMPlch2hsp(value);
            case IMPHsvSpace:
            return IMPhsv2hsp(value);
            case IMPHslSpace:
            return IMPhsl2hsp(value);
            case IMPHspSpace:
            return value;
            case IMPXyzSpace:
            return IMPxyz2hsp(value);
            case IMPDCProfLutSpace:
            return IMPdcproflut2hsp(value);
            case IMPYcbcrHDSpace:
            return IMPycbcrHD2hsp(value);
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
                case IMPHspSpace:
                return IMPhsp2lch(value);
                case IMPXyzSpace:
                    return IMPxyz2lch(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2lch(value);
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
                case IMPHspSpace:
                return IMPhsp2ycbcrHD(value);
                case IMPXyzSpace:
                    return IMPxyz2ycbcrHD(value);
                case IMPDCProfLutSpace:
                    return IMPdcproflut2ycbcrHD(value);
                case IMPYcbcrHDSpace:
                    return value;
            }
    }
    return value;;
}

static inline float3 IMPConvertToNormalizedColor(IMPColorSpaceIndex from, IMPColorSpaceIndex to, float3 rgb) {
    float3 color = IMPConvertColor(from, to, rgb);
    
    float2 xr = IMPgetColorSpaceRange(to,0);
    float2 yr = IMPgetColorSpaceRange(to,1);
    float2 zr = IMPgetColorSpaceRange(to,2);
    
    return (float3){(color.x-xr.x)/(xr.y-xr.x), (color.y-yr.x)/(yr.y-yr.x), (color.z-zr.x)/(zr.y-zr.x)};
}

static inline float3 IMPConvertFromNormalizedColor(IMPColorSpaceIndex from, IMPColorSpaceIndex to, float3 rgb) {
    
    float2 xr = IMPgetColorSpaceRange(from,0);
    float2 yr = IMPgetColorSpaceRange(from,1);
    float2 zr = IMPgetColorSpaceRange(from,2);
    
    float x = rgb.x * (xr.y-xr.x) + xr.x;
    float y = rgb.y * (yr.y-yr.x) + yr.x;
    float z = rgb.z * (zr.y-zr.x) + zr.x;
    
    return IMPConvertColor(from, to, (float3){x,y,z});
    
}

#endif /* IMPColorSpaces_Bridging_Metal_h */
