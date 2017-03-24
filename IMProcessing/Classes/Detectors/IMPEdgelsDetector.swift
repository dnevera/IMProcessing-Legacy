//
//  IMPEdgelsDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 24.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
import Accelerate


/**
 Sources: https://infi.nl/nieuws/marker-detection-for-augmented-reality-applications/blog/view/id/56/#article_2
 */

public class IMPEdgelsDetector: IMPResampler{
   
    struct Edgel {
        var position = float2(0)
        var slope    = float2(0)
        
        func isOrientationCompatible(cmp:Edgel) -> Bool {
            return (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.38
        }
    }
    
    lazy var regionSize:Int = {
        return Int(sqrt(Float(self.edgelsKernel.maxThreads)))
    }()
    
    public override var source: IMPImageProvider? {
        didSet{
            edegelSizeBuffer = context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
            memset(edegelSizeBuffer.contents(),0,MemoryLayout<uint>.size)
        }
    }
    
    public var rasterSize:uint = 5
    
    public override func configure() {
        extendName(suffix: "EdgelsDetector")
        super.configure()
    
        maxSize = 800
        
        //edgelsKernel.threadsPerThreadgroup = MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        edgelsKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        edgelsKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        
        erosion.dimensions = (Int(rasterSize),Int(rasterSize))
        dilation.dimensions = (Int(rasterSize/2),Int(rasterSize/2))
        blur.radius = 2

        add(filter: blur)
        
        add(filter: gaussianDerivative)
        //add(filter: dilation)
        //add(filter: erosion)

        add(function: edgelsKernel){ (result) in
            let count = Int(self.edegelSizeBuffer.contents().bindMemory(to: uint.self,
                                                                      capacity: MemoryLayout<uint>.size).pointee)
            
           // var edgels = [Edgel](repeating:Edgel(), count: count)
            
           // memcpy(&edgels, self.edegelSizeBuffer.contents(), MemoryLayout<Edgel>.size * count)

            print(" EDGELS count = \(count)")
            
        }
    }
    
    private lazy var gaussianDerivative:IMPGaussianDerivative = IMPGaussianDerivative(context: self.context)
    private lazy var blur:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var erosion:IMPErosion = IMPErosion(context: self.context)
    private lazy var dilation:IMPDilation = IMPDilation(context: self.context)
    
    private lazy var edegelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    private lazy var edegelArrayBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Edgel>.size * 64000, options: .storageModeShared)

    private lazy var edgelsKernel:IMPFunction = {
    
        let f = IMPFunction(context: self.context, kernelName: "kernel_edgels")
        f.optionsHandler = { (function, command, input, output) in
            
            memset(self.edegelSizeBuffer.contents(),0,MemoryLayout<uint>.size)
            
            command.setBytes(&self.rasterSize,length:MemoryLayout<uint>.size,at:0)
            command.setBuffer(self.edegelSizeBuffer, offset: 0, at: 1)
            command.setBuffer(self.edegelArrayBuffer, offset: 0, at: 2)
            if let texture = self.source?.texture {
                command.setTexture(texture, at: 2)
            }
        }
        return f
    }()
}
