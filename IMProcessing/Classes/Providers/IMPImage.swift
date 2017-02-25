//
//  IMPImage.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 12.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa    
#endif

import CoreImage
import simd
import Metal
import AVFoundation


public class IMPImage: IMPImageProvider {
    
    public var context: IMPContext
    
    public var texture: MTLTexture? {
        get{
            if _texture == nil {
                self.render(to: &_texture)
            }
            return _texture
        }
        set{
            _texture = newValue
            _image = nil
        }
    }
    
    public var image: CIImage? {
        set{
            _texture?.setPurgeableState(.empty)
            _texture = nil
            _image = newValue
        }
        get {
            if _image == nil && _texture != nil {
                _image = CIImage(mtlTexture: _texture!, options:  [kCIImageColorSpace: colorSpace])
            }
            return _image
        }
    }
        
    
    public var size: NSSize? {
        get{
            return _image?.extent.size ?? _texture?.cgsize
        }
    }
    
    fileprivate var _image:CIImage? = nil
    fileprivate var _texture:MTLTexture? = nil
    
    public lazy var videoCache:IMPVideoTextureCache = {
        return IMPVideoTextureCache(context: self.context)
    }()
    
    //
    // http://stackoverflow.com/questions/12524623/what-are-the-practical-differences-when-working-with-colors-in-a-linear-vs-a-no
    //
    lazy public var colorSpace:CGColorSpace = {
        if #available(iOS 10.0, *) {
            return  CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    public required init(context: IMPContext) {
        self.context = context
    }
}

public extension IMPImage {
        
    public convenience init(context: IMPContext, provider: IMPImageProvider, maxSize: CGFloat = 0){
        self.init(context:context)
        self.image = prepareImage(image: provider.image?.copy() as? CIImage, maxSize: maxSize)
    }

    public convenience init(context: IMPContext, image: CIImage, maxSize: CGFloat = 0){
        self.init(context:context)
        self.image = prepareImage(image: image.copy() as? CIImage, maxSize: maxSize)
    }

    public convenience init(context: IMPContext, image: NSImage, maxSize: CGFloat = 0){
        self.init(context:context)
        print("IMPImage init image orientation = \(image.imageOrientation.rawValue)")
        self.image = prepareImage(image: CIImage(image: image, options: [kCIImageColorSpace: colorSpace]), maxSize: maxSize)
        //self.image = self.image?.applyingOrientation(Int32(IMPExifOrientationUp.rawValue))
    }
    
    public convenience init(context: IMPContext, image: CGImage, maxSize: CGFloat = 0){
        self.init(context:context)
        self.image = prepareImage(image: CIImage(cgImage: image, options: [kCIImageColorSpace: colorSpace]), maxSize: maxSize)
        //self.image = self.image?.applyingOrientation(Int32(IMPExifOrientationUp.rawValue))
    }
    
    public convenience init(context: IMPContext, image: CMSampleBuffer, maxSize: CGFloat = 0){
        self.init(context:context)
        self.update(image)
    }
    
    public convenience init(context: IMPContext, image: CVImageBuffer, maxSize: CGFloat = 0){
        self.init(context:context)
        self.update(image)
    }

    public convenience init(context: IMPContext, texture: MTLTexture){
        self.init(context:context)
        self.texture = texture
    }

    
    public func update(_ inputImage:CIImage){
        image = inputImage
    }
    
    public func update(_ inputImage:CGImage){
        image = CIImage(cgImage: inputImage)
    }
    
    public func update(_ inputImage:NSImage){
        image = CIImage(image: inputImage)
    }
    
    public func update(_ buffer:CMSampleBuffer){
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            update(pixelBuffer)
        }
    }

    public func update(_ buffer:CVImageBuffer){
        
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

    func prepareImage(image originImage: CIImage?, maxSize: CGFloat)  -> CIImage? {
        
        guard let image = originImage else { return originImage }
        
        if maxSize > 0 {
            let size       = image.extent
            let imagesize  = max(size.width, size.height)
            let scale      = min(maxSize/imagesize,1)
            let transform  = CGAffineTransform(scaleX: scale, y: scale)
            let orientation = image.imageTransform(forOrientation: 1)
            return image.applying(transform).applying(orientation)
        }
        
        return image
    }
}


