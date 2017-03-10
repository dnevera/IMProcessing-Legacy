//
//  IMPHarrisCorner.swift
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPHarrisCorner: IMPFilter{

    public static let defaultSensitivity:Float = 10

    public var sensitivity:Float = IMPHarrisCorner.defaultSensitivity {
        didSet{
            memcpy(sensitivityBuffer.contents(), &sensitivity, sensitivityBuffer.length)
            dirty = true
        }
    }
    
    public let functionName: String
    
    public required init(context: IMPContext, name: String?=nil) {
        self.functionName = "fragment_harrisCorner"
        super.init(context: context, name: name)
    }
    
    public override func configure() {
        extendName(suffix: "HarrisCorner")
        super.configure()
        sensitivity = IMPHarrisCorner.defaultSensitivity
        add(shader:derivative)
    }
    
    private lazy var derivative:IMPShader = {
        let s = IMPShader(context: self.context,
                          fragmentName: self.functionName)        
        s.optionsHandler = { (shader, commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.sensitivityBuffer, offset: 0, at: 0)
        }
        return s
    }()
    
    private lazy var sensitivityBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.sensitivity), options: [])
    
}
