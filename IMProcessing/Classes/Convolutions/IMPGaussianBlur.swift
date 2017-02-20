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
    func update(){
        
        guard  let size = source?.image?.extent.size else {return}
        
        var offsets:[Float] = [Float]()
        var weights:[Float] = [Float]()
        if radius > IMPGaussianBlurFilter.radiusRange.minimum {
            var
            factor = float2(downsamplingFactor/size.width.float, 0)
            memcpy(hTexelSizeBuffer.contents(), &factor, hTexelSizeBuffer.length)
            
            factor = float2(0, downsamplingFactor/size.height.float)
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
        
        let newLines  = generateMSL(weights:weights,offsets:offsets)
        let newShader = String(format:self.shaderSource,newLines)
        
        horizontal_shader.updateShader(source: newShader)
        vertical_shader.updateShader(source: newShader)
        
        //print(newShader)
    }

    func generateMSL(weights:[Float], offsets:[Float]) -> String {
        var lines = String()
        if weights.count > 0 {
            lines += "color = texture.sample(s, (texCoord + texelSize)).rgb * \(weights[0]);" + "\n"
            for i in 1..<weights.count{
                lines += "color += texture.sample(s, (texCoord + texelSize * \(offsets[i]))).rgb * \(weights[i]);" + "\n"
                lines += "color += texture.sample(s, (texCoord - texelSize * \(offsets[i]))).rgb * \(weights[i]);" + "\n"
            }
        }
        return lines
    }
    
    lazy var hTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    lazy var vTexelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
    
    lazy var horizontal_shader:IMPShader = {
        let ss = String(format:self.shaderSource,self.fragmentBody)

        let s = IMPShader(context: self.context,
                          vertex: "vertex_passthrough",
                          fragment: "fragment_gaussianSampledBlur",
                          shaderSource: ss,
                          withName: "gaussianBlurHorizontalShader")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.hTexelSizeBuffer, offset: 0, at: 0)
        }
        
        return s
    }()
    
    lazy var vertical_shader:IMPShader = {
        
        let ss = String(format:self.shaderSource,self.fragmentBody)

        let s = IMPShader(context: self.context,
                          vertex: "vertex_passthrough",
                          fragment: "fragment_gaussianSampledBlur",
                          shaderSource: ss,
                          withName: "gaussianBlurVerticalShader")
        
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.vTexelSizeBuffer, offset: 0, at: 0)
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
        let (count, trueCount) = self.count(for: radius)
        
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
    
    lazy var mpsSupported:Bool = false //MPSSupportsMTLDevice(self.context.device)
    
    let shaderTypes:String = ""   + "\n"  +
        "#include <metal_stdlib>" + "\n"  +
        "#include <simd/simd.h>"  + "\n"  +
        "using namespace metal;"  + "\n"  +
        "typedef struct {" + "\n" +
        "packed_float3 position;" + "\n"  +
        "packed_float3 texcoord;" + "\n"  +
        "} IMPVertex;" + "\n"  +
        "" + "\n"  +
        "typedef struct {" + "\n"  +
        "    float4 position [[position]];" + "\n"  +
        "    float2 texcoord;" + "\n"  +
    "} IMPVertexOut;" + "\n"   + "\n"
    

    let vertextString:String = "vertex IMPVertexOut vertex_passthrough(" + "\n" +
        "const device IMPVertex*   vertex_array [[ buffer(0) ]]," + "\n" +
        "unsigned int vid [[ vertex_id ]]) {" + "\n" +
        "" + "\n" +
        "" + "\n" +
        "    IMPVertex in = vertex_array[vid];" + "\n" +
        "    float3 position = float3(in.position);" + "\n" +
        "" + "\n" +
        "    IMPVertexOut out;" + "\n" +
        "    out.position = float4(position,1);" + "\n" +
        "    out.texcoord = float2(float3(in.texcoord).xy);" + "\n" +
        "" + "\n" +
        "    return out;}"  + "\n"  + "\n"
    
    let fragmentString:String = "fragment float4 fragment_gaussianSampledBlur(" + "\n" +
        "IMPVertexOut in [[stage_in]]," + "\n" +
        "texture2d<float, access::sample> texture    [[ texture(0) ]]," + "\n" +
        "const device   float2           &texelSize  [[ buffer(0)  ]]" + "\n" +
        ") {" + "\n" +
        "constexpr sampler s(address::clamp_to_edge, filter::linear, coord::normalized);" + "\n" +
        "" + "\n" +
        "float2 texCoord = in.texcoord.xy;" + "\n" +
        "" + "\n" +
        "float3 color  =  texture.sample(s, texCoord).rgb;" + "\n" +
        ""    + "\n" +
        "%@"  + "\n" +
        ""    + "\n" +
        ""    + "\n" +
        "return float4(color,1);" +
    "}"
    
    lazy var shaderSource:String = self.shaderTypes + self.vertextString + self.fragmentString

    lazy var fragmentBody:String = ""
    
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
