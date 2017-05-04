//
//  IMPRgbXyz.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import simd
import IMProcessing


//
// XYZ -> Luv, RGB, LAB/LCH, HSV
//

public extension float3{
    
    //
    // luv sources: https://www.ludd.ltu.se/~torger/dcamprof.html
    //

    public func xyz2luv() ->float3 {
        return  IMPBridge.xyz_2_luv(self)
    }

    public func xyz2rgb() -> float3 {
        return IMPBridge.xyz_2_rgb(self)
    }
    
    public func xyz2lab() -> float3 {        
        return IMPBridge.xyz_2_lab(self)
        
    }
    
    public func xyz2lch() -> float3{
        return xyz2lab().lab2lch()
    }
    
    public func xyz2hsv() -> float3 {
        return xyz2rgb().rgb2hsv()
    }
}
