//
//  IMPRgbLab.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import simd

//
// luv sources: https://www.ludd.ltu.se/~torger/dcamprof.html
//

public func lab_ft_forward(_ t:Float) -> Float
{
    if (t >= 8.85645167903563082e-3) {
        return pow(t, 1.0/3.0)
    } else {
        return t * (841.0/108.0) + 4.0/29.0
    }
}

public func lab_ft_inverse(_ t:Float) -> Float
{
    if (t >= 0.206896551724137931) {
        return t*t*t
    } else {
        return 108.0 / 841.0 * (t - 4.0/29.0)
    }
}


//
// LAB -> RGB, XYZ, LCH, LUV, HSV
//

public extension float3{
    
      public func lab2rgb() -> float3 {
        let xyz = lab2xyz()
        return  xyz.xyz2rgb()
    }
    
    public func lab2xyz() -> float3 {
        
        let lab = self
        var xyz = float3()
        
        xyz.y = ( lab.x + 16.0 ) / 116.0
        xyz.x = lab.y / 500.0 + xyz.y
        xyz.z = xyz.y - lab.z / 200.0
        
        if ( pow(xyz.y,3.0) > 0.008856 ) {xyz.y = pow(xyz.y,3.0)}
        else                             {xyz.y = ( xyz.y - 16.0 / 116.0 ) / 7.787}
        
        if ( pow(xyz.x,3.0) > 0.008856 ) {xyz.x = pow(xyz.x,3.0)}
        else                             {xyz.x = ( xyz.x - 16.0 / 116.0 ) / 7.787}
        
        if ( pow(xyz.z,3.0) > 0.008856 ) {xyz.z = pow(xyz.z,3.0)}
        else                             {xyz.z = ( xyz.z - 16.0 / 116.0 ) / 7.787}
        
        xyz.x *= kIMP_Cielab_X    //     Observer= 2°, Illuminant= D65
        xyz.y *= kIMP_Cielab_Y
        xyz.z *= kIMP_Cielab_Z
        
        return xyz
    }
            
    public func lab2lch() -> float3 {
        // let l = x
        // let a = y
        // let b = z, lch = xyz

        var h = atan2(z, y)
        if h > 0  { h = ( h / Float.pi ) * 180 }
        else      { h = 360 - ( abs( h ) / Float.pi ) * 180}

        let c = sqrt(y * y + z * z)

        return float3(x, c, h)
    }
    
    public func lab2luv() -> float3 {
        return lab2xyz().xyz2luv()
    }

    public func lab2hsv() -> float3 {
        return lab2rgb().rgb2hsv()
    }
}
