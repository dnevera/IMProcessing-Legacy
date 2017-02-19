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
    
    public var radius:Float!{
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
            return radiusLimit > radius ? radius : radiusLimit
        }
    }
    
    var pixelRadius:Int {
        let samplingArea:Float = 1.0 / 256.0
        var newRadius:Int = 0
        if sigma >= 1.0 {
            newRadius = Int(floor(sqrt(-2.0 * pow(sigma, 2.0) * log(samplingArea * sqrt(2.0 * .pi * pow(sigma, 2.0))) )))
            newRadius += newRadius % 2
        }
        return newRadius
    }
    
    var downsamplingFactor:Float {
        return  1 //radiusLimit > radius ? 1 : round(Float(radius)) / radiusLimit
    }
    

    
    var adjustmentBuffer:MTLBuffer!
    var empty = true
    func update(){
        
        var factor = downsamplingFactor
        memcpy(downsamplingFactorBuffer.contents(), &factor, downsamplingFactorBuffer.length)
        
        let kernel: [Float] = radius.int.gaussianKernel
        let inputs: [Float] = kernel.gaussianInputs
        
        let weights:[Float] = inputs.gaussianWeights
        let offsets:[Float] = inputs.gaussianOffsets(weights: weights)

        //let weights:[Float] = optimizedWeights(pixelRadius, sigma: sigma)
        //let offsets:[Float] = optimizedOffsets(pixelRadius, sigma: sigma)

        if weights.count>0{
            if empty {
                empty = false
                add(function: horizontal_pass_kernel)
                add(function: vertical_pass_kernel)
            }
            weightsTexure =  context.device.texture1D(buffer:weights)
            offsetsTexture = context.device.texture1D(buffer:offsets)
            
            NSLog("weights[\(radius, pixelRadius, sigma, downsamplingFactor)] = \(weights)")
            NSLog("offsets = \(offsets)")
        }
        else{
            empty = true
            remove(function: horizontal_pass_kernel)
            remove(function: vertical_pass_kernel)        
        }
    }

    lazy var downsamplingFactorBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    var weightsTexure:MTLTexture!
    var offsetsTexture:MTLTexture!
    var sourceTexture:MTLTexture?
    
    lazy var horizontal_pass_kernel:IMPFunction = {
        let f = IMPFunction(context: self.context, name: "kernel_gaussianSampledBlurHorizontalPass")
        
        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            self.sourceTexture = input
            commandEncoder.setTexture(self.weightsTexure, at: 2)
            commandEncoder.setTexture(self.offsetsTexture, at: 3)
            commandEncoder.setBuffer(self.downsamplingFactorBuffer, offset:0, at: 0)
        }
        
        return f
    }()
    
    lazy var vertical_pass_kernel:IMPFunction   = {
        let f = IMPFunction(context: self.context,name: "kernel_gaussianSampledBlurVerticalPass")

        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            commandEncoder.setTexture(self.weightsTexure, at: 2)
            commandEncoder.setTexture(self.offsetsTexture, at: 3)
            commandEncoder.setTexture(self.sourceTexture, at: 4)
            
            commandEncoder.setBuffer(self.downsamplingFactorBuffer, offset: 0, at:0)
            commandEncoder.setBuffer(self.adjustmentBuffer, offset: 0, at: 1)
        }

        return f
    }()
    
    
    func gaussianWeights(_ radius:Int, sigma:Float) -> [Float] {
        var weights = [Float]()
        var sumOfWeights:Float = 0.0
        
        for index in 0...radius {
            let weight:Float = (1.0 / sqrt(2.0 * .pi * pow(sigma, 2.0))) * exp(-pow(Float(index), 2.0) / (2.0 * pow(sigma, 2.0)))
            weights.append(weight)
            if (index == 0) {
                sumOfWeights += weight
            } else {
                sumOfWeights += (weight * 2.0)
            }
        }
        return weights.map{$0 / sumOfWeights}
    }
    
    func optimizedOffsets(_ radius:Int, sigma:Float) -> [Float] {
        
        let standardWeights = gaussianWeights(radius, sigma:sigma)
        let count = min(radius / 2 + (radius % 2), 7)
        
        var optimizedOffsets = [Float]()
        optimizedOffsets.append(0)
        
        for index in 0..<count {
            let firstWeight = Float(standardWeights[Int(index * 2 + 1)])
            let secondWeight = Float(standardWeights[Int(index * 2 + 2)])
            let optimizedWeight = firstWeight + secondWeight
            
            optimizedOffsets.append((firstWeight * (Float(index) * 2.0 + 1.0) + secondWeight * (Float(index) * 2.0 + 2.0)) / optimizedWeight)
        }
        
        return optimizedOffsets
    }
    
    func optimizedWeights(_ radius:Int, sigma:Float) -> [Float] {
        let standardWeights = gaussianWeights(radius, sigma:sigma)
        let count = min(radius / 2 + (radius % 2), 7)
        let trueNumberOfOptimizedOffsets = radius / 2 + (radius % 2)

        var optimizedWeights = [Float]()
        optimizedWeights.append(standardWeights[0])

        for index in 0..<count {
            let firstWeight = standardWeights[Int(index * 2 + 1)]
            let secondWeight = standardWeights[Int(index * 2 + 2)]
            let optimizedWeight = firstWeight + secondWeight
            optimizedWeights.append(optimizedWeight)
        }
        
        return optimizedWeights
    }
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
