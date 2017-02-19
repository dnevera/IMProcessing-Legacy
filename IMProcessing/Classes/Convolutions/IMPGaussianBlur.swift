//
//  IMPGaussianBlur.swift
//  Pods
//
//  Created by denis svinarchuk on 18.02.17.
//
//

import Foundation
import Accelerate
import simd

public class IMPGaussianBlurFilter: IMPFilter {
    
    public static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            adjustmentBuffer = adjustmentBuffer ?? context.device.makeBuffer(length: MemoryLayout.size(ofValue: adjustment), options: [])
            memcpy(adjustmentBuffer.contents(), &adjustment, adjustmentBuffer.length)
            dirty = true
        }
    }

    public var radiusLimit:Float = 8 {
        didSet{
            update()
            dirty = true
        }
    }
    
    public var radius:Int!{
        didSet{
            update()
            dirty = true
        }
    }
    
    public override func configure(_ withName: String?) {
        self.name = "IMPGaussianBlurFilter"
        adjustment = IMPGaussianBlurFilter.defaultAdjustment
        radius = 0
    }
  
    var sigma:Float {
        get {
            return radiusLimit
        }
    }
    
    var downsamplingFactor:Float {
        return round(Float(radius)) / radiusLimit
    }
    
    var adjustmentBuffer:MTLBuffer!
    var empty = true
    func update(){
        let kernel: [Float] = radius.gaussianKernel
        let inputs: [Float] = kernel.gaussianInputs
        
        let weights:[Float] = inputs.gaussianWeights
        let offsets:[Float] = inputs.gaussianOffsets(weights: weights)
        
        if weights.count>0{
            if empty {
                empty = false
                add(function: horizontal_pass_kernel)
                add(function: vertical_pass_kernel)
            }
            weightsTexure =  context.device.texture1D(buffer:weights)
            offsetsTexture = context.device.texture1D(buffer:offsets)
            
            print("weights = \(weights)")
            print("offsets = \(offsets)")
        }
        else{
            empty = true
            remove(function: horizontal_pass_kernel)
            remove(function: vertical_pass_kernel)        
        }
    }

    var weightsTexure:MTLTexture!
    var offsetsTexture:MTLTexture!
    
    lazy var horizontal_pass_kernel:IMPFunction = {
        let f = IMPFunction(context: self.context, name: "kernel_gaussianSampledBlurHorizontalPass")
        
        f.optionsHandler = { (kernel,commandEncoder) in
            commandEncoder.setTexture(self.weightsTexure, at: 2)
            commandEncoder.setTexture(self.offsetsTexture, at: 3)
        }
        
        return f
    }()
    
    lazy var vertical_pass_kernel:IMPFunction   = {
        let f = IMPFunction(context: self.context,name: "kernel_gaussianSampledBlurVerticalPass")

        f.optionsHandler = { (kernel,commandEncoder) in
            commandEncoder.setTexture(self.weightsTexure, at: 2)
            commandEncoder.setTexture(self.offsetsTexture, at: 3)
            //commandEncoder.setTexture(source?.texture, atIndex: 4)
            //commandEncoder.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }

        return f
    }()
}


extension Collection where Iterator.Element == Float {
    
    typealias Element = Iterator.Element
    
    var gaussianInputs:[Element]{
        get{
            var oneSideInputs = [Element]()
            for i in stride(from: (self.count/2 as! Int), through: 0, by: -1) {
                
                if i == count as! Int/2  {
                    oneSideInputs.append(self[i as! Self.Index] * 0.5)
                }
                else{
                    oneSideInputs.append(self[i as! Self.Index])
                }
            }
            return oneSideInputs
        }
    }
    
    var gaussianWeights:[Element]{
        get{
            var weights = [Element]()
            let numSamples = self.count as! Int/2
            
            for i in 0 ..< numSamples {
                let index = i * 2
                let sum = self[index+0 as! Self.Index] + self[index + 1 as! Self.Index ]
                weights.append(sum)
            }
            return weights
        }
    }
    
    func gaussianOffsets(weights:[Element]) -> [Element]{
        var offsets = [Element]()
        let numSamples = self.count as! Int/2
        for i in 0 ..< numSamples  {
            let index = i * 2
            offsets.append( i.float * 2.0 + self[index+1 as! Self.Index] / weights[i] )
        }
        return offsets
    }
}
