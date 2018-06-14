//
//  IMPImageProvider+JpegTurbo.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 21.05.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation

open class IMPJpegProvider:IMPImageProvider{

    public convenience init(context: IMPContext, file: String, maxSize: Float = 0, orientation:IMPExifOrientation = IMPExifOrientation.up) throws {
        self.init(context: context)
        try self.updateFromJpeg(file: file, maxSize: maxSize, orientation: orientation)
    }
    
    
    open func updateFromJpeg(file:String, maxSize: Float = 0, orientation:IMPExifOrientation = IMPExifOrientation.up) throws {
        let source = try IMPJpegturbo.update(texture,
                                                    with: IMProcessing.colors.pixelFormat,
                                                    with: context.device,
                                                    fromFile: file,
                                                    maxSize: maxSize.cgfloat
        )
        
        texture = transform(source, orientation: orientation)
        
        self.orientation = .up
        
        completeUpdate()
    }
    
 }
