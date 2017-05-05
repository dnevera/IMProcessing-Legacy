//
//  IMPSimdLuv.swift
//  Pods
//
//  Created by Denis Svinarchuk on 03/05/2017.
//
//

import Foundation
import simd
import IMProcessing

//
// luv sources: https://www.ludd.ltu.se/~torger/dcamprof.html
//

//
// Luv -> RGB, XYZ, LAB/LCH, HSV
//
public extension float3{
    
    public var L:Float { set{ x = newValue } get{ return x } }
    public var u:Float { set{ y = newValue } get{ return y } }
    public var v:Float { set{ z = newValue } get{ return z } }
    
    public func luv2xyz() -> float3
    {
        return IMPBridge.luv_2_xyz(self) 
    }
    
    public func luv2rgb() -> float3 {
        return luv2xyz().xyz2rgb()
    }
    
    public func luv2lab() -> float3 {
        return luv2xyz().xyz2lab()
    }

    public func luv2lch() -> float3 {
        return luv2xyz().luv2lch()
    }

    public func luv2hsv() -> float3 {
        return luv2xyz().xyz2hsv()
    }

    public func luv2hsl() -> float3 {
        return luv2xyz().xyz2hsl()
    }
    public func luv2ycbcrHD() -> float3 {
        return luv2rgb().rgb2ycbcrHD()
    }
    
}
