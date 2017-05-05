//
//  IMPHsv.swift
//  Pods
//
//  Created by Denis Svinarchuk on 03/05/2017.
//
//

import Foundation
import simd

//
// HSV -> RGB, XYZ, LAB/LCH, LUV
//

public extension float3{
        
    public func hsv2rgb() -> float3 {
        return IMPBridge.hsv2rgb(self)
    }
    
    public func hsv2hsl() -> float3 {
        return hsv2rgb().rgb2hsl()
    }
    
    public func hsv2ycbcrHD() -> float3 {
        return hsv2rgb().rgb2ycbcrHD()
    }
    
    public func hsv2lab() -> float3 {
        return hsv2rgb().rgb2lab()
    }
    
    public func hsv2lch() -> float3 {
        return hsv2lab().lab2lch()
    }
    
    public func hsv2xyz() -> float3 {
        return hsv2lab().lab2xyz()
    }
    
    public func hsv2luv() -> float3 {
        return hsv2xyz().xyz2luv()
    }

}
