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
        //let h = z * Float.pi / 180
        //return float3(x, cos(h) * y, sin(h) * y)
        return IMPBridge.lch_2_lab(self)
    }
    
    public func lch2rgb() -> float3 {
        return lch2lab().lab2rgb()
    }
    
    public func lch2hsv() -> float3 {
        return lch2rgb().rgb2hsv()
    }

    public func lch2hsl() -> float3 {
        return lch2rgb().rgb2hsl()
    }
    public func lch2luv() -> float3 {
        return lch2xyz().xyz2luv()
    }

    public func lch2xyz() -> float3 {
        return lch2lab().lab2xyz()
    }
    
    public func lch2ycbcrHD() -> float3 {
        return lch2rgb().rgb2ycbcrHD()
    }
}
