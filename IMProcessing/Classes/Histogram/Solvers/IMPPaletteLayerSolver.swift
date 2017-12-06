//
//  IMPPalleteLayerSolver.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 31.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

/// Palette layer representasion in IMPFilter context
open class IMPPaletteLayerSolver: IMPFilter, IMPHistogramCubeSolver {

    /// Layer preferences
    open var layer = IMPPaletteLayerBuffer(backgroundColor: float4([0,0,0,1]), backgroundSource: false) {
        didSet{
            memcpy(layerBuffer.contents(), &layer, layerBuffer.length)
        }
    }
    
    /// Palette color number represents on layer.
    open var colorNumber:Int = 8
    
    /// Palette representaion handler
    open var paletteHandler:((_ cube:IMPHistogramCube.Cube, _ count:Int)->[float3])?
    
    ///  Create palette layer object
    ///
    ///  - parameter context: current IMPContext
    ///
    public required init(context: IMPContext) {
        super.init(context: context)
        
        layerBuffer = context.device.makeBuffer(bytes: &layer, length: MemoryLayout<IMPPaletteLayerBuffer>.size, options: MTLResourceOptions())
        
        palleteBuffer =  context.device.makeBuffer(length: MemoryLayout<IMPPaletteBuffer>.size, options: MTLResourceOptions())
        memset(palleteBuffer.contents(), 0, palleteBuffer.length)

        palleteCountBuffer = context.device.makeBuffer(length: MemoryLayout<uint>.size, options: MTLResourceOptions())
        memset(palleteCountBuffer.contents(), 0, palleteCountBuffer.length)
        
        kernel = IMPFunction(context: self.context, name: "kernel_paletteLayer")
        self.addFunction(kernel)
    }
    
    
    ///  Analizer handler
    ///
    ///  - parameter analizer:  analizer object
    ///  - parameter histogram: cube histogram object
    ///  - parameter imageSize: current image size
    open func analizerDidUpdate(_ analizer: IMPHistogramCubeAnalyzer, histogram: IMPHistogramCube, imageSize: CGSize) {
        
        var palette:[float3]
        if let handler = paletteHandler{
            palette = handler(histogram.cube,colorNumber)
        }
        else{
            palette      = histogram.cube.palette(count: colorNumber)
        }
        var paletteLayer = [IMPPaletteBuffer](repeating: IMPPaletteBuffer(color: vector_float4()), count: palette.count)
        
        for i in 0..<palette.count {
            paletteLayer[i].color = float4(rgb: palette[i], a: 1)
        }
        
        let length = palette.count * MemoryLayout<IMPPaletteBuffer>.size
        var count = palette.count
        
        memcpy(palleteCountBuffer.contents(), &count, palleteCountBuffer.length)

        if palleteBuffer?.length != length {
            palleteBuffer = nil
        }
        palleteBuffer =  palleteBuffer ?? context.device.makeBuffer(length: length, options: MTLResourceOptions())
        memcpy(palleteBuffer.contents(), &paletteLayer, palleteBuffer.length)
    }
    
    override open func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if (kernel == function){
            command.setBuffer(palleteBuffer, offset: 0, index: 0)
            command.setBuffer(palleteCountBuffer,  offset: 0, index: 1)
            command.setBuffer(layerBuffer,     offset: 0, index: 2)
        }
    }
    
    fileprivate var kernel:IMPFunction!
    fileprivate var palleteBuffer:MTLBuffer!
    fileprivate var palleteCountBuffer:MTLBuffer!
    fileprivate var layerBuffer:MTLBuffer!

}
