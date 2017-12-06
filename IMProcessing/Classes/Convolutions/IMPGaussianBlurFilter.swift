//
//  IMPGaussianBlurFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 14.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Accelerate
import simd

open class IMPGaussianBlurFilter: IMPFilter {
    
    open static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    open var adjustment:IMPAdjustment!{
        didSet{
            adjustmentBuffer = adjustmentBuffer ?? context.device.makeBuffer(length: MemoryLayout.size(ofValue: adjustment), options: MTLResourceOptions())
            memcpy(adjustmentBuffer.contents(), &adjustment, adjustmentBuffer.length)
            dirty = true
        }
    }
    
    open var radius:Int!{
        didSet{
            update()
            dirty = true
        }
    }
    
    var adjustmentBuffer:MTLBuffer!
    var horizontal_pass_kernel : IMPFunction!
    var vertical_pass_kernel   : IMPFunction!
    var empty = true
    
    public required init(context: IMPContext) {
        super.init(context: context)
        horizontal_pass_kernel = IMPFunction(context: context, name: "kernel_gaussianSampledBlurHorizontalPass")
        vertical_pass_kernel   = IMPFunction(context: context, name: "kernel_gaussianSampledBlurVerticalPass")
        defer{
            radius = 0
            adjustment = IMPGaussianBlurFilter.defaultAdjustment
        }
    }
    
    var weightsTexure:MTLTexture!
    var offsetsTexture:MTLTexture!
    
    func create1DTexture(_ buffer:[Float]) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .type1D
        weightsDescription.pixelFormat = .r32Float
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = context.device.makeTexture(descriptor: weightsDescription)
        texture?.replace(region: MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: MemoryLayout<Float32>.size*buffer.count)
        return texture!
    }
    
    func update(){
        let kernel: [Float] = radius.gaussianKernel
        let inputs: [Float] = kernel.gaussianInputs
        
        let weights:[Float] = inputs.gaussianWeights
        let offsets:[Float] = inputs.gaussianOffsets(weights)
        
        if weights.count>0{
            if empty {
                empty = false
                addFunction(horizontal_pass_kernel)
                addFunction(vertical_pass_kernel)
            }
            weightsTexure =  context.device.texture1D(weights)
            offsetsTexture = context.device.texture1D(offsets)
        }
        else{
            empty = true
            removeAllFunctions()
        }
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if function == horizontal_pass_kernel || function == vertical_pass_kernel {
            command.setTexture(weightsTexure, index: 2)
            command.setTexture(offsetsTexture, index: 3)
            if function == vertical_pass_kernel{
                command.setTexture(source?.texture, index: 4)
                command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
            }
        }
    }
}


extension Collection where Iterator.Element == Float {
    
    func drop(threshold: Float) -> [Float] {
        var collection = [Float]()
        for i in self {
            if i > threshold{
                collection.append(i)
            }
        }
        return collection
    }
    
    var gaussianInputs:[Float]{
        get{
            var oneSideInputs = [Float]()
            for i in stride(from: (count/2 as! Int), through: 0, by: -1) {
  
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
    
    var gaussianWeights:[Float]{
        get{
            var weights = [Float]()
            let numSamples = self.count as! Int/2
            
            for i in 0 ..< numSamples {
                let index = i * 2
                let sum = self[index+0 as! Self.Index] + self[index + 1 as! Self.Index ]
                weights.append(sum)
            }
            return weights
        }
    }
    
    func gaussianOffsets(_ weights:[Float]) -> [Float]{
        var offsets = [Float]()
        let numSamples = self.count as! Int/2
        for i in 0 ..< numSamples  {
            let index = i * 2
            offsets.append( i.float * 2.0 + self[index+1 as! Self.Index] / weights[i] )
        }
        return offsets
    }
}
