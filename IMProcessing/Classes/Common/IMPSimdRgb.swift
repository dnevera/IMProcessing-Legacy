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
        return IMPBridge.rgb_2_xyz(self)
    }
    
    public func rgb2hsv() -> float3 {
        return IMPBridge.rgb_2_hsv(self)
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
