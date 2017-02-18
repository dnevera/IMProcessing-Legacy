//
//  IMPColor.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import simd
import Metal


#if os(OSX)
let impColorSpace = NSColorSpace.sRGBColorSpace()
#endif

public extension NSColor{
    
    public convenience init(color:float4) {
        self.init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
    }
    public convenience init(rgba:float4) {
        self.init(color:rgba)
    }
    public convenience init(rgb:float3) {
        self.init(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: CGFloat(1))
    }
    public convenience init(red:Float, green:Float, blue:Float) {
        self.init(rgb:float3(red,green,blue))
    }
    #if os(iOS)
    public var rgb:float3{
        get{
            return rgba.xyz
        }
    }
    
    public var rgba:float4{
        get{
            var red:CGFloat   = 0.0
            var green:CGFloat = 0.0
            var blue:CGFloat  = 0.0
            var alpha:CGFloat = 0.0
            getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return float4(red.float,green.float,blue.float,alpha.float)
        }
    }
    #else
    public var rgb:float3{
    get{
    guard let rgba = self.colorUsingColorSpace(impColorSpace) else {
    return float3(0)
    }
    return float3(rgba.redComponent.float,rgba.greenComponent.float,rgba.blueComponent.float)
    }
    }
    
    public var rgba:float4{
    get{
    guard let rgba = self.colorUsingColorSpace(impColorSpace) else {
    return float4(0)
    }
    return float4(rgba.redComponent.float,rgba.greenComponent.float,rgba.blueComponent.float,rgba.alphaComponent.float)
    }
    }
    #endif
    
    public static func * (left:NSColor, right:Float) -> NSColor {
        let rgb = left.rgb
        return NSColor( red: rgb.r*right, green: rgb.g*right, blue: rgb.b*right)
    }
}
