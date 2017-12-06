//
//  IMPHSVFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal
import simd

public extension IMProcessing{
    public struct hsv {
        /// Ramps of HSV hextants in the HSV color wheel with overlaping levels
        public static let hueRamps:[float4] = [kIMP_Reds, kIMP_Yellows, kIMP_Greens, kIMP_Cyans, kIMP_Blues, kIMP_Magentas]
        /// Hextants aliases
        public static let reds     = hueRamps[0]
        public static let yellows  = hueRamps[1]
        public static let greens   = hueRamps[2]
        public static let cyans    = hueRamps[3]
        public static let blues    = hueRamps[4]
        public static let magentas = hueRamps[5]
        
        /// Overlap factor
        public static var hueOverlapFactor:Float  = 1.4
        /// Hue range of the HSV color wheel
        fileprivate static let hueRange = CountableRange<Int>(0..<360)
    }
}

public extension Float32{
    
    //
    // Get HSV weight which uses to define how two close colors interfer between ech others
    //
    func overlapWeight(ramp:float4, overlap:Float = IMProcessing.hsv.hueOverlapFactor) -> Float32 {
        
        var sigma = (ramp.z-ramp.y)
        var mu    = (ramp.w+ramp.x)/2.0
        
        if ramp.y>ramp.z {
            sigma = (IMProcessing.hsv.hueRange.upperBound.float-ramp.y+ramp.z)
            if (self >= 0.float) && (self <= IMProcessing.hsv.hueRange.upperBound.float/2.0) {
                mu    = (IMProcessing.hsv.hueRange.upperBound.float-ramp.y-ramp.z) / 2.0
            }else{
                mu    = (ramp.y+ramp.z)
            }
        }
        
        return self.gaussianPoint(fi: 1, mu: mu, sigma: sigma * overlap)
    }
}

public extension Sequence where Iterator.Element == Float32 {
    
    public func overlapWeightsDistribution(ramp:float4, overlap:Float = IMProcessing.hsv.hueOverlapFactor) -> [Float32]{
        var a = [Float32]()
        for i in self{
            a.append(i.overlapWeight(ramp: ramp, overlap: overlap))
        }
        return a
    }
    
    public func overlapWeightsDistribution(ramp:float4, overlap:Float = IMProcessing.hsv.hueOverlapFactor) -> Data {
        let f:[Float32] = overlapWeightsDistribution(ramp: ramp, overlap: overlap) as [Float32]
        return Data(bytes: UnsafeRawPointer(UnsafePointer<Float32>(f)), count: f.count)
    }
    
}

public func * (left:IMPHSVLevel,right:Float) -> IMPHSVLevel {
    return IMPHSVLevel(hue: left.hue * right, saturation: left.saturation * right, value: left.value * right)
}

public extension IMPHSVAdjustment{
    
    public var reds:    IMPHSVLevel{ get { return levels.0 } set{ levels.0 = newValue }}
    public var yellows: IMPHSVLevel{ get { return levels.1 } set{ levels.1 = newValue }}
    public var greens:  IMPHSVLevel{ get { return levels.2 } set{ levels.2 = newValue }}
    public var cyans:   IMPHSVLevel{ get { return levels.3 } set{ levels.3 = newValue }}
    public var blues:   IMPHSVLevel{ get { return levels.4 } set{ levels.4 = newValue }}
    public var magentas:IMPHSVLevel{ get { return levels.5 } set{ levels.5 = newValue }}
    
    public subscript(index:Int) -> IMPHSVLevel {
        switch(index){
        case 0:
            return levels.0
        case 1:
            return levels.1
        case 2:
            return levels.2
        case 3:
            return levels.3
        case 4:
            return levels.4
        case 5:
            return levels.5
        default:
            return master
        }
    }
    
    public mutating func hue(index:Int, value newValue:Float){
        switch(index){
        case 0:
            levels.0.hue = newValue
        case 1:
            levels.1.hue = newValue
        case 2:
            levels.2.hue = newValue
        case 3:
            levels.3.hue = newValue
        case 4:
            levels.4.hue  = newValue
        case 5:
            levels.5.hue  = newValue
        default:
            master.hue  = newValue
        }
    }
    
    public mutating func saturation(index:Int, value newValue:Float){
        switch(index){
        case 0:
            levels.0.saturation = newValue
        case 1:
            levels.1.saturation = newValue
        case 2:
            levels.2.saturation = newValue
        case 3:
            levels.3.saturation = newValue
        case 4:
            levels.4.saturation  = newValue
        case 5:
            levels.5.saturation  = newValue
        default:
            master.saturation  = newValue
        }
    }
    
    public mutating func value(index:Int, value newValue:Float){
        switch(index){
        case 0:
            levels.0.value = newValue
        case 1:
            levels.1.value = newValue
        case 2:
            levels.2.value = newValue
        case 3:
            levels.3.value = newValue
        case 4:
            levels.4.value  = newValue
        case 5:
            levels.5.value  = newValue
        default:
            master.value  = newValue
        }
    }
}

///
/// HSV adjustment filter
///
open class IMPHSVFilter:IMPFilter,IMPAdjustmentProtocol{
   
    public typealias Adjustment = IMPHSVAdjustment
    
    ///  Optimization level description
    ///
    ///  - HIGH:   default optimization uses when you need to accelerate hsv adjustment
    ///  - NORMAL: hsv adjustments application without interpolation
    public enum Optimization{
        case high
        case normal
    }
    
    ///
    /// Default HSV adjustment
    ///
    open static let defaultAdjustment = Adjustment(
        master:   IMPHSVFilter.level,
        levels:  (IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level,IMPHSVFilter.level),
        blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1)
    )
    
    /// HSV adjustment levels
    open var adjustment:Adjustment!{
        didSet{
            if self.optimization == .high {
                adjustmentLut.blending = adjustment.blending
                updateBuffer(&adjustmentLutBuffer, context:context, adjustment:&adjustmentLut, size:MemoryLayout<IMPAdjustment>.size)
                updateBuffer(&adjustmentBuffer, context:context_hsv3DLut, adjustment:&adjustment, size:MemoryLayout<IMPHSVAdjustment>.size)
                applyHsv3DLut()
            }
            else {
                updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout<IMPHSVAdjustment>.size)
            }
            
            dirty = true
        }
    }
    
    ///
    /// Overlap colors in the HSV color wheel. Define the width of color overlaping.
    ///
    open var overlap:Float = IMProcessing.hsv.hueOverlapFactor {
        didSet{
            hueWeights = IMPHSVFilter.defaultHueWeights(self.context, overlap: overlap)
            if self.optimization == .high {
                applyHsv3DLut()
            }
            dirty = true
        }
    }
    
    ///  Create HSV adjustment filter. 
    ///
    ///  - .HIGH optimization level uses to reduce HSV adjustment computation per pixel.
    ///     only defult 64x64x64 LUT creates and then applies to final image. With this 
    ///     option an image modification can lead to the appearance of artifacts in the image.
    ///    .HIGH level can use for live-view mode of image processing
    ///
    ///  - .Normal uses for more precise HSV adjustments
    ///
    ///  - parameter context:      execution context
    ///  - parameter optimization: optimization level
    ///
    public required init(context: IMPContext, optimization:Optimization) {
        
        super.init(context: context)
        
        self.optimization = optimization
        
        if self.optimization == .high {
            hsv3DlutTexture = hsv3DLut(self.rgbCubeSize)
            kernel_hsv3DLut = IMPFunction(context: self.context_hsv3DLut, name: "kernel_adjustHSV3DLut")
            kernel = IMPFunction(context: self.context, name: "kernel_adjustLutD3D")
        }
        else{
            kernel = IMPFunction(context: self.context, name: "kernel_adjustHSV")
        }
        
        addFunction(kernel)
        
        defer{
            adjustment = IMPHSVFilter.defaultAdjustment
        }
        
        //NSLog("\(self): \(self.optimization )")
    }

    ///  Create HSV adjustment filter with default optimization level .NORMAL
    ///
    ///  - parameter context: device execution context
    ///
    public convenience required init(context: IMPContext) {
        self.init(context: context, optimization:context.isLazy ? .high : .normal)
    }
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            if self.optimization == .high {
                command.setTexture(hsv3DlutTexture, index: 2)
                command.setBuffer(adjustmentLutBuffer, offset: 0, index: 0)
            }
            else{
                command.setTexture(hueWeights, index: 2)
                command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
            }
        }
    }
    
    
    ///  Create new hue color overlaping weights for the HSV color wheel
    ///
    ///  - parameter context: device execution context
    ///
    ///  - returns: new overlaping weights
    open static func defaultHueWeights(_ context:IMPContext, overlap:Float) -> MTLTexture {
        let width  = IMProcessing.hsv.hueRange.upperBound
        
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = .type1DArray;
        textureDescriptor.width       = width;
        textureDescriptor.height      = 1;
        textureDescriptor.depth       = 1;
        textureDescriptor.pixelFormat = .r32Float;
        
        textureDescriptor.arrayLength = IMProcessing.hsv.hueRamps.count;
        textureDescriptor.mipmapLevelCount = 1;
        
        let region = MTLRegionMake2D(0, 0, width, 1);
        
        let hueWeights = context.device.makeTexture(descriptor: textureDescriptor)
        
        let hues = Float.range(0..<width)
        for i in 0..<IMProcessing.hsv.hueRamps.count{
            let ramp = IMProcessing.hsv.hueRamps[i]
            var data = hues.overlapWeightsDistribution(ramp: ramp, overlap: overlap) as [Float32]
            hueWeights?.replace(region: region, mipmapLevel:0, slice:i, withBytes:&data, bytesPerRow:MemoryLayout<Float32>.size * width, bytesPerImage:0)
        }
        
        return hueWeights!;
    }
    
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    open var rgbCube:MTLTexture? {
        return hsv3DlutTexture
    }
    
    open var rgbCubeSize = 64 {
        didSet{
            if self.optimization == .high {
                
                adjustmentLut.blending = adjustment.blending
                updateBuffer(&adjustmentLutBuffer, context:context, adjustment:&adjustmentLut, size:MemoryLayout<IMPAdjustment>.size)
                updateBuffer(&adjustmentBuffer, context:context_hsv3DLut, adjustment:&adjustment, size:MemoryLayout<Adjustment>.size)
                
                applyHsv3DLut()
                
                dirty = true
            }
        }
    }

    internal static let level:IMPHSVLevel = IMPHSVLevel(hue: 0.0, saturation: 0, value: 0)
    internal lazy var hueWeights:MTLTexture = {
        return IMPHSVFilter.defaultHueWeights(self.context, overlap: IMProcessing.hsv.hueOverlapFactor)
    }()
    
    fileprivate  var adjustmentLut = IMPAdjustment(blending: IMPBlending(mode: IMPBlendingMode.NORMAL, opacity: 1))
    internal var adjustmentLutBuffer:MTLBuffer?
    
    fileprivate var optimization:Optimization!

    //
    // Convert HSV transformation to 3D-rgb lut-cube
    //
    //
    fileprivate var kernel_hsv3DLut:IMPFunction!
    fileprivate lazy var context_hsv3DLut:IMPContext = {return self.context }()
    
    fileprivate func applyHsv3DLut(){
        
        context_hsv3DLut.execute{ (commandBuffer) -> Void in
            
            let width  = self.hsv3DlutTexture!.width
            let height = self.hsv3DlutTexture!.height
            let depth  = self.hsv3DlutTexture!.depth
            
            let threadgroupCounts = MTLSizeMake(4, 4, 4)
            let threadgroups = MTLSizeMake(width/4, height/4, depth/4)
            
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()
            
            commandEncoder?.setComputePipelineState(self.kernel_hsv3DLut.pipeline!)
            
            commandEncoder?.setTexture(self.hsv3DlutTexture, index:0)
            commandEncoder?.setTexture(self.hueWeights, index:1)
            commandEncoder?.setBuffer(self.adjustmentBuffer, offset: 0, index: 0)

            commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts)
            commandEncoder?.endEncoding()
            #if os(OSX)
                let blitEncoder = commandBuffer.blitCommandEncoder()
                blitEncoder.synchronizeResource(self.hsv3DlutTexture!)
                blitEncoder.endEncoding()
            #endif
        }
    }

    fileprivate var hsv3DlutTexture:MTLTexture?
    
    fileprivate func hsv3DLut(_ dimention:Int) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        
        textureDescriptor.textureType = .type3D
        textureDescriptor.width  = dimention
        textureDescriptor.height = dimention
        textureDescriptor.depth  = dimention
        
        textureDescriptor.pixelFormat = .rgba8Unorm
        
        textureDescriptor.arrayLength = 1;
        textureDescriptor.mipmapLevelCount = 1;
        
        let texture = context_hsv3DLut.device.makeTexture(descriptor: textureDescriptor)
        
        return texture!
    }
}
    
