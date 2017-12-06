//
//  IMPHistogramLayer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 06.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPHistogramGenerator: IMPFilter{
    
    public typealias Layer = IMPHistogramLayer
    
    public var size:IMPSize!{
        didSet{
            if
                source?.texture?.width.cgfloat != size.width
                || 
                 source?.texture?.height.cgfloat != size.height
            {
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
                source = IMPImageProvider(context: context, texture: context.device.makeTexture(descriptor: desc)!)
            }
            destinationSize = MTLSize(cgsize: size)
        }
    }
    
    public static let defaultLayer = Layer(
        components: (
            IMPHistogramLayerComponent(color: float4([1,0,0,0.5]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,1,0,0.6]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0,0,1,0.7]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.8,0.8,0.8,0.8]), width: Float(UInt32.max))),
        backgroundColor: float4([0.1, 0.1, 0.1, 0.7]),
        backgroundSource: false,
        sample: false,
        separatorWidth: 0
    )
    
    public var layer = IMPHistogramGenerator.defaultLayer {
        didSet{
            layerUniformBiffer = layerUniformBiffer ?? self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramLayer>.size, options: [])
            memcpy(layerUniformBiffer.contents(), &layer, MemoryLayout<IMPHistogramLayer>.size)
        }
    }
    
    public required init(context: IMPContext, size:IMPSize) {
        super.init(context: context)
        
        defer{
            self.size = size
            layer = IMPHistogramGenerator.defaultLayer
        }
        
        kernel = IMPFunction(context: self.context, name: "kernel_histogramGenerator")
        self.addFunction(kernel)        
    }

    required public init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    public var histogram:IMPHistogram?{
        didSet{
            if let h = histogram {
                update(h)
            }
        }
    }
    
    func update(_ histogram: IMPHistogram){
        
        if histogramInputTexture.arrayLength != histogram.channels.count || histogramInputTexture.width != histogram.size {
            histogramInputTexture = context.device.texture1DArray(histogram.channels)
        }
        else {
            histogramInputTexture.update(histogram.channels)
        }
        self.dirty = true;
        self.apply()
    }
    
    
    override public func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if (kernel == function){
            command.setTexture(histogramInputTexture, index: 2)
            command.setBuffer(layerUniformBiffer,     offset: 0, index: 0)
        }
    }
    
    private lazy var histogramInputTexture:MTLTexture = {
        if let c = self.histogram?.channels {
            return self.context.device.texture1DArray(c)
        }
        return self.context.device.texture1DArray([[Float]](repeating:[Float](repeating:0,count:Int(kIMP_HistogramSize)),
                                                            count:4))
    }()
    
    private var kernel:IMPFunction!
    private var layerUniformBiffer:MTLBuffer!
}
