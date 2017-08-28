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
import ImageIO

open class IMPImage: IMPImageProvider {

    public let storageMode: IMPImageStorageMode
    
    public var orientation = IMPImageOrientation.up

    public var context: IMPContext
    
    public var texture: MTLTexture? {
        set{
            _texture = newValue
            _image = nil
        }
        get{
            if _texture == nil && _image != nil {
                self.render(to: &_texture)
            }
            return _texture
        }
    }
    
    public var image: CIImage? {
        set{
           //_texture?.setPurgeableState(.empty)
            _texture = nil
            _image = newValue
        }
        get {
            if _image == nil && _texture != nil {
                _image = CIImage(mtlTexture: _texture!, options:  [kCIImageColorSpace: colorSpace])
                //if let im = CIImage(mtlTexture: _texture!, options:  [kCIImageColorSpace: colorSpace]){
                    //
                    // convert back to MTL texture coordinates system
                    //
                    //let transform = CGAffineTransform.identity.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: im.extent.height)
                    //_image = im.applying(transform)
                    //_image = im
                //}
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
            return CGColorSpace(name: CGColorSpace.sRGB)!
            //return  CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
            //return  CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    public required init(context: IMPContext, storageMode:IMPImageStorageMode? = .shared) {
        self.context = context
        
        if storageMode != nil {
            self.storageMode = storageMode!
        }
        else {
            self.storageMode = .shared
        }
    }
}
