//
//  IMPPerlinNoiseFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 25.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

open class IMPFilmGrainFilter:IMPFilter,IMPAdjustmentProtocol{
    
//    public static let defaultAdjustment = IMPFilmGrainAdjustment(
//        isColored: true,
//        size:  1,
//        amount: IMPFilmGrainColor(total: 1, color: 0.3, luma: 1.0),
//        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    open var adjustment:IMPFilmGrainAdjustment!{
        didSet{

            var times = [Float](repeating: 0, count: 4)
            
            let timer  = UInt32(modf(Date.timeIntervalSinceReferenceDate).0)
            for i in 0 ..< times.count {
                times[i] = Float(arc4random_uniform(timer))/Float(timer)
            }
            
            let size = MemoryLayout<Float>.size*times.count
            timerBuffer = timerBuffer ?? context.device.makeBuffer(length: size, options: MTLResourceOptions())
            memcpy(timerBuffer.contents(), &times, size)

            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout.size(ofValue: adjustment))
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_filmGrain")
        self.addFunction(kernel)
        defer{
            adjustment = IMPFilmGrainAdjustment(
                isColored: true,
                size:  1,
                amount: IMPFilmGrainColor(total: 1, color: 0.3, luma: 1.0),
                blending: IMPBlending(mode: NORMAL, opacity: 1))
        }
    }
    
    var timerBuffer:MTLBuffer!
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
            
            command.setBuffer(timerBuffer, offset: 0, index: 1)
        }
    }
}
