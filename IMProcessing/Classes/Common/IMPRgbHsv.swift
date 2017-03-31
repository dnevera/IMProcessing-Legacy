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

public extension float3{
    
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
    
    public func hsv2rgb() -> float3 {
        let K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        let p = abs(fract(self.xxx + K.xyz) * float3(6.0) - K.www);
        return self.z * mix(K.xxx, clamp(p - K.xxx, min: 0.0, max: 1.0), t: self.y);
    }
}
