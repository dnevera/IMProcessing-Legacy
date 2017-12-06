//
//  IMPSaturationFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 24.02.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

/// Image saturation filter
open class IMPSaturationFilter:IMPFilter,IMPAdjustmentProtocol{
    
    /// Saturation adjustment.
    /// Default level is 0.5. Level values must be within interval [0,1].
    ///
    open var adjustment:IMPLevelAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout<IMPLevelAdjustment>.size)
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    ///  Create image saturation filter.
    ///
    ///  - parameter context: device context
    ///
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustSaturation")
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPLevelAdjustment(
                level: 0.5,
                blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
            )
        }
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
        }
    }
}
