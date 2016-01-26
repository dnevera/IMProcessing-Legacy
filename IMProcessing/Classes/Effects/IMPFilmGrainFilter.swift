//
//  IMPPerlinNoiseFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 25.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

public class IMPFilmGrainFilter:IMPFilter,IMPAdjustmentProtocol{
    
    struct  Times{
        var  time = [Float](count: 8, repeatedValue: 0)
    }

    public static let defaultAdjustment = IMPFilmGrainAdjustment(
        isColored: true,
        size:  1,
        scale: 1,
        amount: IMPFilmGrainColor(total: 1, color: 0.3, luma: 1.0),
        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPFilmGrainAdjustment!{
        didSet{

            var times = [Float](count: 8, repeatedValue: 0)
            
            let timer  = UInt32(modf(NSDate.timeIntervalSinceReferenceDate()).0)
            for var i=0; i < times.count; i++ {
                times[i] = Float(arc4random_uniform(timer))/Float(timer)
            }
            
            let size = sizeof(Float)*times.count
            timerBuffer = timerBuffer ?? context.device.newBufferWithLength(size, options: .CPUCacheModeDefaultCache)
            memcpy(timerBuffer.contents(), &times, size)

            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeofValue(adjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_perlinNoise")
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPFilmGrainFilter.defaultAdjustment
        }
    }
    
    var timerBuffer:MTLBuffer!
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
            
            command.setBuffer(timerBuffer, offset: 0, atIndex: 1)
        }
    }
}