//
//  IMPNonMaximumSuppression.swift
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPNonMaximumSuppression: IMPDerivative {
    
    public static let defaultThreshold:Float = 0.2
    
    public var threshold:Float = IMPNonMaximumSuppression.defaultThreshold {
        didSet{
            memcpy(thresholdBuffer.contents(), &threshold, thresholdBuffer.length)
            dirty = true
        }
    }
    
    public required init(context: IMPContext, name: String?=nil) {
        super.init(context:context, name:name, functionName:"fragment_nonMaximumSuppression")
    }
    
    public required init(context: IMPContext, name: String?, functionName: String) {
        fatalError("IMPNonMaximumSuppression:init(context:name:functionName:) has been already implemented")
    }
    
    public override func configure() {
        extendName(suffix: "NonMaximumSuppression")
        super.configure()
        threshold = IMPNonMaximumSuppression.defaultThreshold
    }
    
    public override func optionsHandler(shader: IMPShader, command: MTLRenderCommandEncoder, inputTexture: MTLTexture?, outputTexture: MTLTexture?) {
        command.setFragmentBuffer(self.thresholdBuffer, offset: 0, at: 1)
    }
    
    
    lazy var thresholdBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.threshold), options: [])
    
}

public class IMPDirectionalNonMaximumSuppression: IMPDerivative {
    
    public static let defaultUpperThreshold:Float = 0.4
    public static let defaultLowerThreshold:Float = 0.1
    
    public var upperThreshold:Float = IMPDirectionalNonMaximumSuppression.defaultUpperThreshold {
        didSet{
            memcpy(upperThresholdBuffer.contents(), &upperThreshold, upperThresholdBuffer.length)
            dirty = true
        }
    }
    
    public var lowerThreshold:Float = IMPDirectionalNonMaximumSuppression.defaultLowerThreshold {
        didSet{
            memcpy(lowerThresholdBuffer.contents(), &lowerThreshold, lowerThresholdBuffer.length)
            dirty = true
        }
    }
    
    public required init(context: IMPContext, name: String?=nil) {
        super.init(context:context, name:name, functionName:"fragment_directionalNonMaximumSuppression")
    }
    
    public required init(context: IMPContext, name: String?, functionName: String) {
        fatalError("IMPDirectionalNonMaximumSuppression:init(context:name:functionName:) has been already implemented")
    }
    
    public override func configure() {
        extendName(suffix: "NonMaximumSuppression")
        super.configure()
        upperThreshold = IMPDirectionalNonMaximumSuppression.defaultUpperThreshold
        lowerThreshold = IMPDirectionalNonMaximumSuppression.defaultLowerThreshold
    }
    
    public override func optionsHandler(shader: IMPShader, command: MTLRenderCommandEncoder, inputTexture: MTLTexture?, outputTexture: MTLTexture?) {
        command.setFragmentBuffer(self.upperThresholdBuffer, offset: 0, at: 1)
        command.setFragmentBuffer(self.lowerThresholdBuffer, offset: 0, at: 2)
    }
    
    
    lazy var upperThresholdBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.upperThreshold), options: [])
    lazy var lowerThresholdBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.lowerThreshold), options: [])
}
