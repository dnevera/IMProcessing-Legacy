//
//  IMPWBFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

/// White balance correction filter
open class IMPWBFilter:IMPFilter,IMPAdjustmentProtocol{
    
    /// Default WB adjustment
    open static let defaultAdjustment = IMPWBAdjustment(
        ///  @brief default dominant color of the image
        ///
        dominantColor: float4([0.5, 0.5, 0.5, 0.5]),
        ///  @brief Blending mode and opacity
        ///
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
    )
    
    /// Adjust filter
    open var adjustment:IMPWBAdjustment!{
        didSet{
            updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout<IMPWBAdjustment>.size)
            dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    ///  Create WB filter.
    ///
    ///  - parameter context: device context
    ///
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustWB")
        addFunction(kernel)
        defer{
            adjustment = IMPWBFilter.defaultAdjustment
        }
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, at: 0)
        }
    }
}
