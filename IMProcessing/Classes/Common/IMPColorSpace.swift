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
        let ranges = Array(Mirror.init(reflecting: kIMP_ColorSpaceRanges).children)[self.index].value as! (float2,float2,float2)
        return [ranges.0, ranges.1, ranges.2]
    }
    
    public func from(_ space: IMPColorSpace, value: float3) -> float3 {
        return convert(from: space, to: self, value: value)
    }
    
    public func to(_ space: IMPColorSpace, value: float3) -> float3 {
        return convert(from: self, to: space, value: value)
    }
    
    private func convert(from from_cs:IMPColorSpace, to to_cs:IMPColorSpace, value:float3) -> float3 {
        return IMPBridge.convert(IMPColorSpaceIndex(rawValue: Int32(from_cs.index)),
                                 to: IMPColorSpaceIndex(rawValue: Int32(to_cs.index)),
                                 value: value)
    }    
}
