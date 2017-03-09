//
//  IMPOperator.swift
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPDerivative: IMPFilter{
    
    public let functionName: String
    
    public required init(context: IMPContext, name: String?=nil, functionName: String) {
        self.functionName = functionName
        super.init(context: context, name: name)
    }
    
    public required init(context: IMPContext, name: String?=nil) {
        fatalError("IMPBasicDerivative.init(context:name:) has not been implemented, use init(context:name:functionName:)")
    }
    
    public override func configure() {
        extendName(suffix: "Derivative" + ":" + functionName)
        super.configure()
        updateGradientCoords()
        add(shader:derivative)
    }        
    
    open func optionsHandler(shader:IMPShader, command:MTLRenderCommandEncoder, inputTexture:MTLTexture?, outputTexture:MTLTexture?){}
    
    private lazy var derivative:IMPShader = {
        let s = IMPShader(context: self.context,
                          fragmentName: self.functionName)
        
        s.optionsHandler = { (shader, commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.gradientCoordsBuffer, offset: 0, at: 0)
            self.optionsHandler(shader: shader, command: commandEncoder, inputTexture: input, outputTexture: output)
        }
        return s
    }()
    
    public override var source: IMPImageProvider? {
        didSet{
             updateGradientCoords()
        }
    }
    
    public override var destinationSize: NSSize? {
        didSet{
            updateGradientCoords()
        }
    }
    
    private func updateGradientCoords()  {
        if let size = destinationSize ?? source?.size {
            let t:float2 = float2(1/size.width.float, 1/size.height.float)
            gradientCoords = IMPGradientCoords(point: ((float2(-t.x,-t.y), float2(0,-t.y), float2(t.x,-t.y)),
                                                       (float2(-t.x, 0),   float2(0, 0),   float2(t.x, 0)),
                                                       (float2(-t.x, t.y), float2(0, t.y), float2(t.x, t.y))
                )
            )
        }
        else {
            gradientCoords = IMPGradientCoords()
        }
    }
    
    
    private var gradientCoords:IMPGradientCoords = IMPGradientCoords() {
        didSet{
            memcpy(gradientCoordsBuffer.contents(), &gradientCoords, gradientCoordsBuffer.length)
            dirty = true
        }
    }
    private lazy var gradientCoordsBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.gradientCoords), options: [])
}
