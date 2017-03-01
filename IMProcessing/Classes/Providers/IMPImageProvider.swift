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
import AVFoundation
import ImageIO


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

public enum IMPImageStorageMode {
    case shared
    case local
}

public protocol IMPImageProvider: IMPTextureProvider, IMPContextProvider{    
    var image:CIImage?{ get set }
    var size:NSSize? {get}
    var colorSpace:CGColorSpace {get set}
    var orientation:IMPImageOrientation {get set}
    var videoCache:IMPVideoTextureCache {get}
    var storageMode:IMPImageStorageMode {get}
    init(context:IMPContext, storageMode:IMPImageStorageMode?)
}

public extension IMPImageProvider {
    
    public init(context: IMPContext,
                provider: IMPImageProvider,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: provider.image?.copy() as? CIImage,
                                  maxSize: maxSize, orientation: orientation)
    }
    
    public init(context: IMPContext,
                image: CIImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: image.copy() as? CIImage,
                                  maxSize: maxSize, orientation: orientation)
    }
    
    
    public init(context: IMPContext,
                image: NSImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: CIImage(cgImage: image.cgImage!, options: [kCIImageColorSpace: colorSpace]),
                                  maxSize: maxSize, orientation: orientation ?? image.imageOrientation)
    }
    
    public init(context: IMPContext,
                image: CGImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: CIImage(cgImage: image, options: [kCIImageColorSpace: colorSpace]),
                                  maxSize: maxSize, orientation: orientation)
    }
    
    public init(context: IMPContext, image: CMSampleBuffer, storageMode:IMPImageStorageMode? = .local, maxSize: CGFloat = 0){
        self.init(context:context, storageMode: storageMode)
        self.update(image)
    }
    
    public init(context: IMPContext, image: CVImageBuffer, storageMode:IMPImageStorageMode? = .local, maxSize: CGFloat = 0){
        self.init(context:context, storageMode: storageMode)
        self.update(image)
    }
    
    public init(context: IMPContext, texture: MTLTexture){
        var mode = IMPImageStorageMode.shared
        if texture.storageMode == .private {
            mode = .local
        }
        self.init(context:context, storageMode:mode)
        self.texture = texture
    }
    
    
    public mutating func update(_ inputImage:CIImage){
        image = inputImage
    }
    
    public mutating func update(_ inputImage:CGImage){
        image = CIImage(cgImage: inputImage)
    }
    
    public mutating func update(_ inputImage:NSImage){
        image = CIImage(image: inputImage)
    }
    
    public mutating func update(_ buffer:CMSampleBuffer){
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
            update(pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        }
    }
    
    public mutating func update(_ buffer: CVImageBuffer) {
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var textureRef:CVMetalTexture?
        
        guard let vcache = videoCache.videoTextureCache else {
            fatalError("IMPImageProvider error: couldn't create video cache... )")
        }
        
        let error = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              vcache,
                                                              buffer, nil,
                                                              .bgra8Unorm,
                                                              width,
                                                              height,
                                                              0,
                                                              &textureRef)
        
        if error != kCVReturnSuccess {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
        
        if let ref = textureRef,
            let texture = CVMetalTextureGetTexture(ref) {
            self.texture = texture
        }
        else {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
    }
    
    mutating private func prepareImage(image originImage: CIImage?, maxSize: CGFloat, orientation:IMPImageOrientation? = nil)  -> CIImage? {
        
        guard let image = originImage else { return originImage }
        
        let size       = image.extent
        let imagesize  = max(size.width, size.height)
        let scale      = maxSize > 0 ? min(maxSize/imagesize,1) : 1
        
        var transform  = scale == 1 ? CGAffineTransform.identity : CGAffineTransform(scaleX: scale, y: scale)
        
        var reflectHorisontalMode = false
        var reflectVerticalMode = false
        var angle:CGFloat = 0
        
        
        if let orientation = orientation {
            
            self.orientation = orientation
            
            //
            // CIImage render to verticaly mirrored texture
            //
            
            switch orientation {
                
            case .up:
                angle = CGFloat.pi
                reflectHorisontalMode = true // 0
                
            case .upMirrored:
                reflectHorisontalMode = true
                reflectVerticalMode   = true // 4
                
            case .down:
                reflectHorisontalMode = true // 1
                
            case .downMirrored: break        // 5
                
            case .left:
                angle = -CGFloat.pi/2
                reflectHorisontalMode = true // 2
                
            case .leftMirrored:
                angle = -CGFloat.pi/2
                reflectVerticalMode   = true
                reflectHorisontalMode = true // 6
                
            case .right:
                angle = CGFloat.pi/2
                reflectHorisontalMode = true // 3
                
            case .rightMirrored:
                angle = CGFloat.pi/2
                reflectVerticalMode   = true
                reflectHorisontalMode = true // 7
            }
        }
        
        if reflectHorisontalMode {
            transform = transform.scaledBy(x: -1, y: 1).translatedBy(x: size.width, y: 0)
        }
        
        if reflectVerticalMode {
            transform = transform.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: size.height)
        }
        
        //
        // fix orientation
        //
        transform = transform.rotated(by: CGFloat(angle))
        
        return image.applying(transform)
    }
}


public extension IMPImageProvider {
    
    public func render(to texture: inout MTLTexture?) {
        
        guard  let image = image else { return }
        
        texture = checkTexture(texture: texture)
        
        if let t = texture {
            context.execute(wait: true) { (commandBuffer) in
                
                self.context.coreImage?.render(image,
                                               to: t,
                                               commandBuffer: commandBuffer,
                                               bounds: image.extent,
                                               colorSpace: self.colorSpace)
            }
        }
    }
    
    public func render(to texture: inout MTLTexture?, with commandBuffer: MTLCommandBuffer) {
        
        guard  let image = image else {  return }
        
        texture = checkTexture(texture: texture)
        
        if let t = texture {
            self.context.coreImage?.render(image,
                                           to: t,
                                           commandBuffer: commandBuffer,
                                           bounds: image.extent,
                                           colorSpace: self.colorSpace)
        }
    }
    
    
    private func checkTexture(texture:MTLTexture?) -> MTLTexture? {
        
        guard  let image = image else {  return nil }
        
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
            
            if storageMode == .shared {
                descriptor.storageMode = .shared
                descriptor.usage = [.shaderRead, .shaderWrite]
            }
            else {
                descriptor.storageMode = .private
                descriptor.usage = [.shaderRead]
            }

            return self.context.device.makeTexture(descriptor: descriptor)
        }
        
        return texture
    }
    
    public var cgiImage:CGImage? {
        get {
            guard let image = image else { return nil }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            return context.coreImage?.createCGImage(image, from: image.extent,
                                                    format: kCIFormatARGB8,
                                                    colorSpace: colorSpace,
                                                    deferred:true)
        }
        set {
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


