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
    public var texture: MTLTexture?
    public var image: CIImage?
    
    public required init(context: IMPContext) {
        self.context = context
    }
}

public extension IMPImage {
    
    //CMSampleBuffer
    
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
        self.image = prepareImage(image: CIImage(image: image), maxSize: maxSize)
    }
    
    public convenience init(context: IMPContext, image: CGImage, maxSize: CGFloat = 0){
        self.init(context:context)
        self.image = prepareImage(image: CIImage(cgImage: image), maxSize: maxSize)
    }
    
    public convenience init(context: IMPContext, image: CMSampleBuffer, maxSize: CGFloat = 0){
        self.init(context:context)
        self.update(image)
    }
    
    public convenience init(context: IMPContext, image: CVImageBuffer, maxSize: CGFloat = 0){
        self.init(context:context)
        self.update(image)
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
            image = CIImage(cvPixelBuffer: pixelBuffer)
        }
    }

    public func update(_ buffer:CVImageBuffer){
        image = CIImage(cvPixelBuffer: buffer)
    }

    func prepareImage(image originImage: CIImage?, maxSize: CGFloat)  -> CIImage? {
        
        guard let image = originImage else { return originImage }
        
        if maxSize > 0 {
            let size       = image.extent
            let imagesize  = max(size.width, size.height)
            let scale      = min(maxSize/imagesize,1)
            return image.applying(CGAffineTransform(scaleX: scale, y: scale))
        }
        
        return image
    }
}


