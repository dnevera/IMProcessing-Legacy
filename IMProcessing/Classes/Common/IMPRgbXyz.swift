//
//  IMPRgbXyz.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation


public extension float3{
    
    public func xyz2rgb() -> float3 {
        let var_X = x / 100.0       //X from 0 to  95.047      (Observer = 2°, Illuminant = D65)
        let var_Y = y / 100.0       //Y from 0 to 100.000
        let var_Z = z / 100.0       //Z from 0 to 108.883
        
        var rgb = float3()
        
        rgb.r = var_X *  3.2406 + var_Y * -1.5372 + var_Z * -0.4986
        rgb.g = var_X * -0.9689 + var_Y *  1.8758 + var_Z *  0.0415
        rgb.b = var_X *  0.0557 + var_Y * -0.2040 + var_Z *  1.0570
        
        if ( rgb.r > 0.0031308 ) {rgb.r = 1.055 * pow( rgb.r, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {rgb.r = 12.92 * rgb.r}
        
        if ( rgb.g > 0.0031308 ) {rgb.g = 1.055 * pow( rgb.g, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {rgb.g = 12.92 * rgb.g}
        
        if ( rgb.b > 0.0031308 ) {rgb.b = 1.055 * pow( rgb.b, ( 1.0 / 2.4 ) ) - 0.055}
        else                     {rgb.b = 12.92 * rgb.b}
        
        return rgb
    }
    
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
}
