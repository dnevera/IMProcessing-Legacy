//
//  IMPSimdHsl.swift
//  Pods
//
//  Created by denis svinarchuk on 05.05.17.
//
//

import Foundation
import simd

//
// HSL -> RGB, XYZ, LAB/LCH, LUV
//

public extension float3{
    
    public func hsl2rgb() -> float3 {
        return IMPBridge.hsv_2_rgb(self)
    }
    
    public func hsl2ycbcrHD() -> float3 {
        return hsl2rgb().rgb2ycbcrHD()
    }

    public func hsl2lab() -> float3 {
        return hsl2rgb().rgb2lab()
    }
    
    public func hsl2hsv() -> float3 {
        return hsl2rgb().rgb2hsv()
    }
    
    public func hsl2lch() -> float3 {
        return hsl2lab().lab2lch()
    }
    
    public func hsl2xyz() -> float3 {
        return hsl2lab().lab2xyz()
    }
    
    public func hsl2luv() -> float3 {
        return hsl2xyz().xyz2luv()
    }
    
}
