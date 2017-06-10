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
// RGB -> dcproflut, XYZ, LAB/LCH, HSV
//

public extension float3{
    
    public func rgb2xyz() -> float3 {
        return IMPBridge.rgb2xyz(self)
    }
    
    public func rgb2hsv() -> float3 {
        return IMPBridge.rgb2hsv(self)
    }
    
    public func rgb2hsl() -> float3 {
        return IMPBridge.rgb2hsl(self)
    }
    
    public func rgb2hsp() -> float3 {
        return IMPBridge.rgb2hsp(self)
    }

    public func rgb2ycbcrHD() -> float3 {
        return IMPBridge.rgb2ycbcrHD(self)
    }

    public func rgb2dcproflut() ->float3 {
        return IMPBridge.rgb2dcproflut(self)
    }
    
    public func rgb2lab() -> float3 {
        return  IMPBridge.rgb2lab(self)
    }

       public func rgb2lch() -> float3 {
        return IMPBridge.rgb2lch(self)
    }
}
