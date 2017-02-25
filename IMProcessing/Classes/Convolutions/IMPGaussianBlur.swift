//
//  IMPGaussianBlur.swift
//  Pods
//
//  Created by denis svinarchuk on 18.02.17.
//
//
//  Acknowledgement:
//  http://www.sunsetlakesoftware.com/ - the famous great work for Image Processing with GPU
//  A lot of ideas were taken from the Brad Larson project: https://github.com/BradLarson/GPUImage
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
            update()
        }
    }

    public var radiusApproximation:Float = 8 {
        didSet{
            update()
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
            update()
        }
    }
    
    public override func configure(_ withName: String?) {
        self.name = "IMPGaussianBlurFilter"
        adjustment = IMPGaussianBlurFilter.defaultAdjustment
        radius = 0
        
        func fail(_ error:RegisteringError) {
            fatalError("IMPGaussianBlurFilter: error = \(error)")

        }
        
        add(shader: downscaleShader, fail: fail)
        add(shader: horizontal_shader, fail: fail)
        add(shader: vertical_shader, fail: fail)
        add(shader: upscaleShader, fail: fail)
    }
    
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
    var oldRadius:Float = 0
    
    func update()  {
        context.async {
            self.updateWeights()
        }
    }
    
    func updateWeights(){
        
        guard  let size = source?.size else {return}
        
        //if oldRadius == radius {
        //    dirty = true
        //    return
        //}
        
        let newSize = NSSize(width: size.width/CGFloat(downsamplingFactor),
                             height: size.height/CGFloat(downsamplingFactor))
        
        downscaleShader.destinationSize = newSize
        upscaleShader.destinationSize = size
        
        oldRadius = radius
        
        var offsets:[Float] = [Float]()
        var weights:[Float] = [Float]()
        
        if radius > IMPGaussianBlurFilter.radiusRange.minimum {
            var
            factor = float2(1/newSize.width.float, 0)
            memcpy(hTexelSizeBuffer.contents(), &factor, hTexelSizeBuffer.length)
            
            factor = float2(0, 1/newSize.height.float)
            memcpy(vTexelSizeBuffer.contents(), &factor, vTexelSizeBuffer.length)
            
            offsets = optimizedOffsets(pixelRadius, sigma: sigma)
            var extendedWeights:[Float]
            var extendedOffsets:[Float]
            (weights, extendedWeights, extendedOffsets) = optimizedWeights(pixelRadius, sigma: sigma)
            
            if extendedOffsets.count > 0 {
                for i in 0..<extendedWeights.count {
                    weights.append(extendedWeights[i])
                    offsets.append(extendedOffsets[i])
                }
            }
        }
        
        if weights.count == 0 {
            weights.append(1)
            offsets.append(1)
        }
        
        weightsTexture = context.device.texture1D(buffer:weights)
        offsetsTexture = context.device.texture1D(buffer:offsets)
        dirty = true        
    }

    
    lazy var hTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    lazy var vTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    lazy var weightsTexture:MTLTexture = {
        return self.context.device.texture1D(buffer:[Float](repeating:1, count:1))
    }()
    lazy var offsetsTexture:MTLTexture = {
        return self.context.device.texture1D(buffer:[Float](repeating:1, count:1))
    }()
    
    
    lazy var downscaleShader:IMPShader = IMPShader(context: self.context)
    lazy var upscaleShader:IMPShader   = {
        let s = IMPShader(context: self.context, fragment: "fragment_blendSource")
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.adjustmentBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentTexture((self.source?.texture)!, at:1)
        }
        return s
    }()

    lazy var horizontal_shader:IMPShader = {
        let s = IMPShader(context: self.context,
                          fragment: "fragment_gaussianSampledBlur")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.hTexelSizeBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentTexture(self.weightsTexture, at:1)
            commandEncoder.setFragmentTexture(self.offsetsTexture, at:2)
        }
        
        return s
    }()
    
    lazy var vertical_shader:IMPShader = {
        
        let s = IMPShader(context: self.context,
                          fragment: "fragment_gaussianSampledBlur")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.vTexelSizeBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentTexture(self.weightsTexture, at:1)
            commandEncoder.setFragmentTexture(self.offsetsTexture, at:2)
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
    
    
    func count(for radius: Int) -> (count:Int,trueCount:Int) {
        return (min(radius / 2 + (radius % 2), radiusApproximation.int-1), radius / 2 + (radius % 2))
    }
    
    func optimizedOffsets(_ radius:Int, sigma:Float) -> [Float] {
        
        let standardWeights = gaussianWeights(radius, sigma:sigma)
        let (count, _) = self.count(for: radius)
        
        var optimizedOffsets = [Float]()
        optimizedOffsets.append(0)
        
        for index in 0..<count {
            let firstWeight     = standardWeights[Int(index * 2 + 1)]
            let secondWeight    = standardWeights[Int(index * 2 + 2)]
            let optimizedWeight = firstWeight + secondWeight
            
            optimizedOffsets.append((firstWeight * (Float(index) * 2.0 + 1.0) + secondWeight * (Float(index) * 2.0 + 2.0)) / optimizedWeight)
        }
        
        return optimizedOffsets
    }
    
    func optimizedWeights(_ radius:Int, sigma:Float) -> ([Float],[Float],[Float]) {
        
        let standardWeights = gaussianWeights(radius, sigma:sigma)
        let (count, trueCount) = self.count(for: radius)

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
            let firstWeight = standardWeights[Int(index * 2 + 1)]
            let secondWeight = standardWeights[Int(index * 2 + 2)]
            
            let optimizedWeight = firstWeight + secondWeight
            let optimizedOffset = (firstWeight * (Float(index) * 2.0 + 1.0) + secondWeight * (Float(index) * 2.0 + 2.0)) / optimizedWeight
            
            extendedOffsets.append(optimizedOffset)
            extendedWeights.append(optimizedWeight)
        }
        
        return (optimizedWeights, extendedWeights, extendedOffsets)
    }
}
