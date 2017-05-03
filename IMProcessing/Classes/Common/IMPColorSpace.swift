//
//  IMPColorSpace.swift
//  Pods
//
//  Created by Denis Svinarchuk on 03/05/2017.
//
//

import Cocoa
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import simd
import Metal

private var __colorSpaceList = [IMPColorSpace]()

public enum IMPColorSpace:String {
    
    public static let rgbIndex = 0
    public static let labIndex = 1
    public static let xyzIndex = 2
    public static let luvIndex = 3
    public static let hsvIndex = 4
    
    case rgb = "RGB"
    case lab = "Lab"
    case xyz = "XYZ"
    case luv = "Luv"
    case hsv = "HSV"
    
    public init(index:Int) {
        switch index {
        case IMPColorSpace.rgbIndex:  self = .rgb
        case IMPColorSpace.labIndex:  self = .lab
        case IMPColorSpace.hsvIndex:  self = .hsv
        case IMPColorSpace.xyzIndex:  self = .xyz
        case IMPColorSpace.luvIndex:  self = .luv
        default:
            self = .rgb
        }
    }
    
    public var index:Int {
        get {
            switch self {
            case .rgb: return IMPColorSpace.rgbIndex
            case .lab: return IMPColorSpace.labIndex
            case .hsv: return IMPColorSpace.hsvIndex
            case .xyz: return IMPColorSpace.xyzIndex
            case .luv: return IMPColorSpace.luvIndex
            }
        }
    }
    
    public static var list:[IMPColorSpace] {
        get{
            if __colorSpaceList.count == 0 {
                for i in 0...4 {
                    __colorSpaceList.append(IMPColorSpace(index: i))
                }
            }
            return __colorSpaceList
        }
    }
    
    public var channelNames: [String] {
        switch self {
        case .rgb: return ["R","G", "B"]
        case .lab: return ["L","a", "b"]
        case .hsv: return ["H","S", "V"]
        case .luv: return ["L","u", "v"]
        case .xyz: return ["X","Y", "Z"]
        }
    }
    
    public var channelColors:[NSColor] {
        switch self {
        case .rgb: return [NSColor.red,    NSColor.green,  NSColor.blue]
        case .lab: return [NSColor.white,  NSColor.orange, NSColor.blue]
        case .hsv: return [NSColor.magenta,NSColor.red,    NSColor.white]
        case .luv: return [NSColor.white,  NSColor.orange, NSColor.blue]
        case .xyz: return [NSColor.red,    NSColor.green,  NSColor.blue]
        }
    }
    
    public var channelRanges:[float2] {
        switch self {
        case .rgb: return [float2(0,1),      float2(0,1),       float2(0,1)]
        case .lab: return [float2(0,100),    float2(-128,127),  float2(-128,127)]  // https://en.wikipedia.org/wiki/Lab_color_space#Range_of_coordinates
        case .hsv: return [float2(0,1),      float2(0,1),       float2(0,1)]
        case .luv: return [float2(0,100),    float2(-134,220),  float2(-140,122)]  // http://cs.haifa.ac.il/hagit/courses/ist/Lectures/Demos/ColorApplet/me/infoluv.html
        case .xyz: return [float2(0,95.047), float2(0,100.000), float2(0,108.883)] // http://www.easyrgb.com/en/math.php#text22
        }
    }
    
    public func from(_ space: IMPColorSpace, value: float3) -> float3 {
        return convert(from: space, to: self, value: value)
    }
    
    public func to(_ space: IMPColorSpace, value: float3) -> float3 {
        return convert(from: self, to: space, value: value)
    }
    
    private func convert(from from_cs:IMPColorSpace, to to_cs:IMPColorSpace, value:float3) -> float3 {
        switch to_cs {
            
        case .rgb:
            switch from_cs {
            case .rgb:
                return value
            case .lab:
                return value.lab2rgb()
            case .hsv:
                return value.hsv2rgb()
            case .xyz:
                return value.xyz2rgb()
            case .luv:
                return value.luv2rgb()
            }
            
        case .lab:
            switch from_cs {
            case .rgb:
                return value.rgb2lab()
            case .lab:
                return value
            case .hsv:
                return value.hsv2lab()
            case .xyz:
                return value.xyz2lab()
            case .luv:
                return value.luv2lab()
            }
            
        case .luv:
            switch from_cs {
            case .rgb:
                return value.rgb2luv()
            case .lab:
                return value.lab2luv()
            case .hsv:
                return value.hsv2luv()
            case .xyz:
                return value.xyz2luv()
            case .luv:
                return value
            }
            
        case .xyz:
            switch from_cs {
            case .rgb:
                return value.rgb2xyz()
            case .lab:
                return value.lab2xyz()
            case .hsv:
                return value.hsv2xyz()
            case .xyz:
                return value
            case .luv:
                return value.luv2xyz()
            }
            
        case .hsv:
            switch from_cs {
            case .rgb:
                return value.rgb2hsv()
            case .lab:
                return value.lab2hsv()
            case .hsv:
                return value
            case .xyz:
                return value.xyz2hsv()
            case .luv:
                return value.luv2hsv()
            }
            
        }
    }
}
