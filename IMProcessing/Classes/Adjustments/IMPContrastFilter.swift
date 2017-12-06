//
//  IMPContrastFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

open class IMPContrastFilter:IMPFilter,IMPAdjustmentProtocol{
    
    open static let defaultAdjustment = IMPContrastAdjustment(
        minimum: float4([0,0,0,0]),
        maximum: float4([1,1,1,1]),
        blending: IMPBlending(mode: IMPBlendingMode.LUMNINOSITY, opacity: 1))
    
    open var adjustment:IMPContrastAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout<IMPContrastAdjustment>.size)
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustContrast")
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPContrastFilter.defaultAdjustment
        }
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
        }
    }
}
