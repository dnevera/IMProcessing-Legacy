//
//  IMPSegmentsDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 26.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal

public class IMPSegmentsDetector: IMPResampler{
    
    lazy var kernleSize:Int = {
        return Int(sqrt(Float(self.segmentsKernel.maxThreads)))
    }()
    
//    public override var source: IMPImageProvider? {
//        didSet{
//            if let size = source?.size {
//                let gw = (Int(size.width)+regionSize-1)/regionSize
//                let gh = (Int(size.height)+regionSize-1)/regionSize
//            }
//        }
//        
//    }
    
    public override func configure() {
        extendName(suffix: "SegmentsDetector")
        super.configure()
        
        erosion.dimensions = (Int(4),Int(4))
        dilation.dimensions = (Int(4/2),Int(4/2))
        blur.radius = 2
        

        add(filter: blur)
        add(filter: dilation)
        add(filter: erosion)

        add(filter: gaussDerivativeEdges)
        add(filter: sobelEdges)
        
        segmentsKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        segmentsKernel.preferedDimension     = MTLSize(width: self.kernleSize, height: self.kernleSize, depth: 1)

        add(function: segmentsKernel)
    }
    
    private lazy var blur:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var erosion:IMPErosion = IMPErosion(context: self.context)
    private lazy var dilation:IMPDilation = IMPDilation(context: self.context)

    
    lazy var gaussDerivativeEdges:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    lazy var sobelEdges:IMPSobelEdges = IMPSobelEdges(context: self.context)

    lazy var segmentsKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_segmentsDetector")
        f.optionsHandler = { (function, command, input, output) in
//            memset(self.edegelSizeBuffer.contents(),0,MemoryLayout<uint>.size)
//            
//            command.setBytes(&self.rasterSize,length:MemoryLayout<uint>.size,at:0)
//            command.setBuffer(self.edegelSizeBuffer, offset: 0, at: 1)
//            command.setBuffer(self.edegelArrayBuffer, offset: 0, at: 2)
//            if let texture = self.source?.texture {
//                command.setTexture(texture, at: 2)
//            }
        }
        return f

    }()
}
