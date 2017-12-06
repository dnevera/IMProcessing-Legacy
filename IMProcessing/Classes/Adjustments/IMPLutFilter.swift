//
//  IMPLutFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

open class IMPLutFilter: IMPFilter, IMPAdjustmentProtocol {
    open static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1))
    
    open var adjustment:IMPAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout<IMPAdjustment>.size)
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    internal var lut:IMPImageProvider?
    internal var _lutDescription = IMPImageProvider.LutDescription()
    open var lutDescription:IMPImageProvider.LutDescription{
        return _lutDescription
    }
    
    public required init(context: IMPContext, lut:IMPImageProvider, description:IMPImageProvider.LutDescription) {
        
        super.init(context: context)

        update(lut, description: description)
        
        defer{
            self.adjustment = IMPLutFilter.defaultAdjustment
        }
    }
    
    public required init(context: IMPContext) {
        fatalError("init(context:) has not been implemented, IMPLutFilter(context: IMPContext, lut:IMPImageProvider, description:IMPImageProvider.lutDescription) should be used instead...")
    }
    
    open func update(_ lut:IMPImageProvider, description:IMPImageProvider.LutDescription){
        var name = "kernel_adjustLut"
        
        if description.type == .d1D {
            name += "D1D"
        }
        else if description.type == .d3D {
            name += "D3D"
        }
        
        if self._lutDescription.type != description.type  || kernel == nil {
            if kernel != nil {
                self.removeFunction(kernel)
            }
            kernel = IMPFunction(context: self.context, name: name)
            self.addFunction(kernel)
        }
        
        self.lut = lut
        self._lutDescription = description
        
        self.dirty = true
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(lut?.texture, index: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
        }
    }
}
