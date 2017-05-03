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
//        let L = self[0]*100.0, up = self[1], vp = self[2]
//        var y = (L + 16)/116
//        y = lab_ft_inverse(y)
//        var x = y*9*up / (4*vp)
//        var z = y * (12 - 3*up - 20*vp) / (4*vp)
//        if (!x.isFinite) {x = 0}
//        if (!z.isFinite) {z = 0}
//        
//        return float3(x, y, z)
        return IMPBridg.luv_2_xyz(self) 
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

    
}
