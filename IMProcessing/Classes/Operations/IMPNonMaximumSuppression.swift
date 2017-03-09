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
