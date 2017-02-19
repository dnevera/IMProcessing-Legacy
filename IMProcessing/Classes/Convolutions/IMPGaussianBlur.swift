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
import MetalPerformanceShaders

public class IMPGaussianBlurFilter: IMPFilter {
    
    public static let radiusRange:(minimum:Float, maximum:Float) = (minimum:0.5, maximum:1000)
    
    public static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            adjustmentBuffer = adjustmentBuffer ?? context.device.makeBuffer(length: MemoryLayout.size(ofValue: adjustment), options: [])
            memcpy(adjustmentBuffer.contents(), &adjustment, adjustmentBuffer.length)
            dirty = true
        }
    }

    public var radiusApproximation:Float = 8 {
        didSet{
            if !mpsSupported{
                update()
                dirty = true
            }
        }
    }
    
    public var radius:Float = 0 {
        didSet{
            if radius < IMPGaussianBlurFilter.radiusRange.minimum {
                radius = 0
            }
            else {
                radius = fmin(IMPGaussianBlurFilter.radiusRange.maximum,
                              fmax(radius,
                                   IMPGaussianBlurFilter.radiusRange.minimum))
            }
            if !mpsSupported{
                update()
            }
            else{
                mpsBlurFilter.sigma = radius
            }
            dirty = true
        }
    }
    
    public override func configure(_ withName: String?) {
        self.name = "IMPGaussianBlurFilter"
        adjustment = IMPGaussianBlurFilter.defaultAdjustment
        radius = 0
        if mpsSupported {
            add(mps: mpsBlurFilter)
        }
        else {
            add(shader: horizontal_shader)
            add(shader: vertical_shader)
        }
    }
  
    
    lazy var mpsSupported:Bool = MPSSupportsMTLDevice(self.context.device)
    
    var sigma:Float {
        get {
            return radiusApproximation > radius ? radius : radiusApproximation
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
        return  radiusApproximation > radius ? 1 : round(Float(radius)) / radiusApproximation
    }
    
    
    var adjustmentBuffer:MTLBuffer!
    var empty = true
    func update(){
        
        if radius <= IMPGaussianBlurFilter.radiusRange.minimum {
            empty = true
            removeAll()
            return
        }

        guard  let size = source?.image?.extent.size else {return}
        
        var
        factor = float2(downsamplingFactor/size.width.float, 0)
        memcpy(hTexelSizeBuffer.contents(), &factor, hTexelSizeBuffer.length)
        
        factor = float2(0, downsamplingFactor/size.height.float)
        memcpy(vTexelSizeBuffer.contents(), &factor, vTexelSizeBuffer.length)
        
        let offsets:[Float] = optimizedOffsets(pixelRadius, sigma: sigma)
        let (weights, extendedWeights, extendedOffsets) = optimizedWeights(pixelRadius, sigma: sigma)
        
        if empty {
            empty = false
            add(shader: horizontal_shader)
            add(shader: vertical_shader)
        }
        weightsTexure =  context.device.texture1D(buffer:weights)
        offsetsTexture = context.device.texture1D(buffer:offsets)
        
        var exceeds = false
        
        if extendedOffsets.count > 0 {
            extendedWeightsTexure =  context.device.texture1D(buffer:extendedWeights)
            extendedOffsetsTexture = context.device.texture1D(buffer:extendedWeights)
            exceeds = true
        }

        memcpy(exceedsBuffer.contents(), &exceeds, exceedsBuffer.length)
    }

    var weightsTexure:MTLTexture!
    var extendedWeightsTexure:MTLTexture!
    var offsetsTexture:MTLTexture!
    var extendedOffsetsTexture:MTLTexture!
    
    lazy var hTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    lazy var vTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    lazy var exceedsBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Bool>.size, options: [])
    
    lazy var horizontal_shader:IMPShader = {
        
        let s = IMPShader(context: self.context,
                          vertex: "vertex_passthrough",
                          fragment: "fragment_gaussianSampledBlur",
                          withName: "gaussianBlurHorizontalShader")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.hTexelSizeBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentBuffer(self.exceedsBuffer, offset: 0, at: 1)
            commandEncoder.setFragmentTexture(self.weightsTexure, at:1)
            commandEncoder.setFragmentTexture(self.offsetsTexture, at:2)
            commandEncoder.setFragmentTexture(self.extendedWeightsTexure, at:3)
            commandEncoder.setFragmentTexture(self.extendedOffsetsTexture, at:4)
        }
        
        return s
    }()
    
    lazy var vertical_shader:IMPShader = {
        
        let s = IMPShader(context: self.context,
                          vertex: "vertex_passthrough",
                          fragment: "fragment_gaussianSampledBlur",
                          withName: "gaussianBlurVerticalShader")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.vTexelSizeBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentBuffer(self.exceedsBuffer, offset: 0, at: 1)
            commandEncoder.setFragmentTexture(self.weightsTexure, at:1)
            commandEncoder.setFragmentTexture(self.offsetsTexture, at:2)
            commandEncoder.setFragmentTexture(self.extendedWeightsTexure, at:3)
            commandEncoder.setFragmentTexture(self.extendedOffsetsTexture, at:4)
        }
        
        return s
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
        let count = min(radius / 2 + (radius % 2), radiusApproximation.int-1)
        
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
    
    func optimizedWeights(_ radius:Int, sigma:Float) -> ([Float],[Float],[Float]) {
        
        let standardWeights = gaussianWeights(radius, sigma:sigma)
        let count     = min(radius / 2 + (radius % 2), radiusApproximation.int-1)
        let trueCount = radius / 2 + (radius % 2)

        var optimizedWeights = [Float]()
        optimizedWeights.append(standardWeights[0])

        for index in 0..<count {
            let firstWeight = standardWeights[Int(index * 2 + 1)]
            let secondWeight = standardWeights[Int(index * 2 + 2)]
            let optimizedWeight = firstWeight + secondWeight
            optimizedWeights.append(optimizedWeight)
        }
        
        var extendedOffsets = [Float]()
        var extendedWeights = [Float]()
        
        for index in count..<trueCount {
            let firstWeight = standardWeights[Int(index * 2 + 1)];
            let secondWeight = standardWeights[Int(index * 2 + 2)];
            
            let optimizedWeight = firstWeight + secondWeight
            let optimizedOffset = (firstWeight * (Float(index) * 2.0 + 1.0) + secondWeight * (Float(index) * 2.0 + 2.0)) / optimizedWeight
            
            extendedOffsets.append(optimizedOffset)
            extendedWeights.append(optimizedWeight)
        }
        
        return (optimizedWeights, extendedWeights, extendedOffsets)
    }
    
    class BlurFilter: IMPMPSUnaryKernelProvider {
        var name: String { return "__MpsBlurFilter__" }
        func mps(device:MTLDevice) -> MPSUnaryImageKernel? {
            return MPSImageGaussianBlur(device: device, sigma: sigma)
        }
        var sigma:Float = 1
        var context: IMPContext?
        init(context:IMPContext?) {
            self.context = context
        }
    }
    
    lazy var mpsBlurFilter:BlurFilter = BlurFilter(context:self.context)
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
