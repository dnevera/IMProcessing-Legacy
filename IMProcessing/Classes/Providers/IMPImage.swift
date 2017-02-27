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

public class IMPImage: IMPImageProvider {

    public var orientation = IMPImageOrientation.up

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
