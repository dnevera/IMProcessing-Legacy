//
//  IMPTypes.h
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPTypes_h
#define IMPTypes_h

#include "IMPConstants-Bridging-Metal.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct {
        float2 vectors[4][4];
    } IMPFloat2x4x4;
    

#ifndef __METAL_VERSION__
    
     typedef struct {
        float3 position;
        float3 texcoord;
    } IMPVertex;

#else
    
    typedef struct {
        packed_float3 position;
        packed_float3 texcoord;
    } IMPVertex;

    typedef struct {
        float4 position [[position]];
        float2 texcoord;
    } IMPVertexOut;

#endif
    
    typedef struct {
        float2 position;
        float2 slope;
    } IMPEdgel;
    
    typedef struct{
        IMPEdgel array[1024];
    }IMPEdgelList;

    
    typedef struct {
        float left;
        float right;
        float top;
        float bottom;
    } IMPRegion;
    
    typedef struct {
        float2 point[3][3];
    } IMPGradientCoords;
    
    typedef enum : uint {
        LUMINOSITY = 0,
        NORMAL
    }IMPBlendingMode;
    
    typedef struct {
        IMPBlendingMode    mode;
        float              opacity;
    } IMPBlending;
    
    typedef struct{
        IMPBlending    blending;
    } IMPAdjustment;
    
    typedef struct{
        float4   dominantColor;
        IMPBlending    blending;
    } IMPWBAdjustment;
    
    typedef struct{
        float        value;
        IMPBlending  blending;
    } IMPValueAdjustment;
    
    typedef struct{
        float        level;
        IMPBlending  blending;
    } IMPLevelAdjustment;
    
    
    typedef struct{
        float4   minimum;
        float4   maximum;
        IMPBlending    blending;
    } IMPContrastAdjustment;
    
    typedef struct{
        float hue;
        float saturation;
        float value;
    }IMPHSVLevel;
    
    typedef struct {
        IMPHSVLevel   master;
        IMPHSVLevel   levels[kIMP_Color_Ramps];
        IMPBlending   blending;
    } IMPHSVAdjustment;
    
    typedef struct {
        float total;
        float color;
        float luma;
    }IMPFilmGrainColor;
    
    typedef struct {
        bool                isColored;
        float               size;
        IMPFilmGrainColor   amount;
        IMPBlending         blending;
    } IMPFilmGrainAdjustment;
    
#ifdef __cplusplus
}
#endif

#endif /* IMPTypes_h */
