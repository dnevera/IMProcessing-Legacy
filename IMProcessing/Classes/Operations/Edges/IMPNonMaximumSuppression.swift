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
    
    public var threshold:Float = defaultThreshold {
        didSet{
            thresholdBuffer <= threshold
            dirty = true
        }
    }
    
    public required init(context: IMPContext, name: String?=nil) {
        super.init(context:context, name:name, functionName:"fragment_nonMaximumSuppression")
    }
    
    public required init(context: IMPContext, name: String?, functionName: String) {
        fatalError("IMPNonMaximumSuppression:init(context:name:functionName:) has been already implemented")
    }
    
    public override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "NonMaximumSuppression")
        super.configure(complete:complete)
    }
    
    public override func optionsHandler(shader: IMPShader,
                                        command: MTLRenderCommandEncoder,
                                        inputTexture: MTLTexture?,
                                        outputTexture: MTLTexture?) {
        command.setFragmentBuffer(self.thresholdBuffer, offset: 0, at: 1)
    }
    
    
    lazy var thresholdBuffer:MTLBuffer = self.context.makeBuffer(from: defaultThreshold)
    
}

public class IMPDirectionalNonMaximumSuppression: IMPDerivative {
    
    public static let defaultUpperThreshold:Float = 0.4
    public static let defaultLowerThreshold:Float = 0.1
    
    public var upperThreshold:Float = defaultUpperThreshold {
        didSet{
            upperThresholdBuffer <= upperThreshold
            dirty = true
        }
    }
    
    public var lowerThreshold:Float = defaultLowerThreshold {
        didSet{
            lowerThresholdBuffer <= lowerThreshold
            dirty = true
        }
    }
    
    public required init(context: IMPContext, name: String?=nil) {
        super.init(context:context, name:name, functionName:"fragment_directionalNonMaximumSuppression")
    }
    
    public required init(context: IMPContext, name: String?, functionName: String) {
        fatalError("IMPDirectionalNonMaximumSuppression:init(context:name:functionName:) has been already implemented")
    }
    
    public override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "NonMaximumSuppression")
        super.configure(complete:complete)
    }
    
    public override func optionsHandler(shader: IMPShader, command: MTLRenderCommandEncoder, inputTexture: MTLTexture?, outputTexture: MTLTexture?) {
        command.setFragmentBuffer(self.upperThresholdBuffer, offset: 0, at: 1)
        command.setFragmentBuffer(self.lowerThresholdBuffer, offset: 0, at: 2)
    }
    
    
    lazy var upperThresholdBuffer:MTLBuffer = self.context.makeBuffer(from: defaultUpperThreshold)
    lazy var lowerThresholdBuffer:MTLBuffer = self.context.makeBuffer(from: defaultLowerThreshold)
}
