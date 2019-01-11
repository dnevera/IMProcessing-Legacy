//
//  IMProcessing.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import simd
import Metal

public enum IMProcessing{
    
    public struct meta {
        
        public static let version                  = 2.0
        public static let versionKey               = "IMProcessingVersion"
        public static let imageOrientationKey      = "Orientation"
        public static let deviceOrientationKey     = "DeviceOrientation"
        public static let imageSourceExposureMode  = "SourceExposureMode"
        public static let imageSourceFocusMode     = "SourceFocusMode"
    }
    
    public struct colorSpace {
        #if os(OSX)
//        if #available(iOS 10.0, *) {
//        //return CGColorSpace(name: CGColorSpace.sRGB)!
//        //return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
//        //return CGColorSpace(name: CGColorSpace.genericRGBLinear)!
//        }
//        else {
//        fatalError("extendedLinearSRGB: ios >10.0 supports only")
//        }

        public static let cgColorSpace =  CGColorSpaceCreateDeviceRGB()
        public static let srgb = NSColorSpace.sRGB
        #endif
    }
    
    public struct names {
        public static let prefix = "com.improcessing."
    }
    
    public struct colors {
        #if os(iOS)
        public static let pixelFormat = MTLPixelFormat.rgba8Unorm
        #else
        public static let pixelFormat = MTLPixelFormat.rgba16Unorm
        //public static let pixelFormat = MTLPixelFormat.rgba8Unorm
        #endif
    }
}


public func addressOf<T: AnyObject>(o: T?) -> Int? {
    return o == nil ? nil : unsafeBitCast(o, to: Int.self)
}
