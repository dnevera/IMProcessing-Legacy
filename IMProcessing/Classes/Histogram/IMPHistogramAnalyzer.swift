//
//  IMPHistogramAnalyzer.swift
//  Pods
//
//  Created by Denis Svinarchuk on 29/06/2017.
//
//

import Foundation

public class IMPHistogramAnalyzer: IMPDetector{
    
    public var histogram = IMPHistogram(){
        didSet{
            channelsToCompute = UInt(histogram.channels.count)
        }
    }

    private var channelsToCompute:UInt = 4 { didSet { dirty = true } }
    
    open override var regionSize:Int {
        //let gz = context.maxThreads.width/histogram.size
        //return gz == 0 ? 1 : gz
        return Int(channelsToCompute)
    }
    
    public override func configure(complete: IMPFilterProtocol.CompleteHandler?) {
        extendName(suffix: "HistogramAnalyzer")
        
        super.configure()
        
        histogramKernel.threadsPerThreadgroup = MTLSize(width: histogram.size, height: 1, depth: 1)
        histogramKernel.preferedDimension     = MTLSize(width: regionSize, height: 1, depth: 1)

        print("IMPHistogramAnalyzer: \(histogram.size, regionSize)")
        
        add(function: histogramKernel) { (result) in
            print("IMPHistogramAnalyzer: \(self.histogram.size, self.regionSize)")
            //self.readCorners(result)
            complete?(result)
        }
    }
    
    private lazy var histogramKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_histogram")
        
        f.optionsHandler = { (function, command, input, output) in
        }
        
        return f
    }()

}
