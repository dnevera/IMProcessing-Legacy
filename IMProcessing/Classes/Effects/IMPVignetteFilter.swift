//
//  IMPVignetteFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 14.06.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Metal

/// Vignette filter
open class IMPVignetteFilter: IMPFilter,IMPAdjustmentProtocol {
    
    /// Vignetting type
    ///
    ///  - Center: around center point
    ///  - Frame:  by region frame rectangle
    public enum FilerType{
        case center
        case frame
    }
    
    ///  @brief Vignette adjustment
    public struct Adjustment {
        /// Start vignetting path
        public var start:Float  = 0 {
            didSet {
                check_diff()
            }
        }
        /// End vignetting path
        public var end:Float    = 1 {
            didSet {
                check_diff()
            }
        }
        /// Vignetting color
        public var color    = float3(0)
        /// Blending options
        public var blending = IMPBlending(mode: NORMAL, opacity: 1)
        public init(start:Float, end:Float, color:float3, blending:IMPBlending){
            self.start = start
            self.end = end
            self.color = color
            self.blending = blending
        }
        public init() {}
        
        mutating func  check_diff() {
            if abs(end - start) < FLT_EPSILON  {
                end   = start+FLT_EPSILON // to avoid smoothstep 0 division
            }
        }
    }
    
    /// Vignette region
    open var region = IMPRegion() {
        didSet{
            memcpy(regionUniformBuffer.contents(), &region, regionUniformBuffer.length)
            var c = center
            memcpy(centerUniformBuffer.contents(), &c, centerUniformBuffer.length)
            dirty = true
        }
    }
    
    open var center:float2 {
        get {
            let rect = region.rectangle
            let x = rect.origin.x + rect.size.width/2
            let y = rect.origin.y + rect.size.height/2
            return float2(x.float,y.float)
        }
    }
    
    /// Default adjusment
    open static let defaultAdjustment = Adjustment()
    
    /// Current adjusment
    open var adjustment:Adjustment!{
        didSet{
            memcpy(colorStartUniformBuffer.contents(), &self.adjustment.start, colorStartUniformBuffer.length)
            memcpy(colorEndUniformBuffer.contents(), &self.adjustment.end, colorEndUniformBuffer.length)
            memcpy(colorUniformBuffer.contents(), &self.adjustment.color, colorUniformBuffer.length)
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment.blending, size:MemoryLayout.size(ofValue: adjustment.blending))
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    var type:FilerType!
    
    public required init(context: IMPContext, type:FilerType = .center) {
        super.init(context: context)
        self.type = type
        if type == .center {
            kernel = IMPFunction(context: self.context, name: "kernel_vignetteCenter")
        }
        else {
            kernel = IMPFunction(context: self.context, name: "kernel_vignetteFrame")
        }
        self.addFunction(kernel)
        defer{
            self.adjustment = IMPVignetteFilter.defaultAdjustment
        }
    }    
    
    required public init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
 
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setBuffer(adjustmentBuffer, offset: 0, at: 0)
            command.setBuffer(colorStartUniformBuffer, offset: 0, at: 1)
            command.setBuffer(colorEndUniformBuffer, offset: 0, at: 2)
            command.setBuffer(colorUniformBuffer, offset: 0, at: 3)
            if type == .center {
                command.setBuffer(centerUniformBuffer, offset: 0, at: 4)
            }
            else {
                command.setBuffer(regionUniformBuffer, offset: 0, at: 4)
            }
        }
    }
    
    lazy var regionUniformBuffer:MTLBuffer = {
        return self.context.device.makeBuffer(bytes: &self.region, length: MemoryLayout.size(ofValue: self.region), options: MTLResourceOptions())
    }()
    
    lazy var centerUniformBuffer:MTLBuffer = {
        var c = self.center
        return self.context.device.makeBuffer(bytes: &c, length: MemoryLayout.size(ofValue: c), options: MTLResourceOptions())
    }()

    lazy var colorStartUniformBuffer:MTLBuffer = {
        return self.context.device.makeBuffer(bytes: &self.adjustment.start, length: MemoryLayout.size(ofValue: self.adjustment.start), options: MTLResourceOptions())
    }()
    
    lazy var colorEndUniformBuffer:MTLBuffer = {
        return self.context.device.makeBuffer(bytes: &self.adjustment.end, length: MemoryLayout.size(ofValue: self.adjustment.end), options: MTLResourceOptions())
    }()
    
    lazy var colorUniformBuffer:MTLBuffer = {
        return self.context.device.makeBuffer(bytes: &self.adjustment.color, length: MemoryLayout.size(ofValue: self.adjustment.color), options: MTLResourceOptions())
    }()
}
