//
//  IMPSegmentsDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 26.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal

public class IMPSegmentsDetector: IMPResampler{

    lazy var scanWidth:Int = 40
    
    lazy var scanLength:Int = {
        //return Int(sqrt(Float(self.segmentsKernel.maxThreads)))
        return self.segmentsKernelX.maxThreads/self.scanWidth
    }()
    
    public override var source: IMPImageProvider? {
        didSet{
            if let size = source?.size {
                let gw = (Int(size.width)+scanWidth-1)/scanWidth
                let gh = (Int(size.height)+scanWidth-1)/scanWidth
                segmentsKernelX.preferedDimension = MTLSize(width: gw, height: scanWidth, depth: 1)
                segmentsKernelY.preferedDimension = MTLSize(width: scanWidth, height: gh, depth: 1)
            }
        }
        
    }
    
    public override func configure() {
        extendName(suffix: "SegmentsDetector")
        super.configure()
        
        maxSize = 600
        
        dilation.dimensions = (Int(4),Int(4))
        erosion.dimensions = dilation.dimensions
        //blur.radius = 1.5
        
        segmentsKernelX.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        segmentsKernelY.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        //segmentsKernel.preferedDimension     = MTLSize(width: 400, height: self.scanWidth, depth: 1)

        gaussDerivativeEdges.pitch = 1

        //add(filter: blur)
        add(filter: erosion)
        add(filter: dilation)
        
        //add(filter: canny)
        
        add(filter: gaussDerivativeEdges)
        
        add(filter: sobelEdges)
        
        add(function: segmentsKernelX)
        //{ (result) in
        //    self.tmpTexture = result.texture
        //}
        add(function: segmentsKernelY)
    }
    
    private var tmpTexture:MTLTexture?
    
    private lazy var canny:IMPCannyEdges = IMPCannyEdges(context: self.context)

    private lazy var blur:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var erosion:IMPErosion = IMPErosion(context: self.context)
    private lazy var dilation:IMPDilation = IMPDilation(context: self.context)
    
    lazy var gaussDerivativeEdges:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    lazy var sobelEdges:IMPSobelEdges = IMPSobelEdges(context: self.context)

    lazy var segmentsKernelX:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_segmentsDetectorX")
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
    
    lazy var segmentsKernelY:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_segmentsDetectorY")
        f.optionsHandler = { (function, command, input, output) in
            //if let texture = self.tmpTexture {
            //    command.setTexture(texture, at: 2)
            //}
        }
        return f
    }()

}
