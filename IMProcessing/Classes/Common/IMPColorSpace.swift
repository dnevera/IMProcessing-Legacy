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
    
    public static let rgbIndex = Int(IMPRgbSpace.rawValue)
    public static let labIndex = Int(IMPLabSpace.rawValue)
    public static let lchIndex = Int(IMPLchSpace.rawValue)
    public static let xyzIndex = Int(IMPXyzSpace.rawValue)
    public static let luvIndex = Int(IMPLuvSpace.rawValue)
    public static let hsvIndex = Int(IMPHsvSpace.rawValue)
    public static let hslIndex = Int(IMPHslSpace.rawValue)
    public static let ycbcrHDIndex = Int(IMPYcbcrHDSpace.rawValue)
    
    public static let spacesCount = 7
    
    case rgb = "RGB"
    case lab = "L*a*b"
    case lch = "L*c*h"
    case xyz = "XYZ"
    case luv = "Luv"
    case hsv = "HSV"
    case hsl = "HSL"
    case ycbcrHD = "YCbCr/HD"
    
    public init(index:Int) {
        switch index {
        case IMPColorSpace.rgbIndex:  self = .rgb  // 0
        case IMPColorSpace.labIndex:  self = .lab
        case IMPColorSpace.lchIndex:  self = .lch
        case IMPColorSpace.hsvIndex:  self = .hsv
        case IMPColorSpace.hslIndex:  self = .hsl
        case IMPColorSpace.xyzIndex:  self = .xyz
        case IMPColorSpace.luvIndex:  self = .luv
        case IMPColorSpace.ycbcrHDIndex:  self = .ycbcrHD
        default:
            self = .rgb
        }
    }
    
    public var index:Int {
        get {
            switch self {
            case .rgb: return IMPColorSpace.rgbIndex
            case .lab: return IMPColorSpace.labIndex
            case .lch: return IMPColorSpace.lchIndex
            case .hsv: return IMPColorSpace.hsvIndex
            case .hsl: return IMPColorSpace.hslIndex
            case .xyz: return IMPColorSpace.xyzIndex
            case .luv: return IMPColorSpace.luvIndex
            case .ycbcrHD: return IMPColorSpace.ycbcrHDIndex
            }
        }
    }
    
    public static var list:[IMPColorSpace] {
        get{
            if __colorSpaceList.count == 0 {
                for i in 0...IMPColorSpace.spacesCount {
                    __colorSpaceList.append(IMPColorSpace(index: i))
                }
            }
            return __colorSpaceList
        }
    }
    
    public var channelNames: [String] {
        switch self {
        case .rgb: return ["R","G", "B"]
        case .lab: return ["L*","a*", "b*"]
        case .lch: return ["L*","c*", "h"]
        case .hsv: return ["H","S", "V"]
        case .hsl: return ["H","S", "L"]
        case .luv: return ["L","u", "v"]
        case .xyz: return ["X","Y", "Z"]
        case .ycbcrHD: return ["Y","Cb", "Cr"]
        }
    }
    
    public var channelColors:[NSColor] {
        switch self {
        case .rgb: return [NSColor.red,    NSColor.green,  NSColor.blue]
        case .lab: return [NSColor.white,  NSColor.orange, NSColor.blue]
        case .lch: return [NSColor.white,  NSColor.orange, NSColor.blue]
        case .hsv: return [NSColor.magenta,NSColor.red,    NSColor.white]
        case .hsl: return [NSColor.magenta,NSColor.red,    NSColor.white]
        case .luv: return [NSColor.white,  NSColor.orange, NSColor.blue]
        case .xyz: return [NSColor.red,    NSColor.green,  NSColor.blue]
        case .ycbcrHD: return [NSColor.red,NSColor.green,  NSColor.blue]
        }
    }
    
    public var channelRanges:[float2] {
        switch self {
        case .rgb: return [float2(0,1),       float2(0,1),       float2(0,1)]
        case .lab: return [float2(0,100),     float2(-128,127),  float2(-128,127)]  // https://en.wikipedia.org/wiki/Lab_color_space#Range_of_coordinates
        case .lch: return [float2(0,100),     float2(0,200),     float2(0,360)]
        case .hsv: return [float2(0,1),       float2(0,1),       float2(0,1)]
        case .hsl: return [float2(0,1),       float2(0,1),       float2(0,1)]
        case .luv: return [float2(0,100),     float2(-134,220),  float2(-140,122)]  // http://cs.haifa.ac.il/hagit/courses/ist/Lectures/Demos/ColorApplet/me/infoluv.html
        case .xyz: return [float2(0,95.047),  float2(0,100.000), float2(0,108.883)] // http://www.easyrgb.com/en/math.php#text22
        case .ycbcrHD: return [float2(0,255), float2(0,255),     float2(0,255)]     // http://www.equasys.de/colorconversion.html
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
            case .lch:
                return value.lch2rgb()
            case .hsv:
                return value.hsv2rgb()
            case .hsl:
                return value.hsl2rgb()
            case .xyz:
                return value.xyz2rgb()
            case .luv:
                return value.luv2rgb()
            case .ycbcrHD:
                return value.ycbcrHD2rgb()
            }
            
        case .lab:
            switch from_cs {
            case .rgb:
                return value.rgb2lab()
            case .lab:
                return value
            case .lch:
                return value.lch2lab()
            case .hsv:
                return value.hsv2lab()
            case .hsl:
                return value.hsl2lab()
            case .xyz:
                return value.xyz2lab()
            case .luv:
                return value.luv2lab()
            case .ycbcrHD:
                return value.ycbcrHD2lab()
            }
            
        case .luv:
            switch from_cs {
            case .rgb:
                return value.rgb2luv()
            case .lab:
                return value.lab2luv()
            case .lch:
                return value.lch2luv()
            case .hsv:
                return value.hsv2luv()
            case .hsl:
                return value.hsl2luv()
            case .xyz:
                return value.xyz2luv()
            case .luv:
                return value
            case .ycbcrHD:
                return value.ycbcrHD2luv()
            }
            
        case .xyz:
            switch from_cs {
            case .rgb:
                return value.rgb2xyz()
            case .lab:
                return value.lab2xyz()
            case .lch:
                return value.lch2xyz()
            case .hsv:
                return value.hsv2xyz()
            case .hsl:
                return value.hsl2xyz()
            case .xyz:
                return value
            case .luv:
                return value.luv2xyz()
            case .ycbcrHD:
                return value.ycbcrHD2xyz()
            }
            
        case .hsv:
            switch from_cs {
            case .rgb:
                return value.rgb2hsv()
            case .lab:
                return value.lab2hsv()
            case .lch:
                return value.lch2hsv()
            case .hsv:
                return value
            case .hsl:
                return value.hsl2hsv()
            case .xyz:
                return value.xyz2hsv()
            case .luv:
                return value.luv2hsv()
            case .ycbcrHD:
                return value.ycbcrHD2hsv()
            }
  
        case .hsl:
            switch from_cs {
            case .rgb:
                return value.rgb2hsl()
            case .lab:
                return value.lab2hsl()
            case .lch:
                return value.lch2hsl()
            case .hsv:
                return value.hsv2hsl()
            case .hsl:
                return value
            case .xyz:
                return value.xyz2hsl()
            case .luv:
                return value.luv2hsl()
            case .ycbcrHD:
                return value.ycbcrHD2hsl()
            }
            
        case .lch:
            switch from_cs {
            case .rgb:
                return value.rgb2lch()
            case .lab:
                return value.lab2lch()
            case .lch:
                return value
            case .hsv:
                return value.hsv2lch()
            case .hsl:
                return value.hsl2lch()
            case .xyz:
                return value.xyz2lch()
            case .luv:
                return value.luv2lch()
            case .ycbcrHD:
                return value.ycbcrHD2lch()
            }
            
        case .ycbcrHD:
            switch from_cs {
            case .rgb:
                return value.rgb2ycbcrHD()
            case .lab:
                return value.lab2ycbcrHD()
            case .lch:
                return value.lch2ycbcrHD()
            case .hsv:
                return value.hsv2ycbcrHD()
            case .hsl:
                return value.hsl2ycbcrHD()
            case .xyz:
                return value.xzy2ycbcrHD()
            case .luv:
                return value.luv2ycbcrHD()
            case .ycbcrHD:
                return value
            }
        }
    }
}
