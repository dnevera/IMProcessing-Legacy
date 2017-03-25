//
//  IMPSobelEdges.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 25.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPSobelEdges:IMPFilter{

    public var rasterSize:uint = 1 { didSet{ dirty = true } }
    
    public override func configure() {
        extendName(suffix: "SobelEdges")
        super.configure()
        
        sebelEdgesKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        sebelEdgesKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        add(function: sebelEdgesKernel)
    }
    
    private lazy var sebelEdgesKernel:IMPFunction = {
        
        let f = IMPFunction(context: self.context, kernelName: "kernel_sobelEdges")
        f.optionsHandler = { (function, command, input, output) in
            command.setBytes(&self.rasterSize,length:MemoryLayout<uint>.size,at:0)
            if let texture = self.source?.texture {
                command.setTexture(texture, at: 2)
            }
        }
        return f
    }()
    
    lazy var regionSize:Int = {
        return Int(sqrt(Float(self.sebelEdgesKernel.maxThreads)))
    }()
}
