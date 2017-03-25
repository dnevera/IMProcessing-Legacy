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
    public override func configure() {
        extendName(suffix: "SobelEdges")
        super.configure()
        add(function: sebelEdgesKernel)
    }
    private lazy var sebelEdgesKernel:IMPFunction = IMPFunction(context: self.context, kernelName: "kernel_sobelEdges")
}

public class IMPRasterizedSobelEdges:IMPFilter{
    
    public var rasterSize:uint = 1 { didSet{ dirty = true } }
    
    public override func configure() {
        extendName(suffix: "RasterizedSobelEdges")
        super.configure()
        
        sebelEdgesKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        sebelEdgesKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        add(function: sebelEdgesKernel)
    }
    
    private lazy var sebelEdgesKernel:IMPFunction = {
        
        let f = IMPFunction(context: self.context, kernelName: "kernel_rasterizedSobelEdges")
        f.optionsHandler = { (function, command, input, output) in
            command.setBytes(&self.rasterSize,length:MemoryLayout<uint>.size,at:0)
        }
        return f
    }()
    
    lazy var regionSize:Int = {
        return Int(sqrt(Float(self.sebelEdgesKernel.maxThreads)))
    }()
}
