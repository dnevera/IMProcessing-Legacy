//
//  IMPHistogramLayerSolver.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 18.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

//
// Depricated. IMPHistogramGenerator is used instead of th solver 
//
open class IMPHistogramLayerSolver: IMPFilter, IMPHistogramSolver {
    
    public enum IMPHistogramType{
        case pdf
        case cdf
    }
    
    open var layer = IMPHistogramLayer(
        components: (
            IMPHistogramLayerComponent(color: float4([1,0,0,0.5]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,1,0,0.6]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,0,1,0.7]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.8,0.8,0.8,0.8]), width: Float(UInt32.max))),
        backgroundColor: float4([0.1, 0.1, 0.1, 0.7]),
        backgroundSource: false,
        sample: false,
        separatorWidth: 0
        ){
        didSet{
            memcpy(layerUniformBiffer.contents(), &layer, layerUniformBiffer.length)
        }
    }
    
    open var histogramType:(type:IMPHistogramType,power:Float) = (type:.pdf,power:1){
        didSet{
            self.dirty = true;
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_histogramLayer")
        self.addFunction(kernel)
        channelsUniformBuffer = self.context.device.makeBuffer(length: MemoryLayout<UInt>.size, options: MTLResourceOptions())
        histogramUniformBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramFloatBuffer>.size, options: MTLResourceOptions())
        layerUniformBiffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramLayer>.size, options: MTLResourceOptions())
        memcpy(layerUniformBiffer.contents(), &layer, layerUniformBiffer.length)
    }
    
    open var histogram:IMPHistogram?{
        didSet{
            update(histogram!)
        }
    }
    
    func update(_ histogram: IMPHistogram){
        
        var pdf:IMPHistogram;
        
        switch(histogramType.type){
        case .pdf:
            pdf = histogram.pdf()
        case .cdf:
            pdf = histogram.cdf(1, power: histogramType.power)
        }
        
        for c in 0..<pdf.channels.count{
            let address =  histogramUniformBuffer.contents().assumingMemoryBound(to: Float.self) + c*pdf.size
            memcpy(address, pdf.channels[c], MemoryLayout<Float>.size*pdf.size)
        }
        
        var channels = pdf.channels.count
        memcpy(channelsUniformBuffer.contents(), &channels, MemoryLayout<UInt>.size)
        
        self.dirty = true;
    }
    
    open func analizerDidUpdate(_ analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize) {
        self.histogram = histogram
    }
    
    override open func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if (kernel == function){
            command.setBuffer(histogramUniformBuffer, offset: 0, index: 0)
            command.setBuffer(channelsUniformBuffer,  offset: 0, index: 1)
            command.setBuffer(layerUniformBiffer,     offset: 0, index: 2)
        }
    }
    
    fileprivate var kernel:IMPFunction!
    fileprivate var layerUniformBiffer:MTLBuffer!
    fileprivate var histogramUniformBuffer:MTLBuffer!
    fileprivate var channelsUniformBuffer:MTLBuffer!
}
