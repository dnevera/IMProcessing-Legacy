//
//  IMPSimdYcbcrHD.swift
//  Pods
//
//  Created by denis svinarchuk on 05.05.17.
//
//

import Foundation
import simd
import IMProcessing


//
// YCrCb/HD -> Luv, RGB, LAB/LCH, HSV
//

public extension float3{
    
    public func ycbcrHD2rgb() -> float3 {
        return IMPBridge.ycbcrHD2rgb(self)
    }
    
    public func ycbcrHD2lab() -> float3 {
        return IMPBridge.ycbcrHD2lab(self)
    }
    
    public func ycbcrHD2lch() -> float3 {
        return IMPBridge.ycbcrHD2lch(self)
    }
    
    public func ycbcrHD2xyz() -> float3 {
        return IMPBridge.ycbcrHD2xyz(self)
    }
    
    public func ycbcrHD2luv() -> float3 {
        return IMPBridge.ycbcrHD2luv(self)
    }
    
    public func ycbcrHD2hsv() -> float3 {
        return IMPBridge.ycbcrHD2hsv(self)
    }

    public func ycbcrHD2hsl() -> float3 {
        return IMPBridge.ycbcrHD2hsl(self)
    }
}
