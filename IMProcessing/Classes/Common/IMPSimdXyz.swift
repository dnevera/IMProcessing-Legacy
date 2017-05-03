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
//        let x = self[0], y = self[1], z = self[2]
//        // u' v' and L*
//        var up = 4*x / (x + 15*y + 3*z)
//        var vp = 9*y / (x + 15*y + 3*z)
//        let L = 116*lab_ft_forward(y) - 16
//        if (!up.isFinite) { up = 0 }
//        if (!vp.isFinite) { vp = 0 }
//        
//        return float3(L*0.01, up, vp)
        return  IMPBridg.xyz_2_luv(self)
    }

    public func xyz2rgb() -> float3 {
        let var_X = x / 100.0       //X from 0 to  95.047      (Observer = 2°, Illuminant = D65)
        let var_Y = y / 100.0       //Y from 0 to 100.000
        let var_Z = z / 100.0       //Z from 0 to 108.883
        
        var ccc = float3(1)
        
        ccc.r = var_X *  3.2406 + var_Y * -1.5372 + var_Z * -0.4986
        ccc.g = var_X * -0.9689 + var_Y *  1.8758 + var_Z *  0.0415
        ccc.b = var_X *  0.0557 + var_Y * -0.2040 + var_Z *  1.0570
        
        if ( ccc.r > 0.0031308 ) {ccc.r = 1.055 * pow( ccc.r, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {ccc.r = 12.92 * ccc.r}
        
        if ( ccc.g > 0.0031308 ) {ccc.g = 1.055 * pow( ccc.g, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {ccc.g = 12.92 * ccc.g}
        
        if ( ccc.b > 0.0031308 ) {ccc.b = 1.055 * pow( ccc.b, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {ccc.b = 12.92 * ccc.b}
        
        return ccc
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
    
    public func xyz2lch() -> float3{
        return xyz2lab().lab2lch()
    }
    
    public func xyz2hsv() -> float3 {
        return xyz2rgb().rgb2hsv()
    }
}
