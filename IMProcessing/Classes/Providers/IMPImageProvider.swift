//
//  IMPImageProvider.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
    
    public typealias IMPImageOrientation = UIImageOrientation
    
#else
    import Cocoa
    
    public enum IMPImageOrientation : Int {
        case Up             // 0,  default orientation
        case Down           // 1, -> Up    (0), UIImage, 180 deg rotation
        case Left           // 2, -> Right (3), UIImage, 90 deg CCW
        case Right          // 3, -> Down  (1), UIImage, 90 deg CW
        case UpMirrored     // 4, -> Right (3), UIImage, as above but image mirrored along other axis. horizontal flip
        case DownMirrored   // 5, -> Right (3), UIImage, horizontal flip
        case LeftMirrored   // 6, -> Right (3), UIImage, vertical flip
        case RightMirrored  // 7, -> Right (3), UIImage, vertical flip
    }
    
    public typealias UIImageOrientation = IMPImageOrientation
    
#endif

import CoreImage
import simd
import Metal

public extension IMPImageOrientation {
    //
    // Exif codes, F is example
    //
    // 1        2       3      4         5            6           7          8
    //
    // 888888  888888      88  88      8888888888  88                  88  8888888888
    // 88          88      88  88      88  88      88  88          88  88      88  88
    // 8888      8888    8888  8888    88          8888888888  8888888888          88
    // 88          88      88  88
    // 88          88  888888  888888
    
    //                                  EXIF orientation
    //    case Up             // 0, < - (1), default orientation
    //    case Down           // 1, < - (3), UIImage, 180 deg rotation
    //    case Left           // 2, < - (8), UIImage, 90 deg CCW
    //    case Right          // 3, < - (6), UIImage, 90 deg CW
    //    case UpMirrored     // 4, < - (2), UIImage, as above but image mirrored along other axis. horizontal flip
    //    case DownMirrored   // 5, < - (4), UIImage, horizontal flip
    //    case LeftMirrored   // 6, < - (5), UIImage, vertical flip
    //    case RightMirrored  // 7, < - (7), UIImage, vertical flip
    
    init?(exifValue: IMPImageOrientation.RawValue) {
        switch exifValue {
        case 1:
            self.init(rawValue: IMPImageOrientation.up.rawValue)            // IMPExifOrientationUp
        case 2:
            self.init(rawValue: IMPImageOrientation.upMirrored.rawValue)    // IMPExifOrientationHorizontalFlipped
        case 3:
            self.init(rawValue: IMPImageOrientation.down.rawValue)          // IMPExifOrientationLeft180
        case 4:
            self.init(rawValue: IMPImageOrientation.downMirrored.rawValue)  // IMPExifOrientationVerticalFlipped
        case 5:
            self.init(rawValue: IMPImageOrientation.leftMirrored.rawValue)  // IMPExifOrientationLeft90VertcalFlipped
        case 6:
            self.init(rawValue: IMPImageOrientation.right.rawValue)         // IMPExifOrientationLeft90
        case 7:
            self.init(rawValue: IMPImageOrientation.rightMirrored.rawValue) // IMPExifOrientationLeft90HorizontalFlipped
        case 8:
            self.init(rawValue: IMPImageOrientation.left.rawValue)          // IMPExifOrientationRight90
        default:
            self.init(rawValue: IMPImageOrientation.up.rawValue)
        }
    }
}

public extension IMPExifOrientation {
    init?(imageOrientationValue: IMPImageOrientation) {
        switch imageOrientationValue {
        case .up:
            self.init(rawValue: IMPExifOrientationUp.rawValue)
        case .upMirrored:
            self.init(rawValue: IMPExifOrientationHorizontalFlipped.rawValue)
        case .down:
            self.init(rawValue: IMPExifOrientationLeft180.rawValue)
        case .downMirrored:
            self.init(rawValue: IMPExifOrientationVerticalFlipped.rawValue)
        case .leftMirrored:
            self.init(rawValue: IMPExifOrientationLeft90VertcalFlipped.rawValue)
        case .right:
            self.init(rawValue: IMPExifOrientationLeft90.rawValue)
        case .rightMirrored:
            self.init(rawValue: IMPExifOrientationLeft90HorizontalFlipped.rawValue)
        case .left:
            self.init(rawValue: IMPExifOrientationRight90.rawValue)
        }
    }
}

public protocol IMPImageProvider: IMPTextureProvider, IMPContextProvider{
    var image:CIImage?{ get set }
    var colorSpace:CGColorSpace {get set}
    init(context:IMPContext)
}

public extension IMPImageProvider {
    
    public func render(to texture: inout MTLTexture?) {
        
        guard  let image = image else {
            return
        }
        
        let width = Int(image.extent.size.width)
        let height = Int(image.extent.size.height)
        
        if texture?.width != width  || texture?.height != height
        {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: IMProcessing.colors.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            if texture != nil {
                texture?.setPurgeableState(.volatile)
            }
            
            texture = self.context.device.makeTexture(descriptor: descriptor)
        }
        
        if let t = texture {
            context.execute(wait: true) { (commandBuffer) in
                self.context.coreImage?.render(image,
                                               to: t,
                                               commandBuffer: commandBuffer,
                                               bounds: image.extent,
                                               colorSpace: image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
            }
        }
    }
    
//    public var texture: MTLTexture? {
//        mutating get {
//            render(to: &texture)
//            return texture
//        }
//        set {
//            guard let t = newValue else {
//                return
//            }
//            let colorSpace = image?.colorSpace ?? CGColorSpaceCreateDeviceRGB()
//            image = CIImage(mtlTexture: t, options: [kCIImageColorSpace: colorSpace])
//        }
//    }
    
    public var cgiImage:CGImage? {
        get {
            guard let image = image else { return nil }
            return context.coreImage?.createCGImage(image, from: image.extent)
        }
        set {
            let colorSpace = image?.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            if let im = newValue {
                image = CIImage(cgImage: im, options: [kCIImageColorSpace: colorSpace])
            }
        }
    }
    
    public var nsImage:NSImage? {
        get{
            guard (image != nil) else { return nil}
            return NSImage(cgImage: cgiImage!)
        }
        set {
            cgiImage = newValue?.cgImage
        }
    }
}


//class IMPCoreImage: CIImage {
//    
//}
//
//public class IMPImageProvider: IMPTextureProvider, IMPContextProvider {
//    
//    public var orientation = IMPImageOrientation.up
//    
//    public var context:IMPContext
//    public var texture:MTLTexture?
//    public var image:CIImage?
//    
//    public var width:Float {
//        get {
//            guard texture != nil else { return 0 }
//            return texture!.width.float
//        }
//    }
//    
//    public var height:Float {
//        get {
//            guard texture != nil else { return 0 }
//            return texture!.height.float
//        }
//    }
//    
//    public lazy var videoCache:IMPVideoTextureCache = {
//        return IMPVideoTextureCache(context: self.context)
//    }()
//    
//    
//    public required init(context: IMPContext) {
//        self.context = context
//    }
//    
//    public required init(context: IMPContext, orientation:IMPImageOrientation) {
//        self.context = context
//        self.orientation = orientation
//    }
//    
//    public convenience init(context: IMPContext, texture:MTLTexture, orientation:IMPImageOrientation = .up){
//        self.init(context: context)
//        self.texture = texture
//        self.orientation = orientation
//    }
//    
//    required public init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//}
