//
//  IMPHistogramAnalyzer.swift
//  Pods
//
//  Created by Denis Svinarchuk on 29/06/2017.
//
//

import Foundation

public class IMPHistogramAnalyzer: IMPDetector{
    
    public var region = IMPRegion()
    
    public var histogram = IMPHistogram(){
        didSet{
            channelsToCompute = histogram.channels.count
        }
    }
    
    public override func configure(complete: IMPFilterProtocol.CompleteHandler?) {
        extendName(suffix: "HistogramAnalyzer")
        
        super.configure()
        
        partialHistogramKernel.threadsPerThreadgroup = MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        partialHistogramKernel.preferedDimension     = MTLSize(width: gridDimension.width*self.regionSize, height: gridDimension.height*self.regionSize, depth: 1)
        
        accumHistogramKernel.threadsPerThreadgroup   = MTLSize(width: histogram.size, height: 1, depth: 1)
        accumHistogramKernel.preferedDimension       = MTLSize(width: histogram.size * channelsToCompute, height: 1, depth: 1)
        
        addObserver(newSource: { (source) in
            if self.partialBuffer.length < MemoryLayout<IMPHistogramBuffer>.size * Int(self.numParts) {
                self.partialBuffer = self.partialBufferGetter()
            }
        })
        
        add(function: partialHistogramKernel)
        
        add(function: accumHistogramKernel) { (result) in
            self.histogram.update(data: self.completeBuffer.contents())
            complete?(result)
        }        
    }

    private var channelsToCompute:Int = 4 { didSet { dirty = true } }

    private lazy var partialHistogramKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_partialHistogram")
        
        f.optionsHandler = { (function, command, input, output) in
            command.setBuffer(self.partialBuffer,       offset: 0, at: 0)
            command.setBytes(&self.region, length: MemoryLayout.size(ofValue: self.region),   at: 1)
            var np = self.channelsToCompute;
            command.setBytes(&np, length: MemoryLayout.size(ofValue: np),   at: 2)
        }
        
        return f
    }()

    private lazy var accumHistogramKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_accumHistogram")
        
        f.optionsHandler = { (function, command, input, output) in
            command.setBuffer(self.partialBuffer,  offset: 0, at: 0)
            command.setBuffer(self.completeBuffer, offset: 0, at: 1)
            
            var np = self.numParts;
            command.setBytes(&np, length: MemoryLayout.size(ofValue: np),   at: 2)
            np = self.channelsToCompute;
            command.setBytes(&np, length: MemoryLayout.size(ofValue: np),   at: 3)
        }
        
        return f
    }()
    
    private var gridDimension:MTLSize {
        return MTLSize(width: 16, height: 16, depth: 1);
    }
    
    private var numParts:Int {
        return  gridDimension.width*gridDimension.height;
    }

    private func partialBufferGetter() -> MTLBuffer {
        //
        // to echange data should be .storageModeShared!!!!
        //
        return context.device.makeBuffer(length: MemoryLayout<IMPHistogramBuffer>.stride * numParts, options: .storageModeShared)
    }
    
    private lazy var partialBuffer:MTLBuffer = self.partialBufferGetter()

    private lazy var completeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramBuffer>.stride, options: .storageModeShared)

}
