//
//  IMPSimdRgb.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import simd

func IMPstep(_ edge:Float, _ x:Float) -> Float {
    return step(x, edge: edge)
}

//
// RGB -> Luv, XYZ, LAB/LCH, HSV
//

public extension float3{
    
    public func rgb2xyz() -> float3 {
        var r = self.r
        var g = self.g
        var b = self.b
        
        
        if ( r > 0.04045 ) {r = pow((( r + 0.055) / 1.055 ), 2.4)}
        else               {r = r / 12.92}
        
        if ( g > 0.04045 ) {g = pow((( g + 0.055) / 1.055 ), 2.4)}
        else               {g = g / 12.92}
        
        if ( b > 0.04045 ) {b = pow((( b + 0.055) / 1.055 ), 2.4)}
        else               {b = b / 12.92}
        
        var xyz = float3()
        
        xyz.x = r * 41.24 + g * 35.76 + b * 18.05;
        xyz.y = r * 21.26 + g * 71.52 + b * 7.22;
        xyz.z = r * 1.93  + g * 11.92 + b * 95.05;
        
        return xyz
    }
    
    public func rgb2hsv() -> float3 {
        let K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0)
        let p = mix(float4(self.bg, K.wz),
                    float4(self.gb, K.xy),
                    t: IMPstep(self.b, self.g))
        let q = mix(float4(rgb: p.xyw, a: self.r), float4(self.r, p.yzx), t: IMPstep(p.x, self.r))
        
        let e = Float(1.0e-10)
        let d = q.x - min(q.w, q.y)
        return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x)
    }
    

    public func rgb2luv() ->float3 {
        return rgb2xyz().xyz2luv()
    }
    
    public func rgb2lab() -> float3 {
        return  rgb2xyz().xyz2lab()
    }

       public func rgb2lch() -> float3 {
        return rgb2lab().lab2lch()
    }
}
