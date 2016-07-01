//
//  IMPHistogramLayer_metal.h
//  IMProcessing
//
//  Created by denis svinarchuk on 18.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#ifndef IMPHistogramLayer_metal_h
#define IMPHistogramLayer_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPConstants_metal.h"
#include "IMPBlending_metal.h"
#include "IMPCommon_metal.h"

using namespace metal;

#ifdef __cplusplus


namespace IMProcessing
{
    kernel void kernel_histogramGenerator(texture2d<float, access::sample>      inTexture  [[texture(0)]],
                                          texture2d<float, access::write>        outTexture [[texture(1)]],
                                          texture1d_array<float, access::sample> histogram  [[texture(2)]],
                                          constant IMPHistogramLayer             &layer     [[buffer(0)]],
                                          uint2 gid [[thread_position_in_grid]])
    {
        
#define IMPHOpacity(bin) (y_position>=bin || y_position<=bin-layer.components[c].width ? 0.0 : 1.0 * component.a)
        
        constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        
        float  width             = float(outTexture.get_width());
        float  height            = float(outTexture.get_height());
        float  x                 = float(gid.x);
        float  y                 = float(gid.y);
        float  y_position        = (height-y);
        
        float  histogramBinPos   = clamp(x/width,0.0,1.0);   // normalize to histogram length
        uint   histogramBinIndex = histogramBinPos * histogram.get_width();
        uint   stride = ceil(float(width/float(histogram.get_width())));
        float  delim = height;
        
        float4 result;
        if (layer.backgroundSource){
            result = inColor;
        }
        else{
            result = layer.backgroundColor;
        }
        
        if ( gid.x % stride > layer.separatorWidth ) {
            for (int c=histogram.get_array_size()-1; c>=0; c--){
                
                float4 component = layer.components[c].color;
                
                half h  = 0;
                
                if (layer.sample)
                    h = histogram.sample(s, histogramBinPos, c).x;
                else
                    h = histogram.read(histogramBinIndex,c).x;
                
                uint   bin       = uint(h*delim); // bin value
                
                float  opacity     = IMPHOpacity(bin);
                
                float4 color     = float4(component.r,component.g,component.b, opacity);
                
                result = IMProcessing::blendNormal(result, color);
            }
        }
        
        outTexture.write(clamp(result,0.0,1.0), gid);
    }
    
    kernel void kernel_histogramLayer(texture2d<float, access::sample>  inTexture   [[texture(0)]],
                                      texture2d<float, access::write>   outTexture  [[texture(1)]],
                                      constant IMPHistogramFloatBuffer  &histogram  [[buffer(0)]],
                                      constant uint                     &channels   [[buffer(1)]],
                                      constant IMPHistogramLayer        &layer      [[buffer(2)]],
                                      uint2 gid [[thread_position_in_grid]])
    {
        
        constexpr uint Im(kIMP_HistogramSize - 1);
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        
        float  width             = float(outTexture.get_width());
        float  height            = float(outTexture.get_height());
        float  x                 = float(gid.x);
        float  y                 = float(gid.y);
        float  y_position        = (height-y);
        
        uint   histogramBinIndex = clamp(uint(x/width*float(Im)),uint(0),Im);   // normalize to histogram length
        float  delim = height;
        
        float4 result;
        if (layer.backgroundSource){
            result = inColor;
        }
        else{
            result = layer.backgroundColor;
        }
        
        for (int c=channels-1; c>=0; c--){
            
            float4 component = layer.components[c].color;
            
            uint   bin       = uint(histogram.channels[c][histogramBinIndex]*delim);   // bin value
            
            float  opacity   = y_position>=bin || y_position<=bin-layer.components[c].width ? 0.0 : 1.0 * component.a;
            
            float4 color     = float4(component.r,component.g,component.b,opacity);
            
            result = IMProcessing::blendNormal(result, color);
        }
        
        outTexture.write(clamp(result,0.0,1.0), gid);
    }
    
    kernel void kernel_paletteLayer(texture2d<float, access::sample>    inTexture   [[texture(0)]],
                                    texture2d<float, access::write>   outTexture  [[texture(1)]],
                                    constant IMPPaletteBuffer        *palette     [[buffer(0)]],
                                    constant uint                     &count      [[buffer(1)]],
                                    constant IMPPaletteLayerBuffer    &layer      [[buffer(2)]],
                                    uint2 gid [[thread_position_in_grid]])
    {
        
        float4 inColor = IMProcessing::sampledColor(inTexture,outTexture,gid);
        
        float  height    = float(outTexture.get_height());
        float  offset    = height/float(count);
        
        float4 result;
        if (layer.backgroundSource){
            result = inColor;
        }
        else{
            result = layer.backgroundColor;
        }
        
        uint index = uint(gid.y/offset);
        
        float4 component = palette[index].color;
        
        result = IMProcessing::blendNormal(result, component);
        
        outTexture.write(clamp(result,0.0,1.0), gid);
    }
}

#endif

#endif

#endif /* IMPHistogramLayer_metal_h */
