//
//  IMPSimdLch.swift
//  Pods
//
//  Created by Denis Svinarchuk on 03/05/2017.
//
//

import Foundation
import simd

// LCH -> RGB, XYZ, LAB, LUV, HSV

public extension float3{
        
    public func lch2lab() -> float3 {
        // let l = x
        // let c = y
        // let h = z
        return IMPBridge.lch2lab(self)
    }
    
    public func lch2rgb() -> float3 {
        return IMPBridge.lch2rgb(self)
    }
    
    public func lch2hsv() -> float3 {
        return IMPBridge.lch2hsv(self)
    }

    public func lch2hsl() -> float3 {
        return IMPBridge.lch2hsl(self)
    }
    public func lch2luv() -> float3 {
        return IMPBridge.lch2luv(self)
    }

    public func lch2xyz() -> float3 {
        return IMPBridge.lch2xyz(self)
    }
    
    public func lch2ycbcrHD() -> float3 {
        return IMPBridge.lch2ycbcrHD(self)
    }
}
