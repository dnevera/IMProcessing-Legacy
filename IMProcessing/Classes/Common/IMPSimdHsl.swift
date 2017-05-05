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
        return IMPBridge.hsl2rgb(self)
    }
    
    public func hsl2ycbcrHD() -> float3 {
        return IMPBridge.hsl2ycbcrHD(self)
    }

    public func hsl2lab() -> float3 {
        return IMPBridge.hsl2lab(self)
    }
    
    public func hsl2hsv() -> float3 {
        return IMPBridge.hsl2hsv(self)
    }
    
    public func hsl2lch() -> float3 {
        return IMPBridge.hsl2lch(self)
    }
    
    public func hsl2xyz() -> float3 {
        return IMPBridge.hsl2xyz(self)
    }
    
    public func hsl2luv() -> float3 {
        return IMPBridge.hsl2luv(self)
    }
    
}
