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
    
    public struct names {
        public static let prefix = "com.improcessing."
    }
    
    public struct colors {
        #if os(iOS)
        public static let pixelFormat = MTLPixelFormat.rgba8Unorm
        #else
        public static let pixelFormat = MTLPixelFormat.rgba16Unorm
        #endif
    }
}
