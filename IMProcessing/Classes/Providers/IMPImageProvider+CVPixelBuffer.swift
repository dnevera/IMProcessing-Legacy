//
//  IMPImageProvider+CVPixelBuffer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 04.03.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMedia
import Metal

public extension IMPImageProvider{
    
    public convenience init(context: IMPContext, pixelBuffer: CVPixelBuffer) {
        self.init(context: context)
        #if os(iOS)
            //
            // Pixelbuffer from camera always is Left
            //
            orientation = .left
        #endif
        update(pixelBuffer: pixelBuffer)
    }
    
    public func update(pixelBuffer:CVPixelBuffer) {
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let textureRef = UnsafeMutablePointer<CVMetalTexture?>.allocate(capacity: 1)
        
        let error = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoCache.reference!, pixelBuffer, nil, .bgra8Unorm, width, height, 0, textureRef)
        
        if error != kCVReturnSuccess {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
        
        if let ref = textureRef.pointee {
            
            if let t = CVMetalTextureGetTexture(ref) {
                texture = t
            }
            else {
                fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
            }
            
        }
    }
}
