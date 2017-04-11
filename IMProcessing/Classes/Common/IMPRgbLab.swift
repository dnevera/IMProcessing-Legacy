//
//  IMPRgbLab.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public extension float3{
    
    public func rgb2lab() -> float3 {
        let xyz = rgb2xyz()
        return  xyz.xyz2lab()
    }
    
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
        
    public func xyz2lab() -> float3 {
        
        let xyz = self
        
        var var_X = xyz.x / kIMP_Cielab_X   //   Observer= 2°, Illuminant= D65
        var var_Y = xyz.y / kIMP_Cielab_Y
        var var_Z = xyz.z / kIMP_Cielab_Z
        
        let t1:Float = 1.0/3.0
        let t2:Float = 16.0/116.0
        
        if ( var_X > 0.008856 ) {var_X = pow (var_X, t1)}
        else                    {var_X = ( 7.787 * var_X ) + t2}
        
        if ( var_Y > 0.008856 ) {var_Y = pow(var_Y, t1)}
        else                    {var_Y = ( 7.787 * var_Y ) + t2}
        
        if ( var_Z > 0.008856 ) {var_Z = pow(var_Z, t1)}
        else                    {var_Z = ( 7.787 * var_Z ) + t2}
        
        return float3(( 116.0 * var_Y ) - 16.0, 500.0 * ( var_X - var_Y ), 200.0 * ( var_Y - var_Z ))
    }
    
    public func lab2lch() -> float3 {
        // let l = x
        // let a = y
        // let b = z, lch = xyz
        let c = sqrt(y * y + z * z)
        let h = atan2(z, y) / Float.pi * 180
        return float3(x, c, h)
    }
    
    public func lch2lab() -> float3 {
        // let l = x
        // let c = y
        // let h = z
        let h = z * Float.pi / 180
        return float3(x, cos(h) * y, sin(h) * y)
    }
}
