//
//  IMPImageProvider+IMPImage.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public extension IMPExifOrientation{
    init(rawValue:Int){
        self.rawValue = UInt32(rawValue)
    }
}

public extension IMPImageProvider{
    
    public convenience init(context: IMPContext, image: IMPImage, maxSize: Float = 0, orientation: IMPImageOrientation? = nil) {
        self.init(context: context)
        self.update(image: image, maxSize: maxSize, orientation: orientation)
    }
    
    public func update(image image:IMPImage, maxSize: Float = 0, orientation: IMPImageOrientation? = nil){
        #if os(OSX)
            texture = image.newTexture(context, maxSize: maxSize)
        #else 
            if let source = image.newTexture(context, maxSize: maxSize){
                if let orientation = orientation {
                    texture = transform(source, orientation: orientation)
                    self.orientation = orientation
                }
                else {
                    texture = transform(source, orientation: image.imageOrientation)
                    self.orientation = .Up
                }
            }
        #endif
        completeUpdate()
    }
    
    public func writeToJpeg(path:String, compression compressionQ:Float) throws {
        if let t = texture {
            var error:NSError?
            IMPJpegturbo.writeMTLTexture(t, toJpegFile: path, compression: compressionQ.cgfloat, error: &error)
            if error != nil {
                throw error!
            }
        }
    }
    
    public func jpegRepresentation(compression compressionQ:Float) -> NSData? {
        if let t = texture {
            return IMPJpegturbo.dataFromMTLTexture(t, compression: compressionQ.cgfloat)
        }
        else {
            return nil
        }
    }
}