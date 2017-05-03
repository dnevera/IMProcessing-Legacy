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
        let K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        let p = abs(fract(self.xxx + K.xyz) * float3(6.0) - K.www);
        return self.z * mix(K.xxx, clamp(p - K.xxx, min: 0.0, max: 1.0), t: self.y);
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
