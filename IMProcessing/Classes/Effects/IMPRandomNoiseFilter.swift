//
//  IMPNoiseFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 25.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

open class IMPRandomNoiseFilter:IMPFilter,IMPAdjustmentProtocol{
    
    open static let defaultAdjustment = IMPLevelAdjustment(
        level: 1,
        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    open var adjustment:IMPLevelAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout.size(ofValue: adjustment))
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_randomNoise")
        self.addFunction(kernel)
        timerBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: MTLResourceOptions())
        defer{
            self.adjustment = IMPRandomNoiseFilter.defaultAdjustment
        }
    }    
    
    var timerBuffer:MTLBuffer!
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            let timer  = UInt32(modf(Date.timeIntervalSinceReferenceDate).0)
            var rand = Float(arc4random_uniform(timer))/Float(timer)
            memcpy(timerBuffer.contents(), &rand, MemoryLayout<Float>.size)
            command.setBuffer(adjustmentBuffer, offset: 0, at: 0)
            command.setBuffer(timerBuffer, offset: 0, at: 1)
        }
    }
}
