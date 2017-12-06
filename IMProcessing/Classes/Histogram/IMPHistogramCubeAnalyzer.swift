//
//  IMPColorCubeAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 28.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif


/// RGB-Cube update handler
public typealias IMPHistogramCubeUpdateHandler =  ((_ histogram:IMPHistogramCube) -> Void)

///  @brief RGB-Cube solver protocol uses to extend cube analizer computation
public protocol IMPHistogramCubeSolver {
    ///  Handler calls every times when analizer calculation completes.
    ///
    ///  - parameter analizer:  analizer wich did computation
    ///  - parameter histogram: current rgb-cube histogram
    ///  - parameter imageSize: image size
    func analizerDidUpdate(_ analizer: IMPHistogramCubeAnalyzer, histogram: IMPHistogramCube, imageSize: CGSize);
}


/// RGB-Cube histogram analizer calculates and prepares base RGB-Cube statistics such as color count and rgb-volumes an image distribution
open class IMPHistogramCubeAnalyzer: IMPFilter {
    
    /// Cube histogram
    open var histogram = IMPHistogramCube()
    
    /// To manage computation complexity you may downscale source image presentation inside the filter kernel function
    open var downScaleFactor:Float!{
        didSet{
            scaleUniformBuffer = scaleUniformBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: MTLResourceOptions())
            memcpy(scaleUniformBuffer.contents(), &downScaleFactor, scaleUniformBuffer.length)
            dirty = true
        }
    }
    
    /// Default colors clipping
    open static var defaultClipping = IMPHistogramCubeClipping(shadows: float3(0.2,0.2,0.2), highlights: float3(0.2,0.2,0.2))
    
    fileprivate var clippingBuffer:MTLBuffer!
    /// Clipping preferences
    open var clipping:IMPHistogramCubeClipping!{
        didSet{
            clippingBuffer = clippingBuffer ?? context.device.makeBuffer(length: MemoryLayout<IMPHistogramCubeClipping>.size, options: MTLResourceOptions())
            memcpy(clippingBuffer.contents(), &clipping, clippingBuffer.length)
            dirty = true
        }
    }
    
    fileprivate var scaleUniformBuffer:MTLBuffer!
    fileprivate var solvers:[IMPHistogramCubeSolver] = [IMPHistogramCubeSolver]()
    
    ///  Add to the analyzer new solver
    ///
    ///  - parameter solver: rgb-cube histogram solver
    open func addSolver(_ solver:IMPHistogramCubeSolver){
        solvers.append(solver)
    }
    
    /// Crop region defines wich region of the image should be explored.
    open var region:IMPRegion!{
        didSet{
            regionUniformBuffer = regionUniformBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<IMPRegion>.size, options: MTLResourceOptions())
            memcpy(regionUniformBuffer.contents(), &region, regionUniformBuffer.length)
            dirty = true
        }
    }
    internal var regionUniformBuffer:MTLBuffer!
    
    fileprivate var kernel_impHistogramCounter:IMPFunction!
    fileprivate var histogramUniformBuffer:MTLBuffer!
    fileprivate var threadgroups = MTLSize(width: 1, height: 1, depth: 1)
    fileprivate var threadgroupCounts = MTLSize(width: Int(kIMP_HistogramCubeThreads),height: 1,depth: 1)
    
    ///  Create RGB-Cube histogram analizer with new kernel
    ///
    ///  - parameter context:  device context
    ///  - parameter function: new rgb-cube histogram kernel
    ///
    public init(context: IMPContext, function: String) {
        super.init(context: context)
        
        kernel_impHistogramCounter = IMPFunction(context: self.context, name:function)
        
        let maxThreads:Int  = kernel_impHistogramCounter.pipeline!.maxTotalThreadsPerThreadgroup
        let actualWidth:Int = threadgroupCounts.width <= maxThreads ? threadgroupCounts.width : maxThreads
        
        threadgroupCounts.width = actualWidth 
        
        let groups = maxThreads/actualWidth
        
        threadgroups = MTLSizeMake(groups,1,1)
        
        histogramUniformBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramCubeBuffer>.size * Int(groups), options: MTLResourceOptions())
        
        self.addFunction(kernel_impHistogramCounter);
        
        defer{
            region = IMPRegion(left: 0, right: 0, top: 0, bottom: 0)
            downScaleFactor = 1.0
            clipping = IMPHistogramCubeAnalyzer.defaultClipping
        }
    }
    
    ///  Create RGB-Cube histogram analizer with standard kernel
    ///
    ///  - parameter context:  device context
    ///
    convenience required public init(context: IMPContext) {
        self.init(context:context, function: "kernel_impHistogramCubePartial")
    }
    
    ///  Add RGB-Cube histogram observer
    ///
    ///  - parameter observer: RGB-Cube update enclosure
    open func addUpdateObserver(_ observer:@escaping IMPHistogramCubeUpdateHandler){
        analizerUpdateHandlers.append(observer)
    }
    
    fileprivate var analizerUpdateHandlers:[IMPHistogramCubeUpdateHandler] = [IMPHistogramCubeUpdateHandler]()
    
    /// Source image frame
    open override var source:IMPImageProvider?{
        didSet{
            
            super.source = source
            
            if source?.texture != nil {
                // выполняем фильтр
                self.apply()
            }
        }
    }
    
    /// Destination image frame is equal the source frame
    open override var destination:IMPImageProvider?{
        get{
            return source
        }
    }
    
    internal func apply(_ texture:MTLTexture, buffer:MTLBuffer!) {
        
        self.context.execute { (commandBuffer) -> Void in
            
            #if os(iOS) 
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()
                blitEncoder?.__fill(buffer, range: NSMakeRange(0, buffer.length), value: 0)
                blitEncoder?.endEncoding()
            #else
                memset(buffer.contents(), 0, buffer.length)
            #endif
            
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()
            
            commandEncoder?.setComputePipelineState(self.kernel_impHistogramCounter.pipeline!);
            commandEncoder?.setTexture(texture, index:0)
            commandEncoder?.setBuffer(buffer, offset:0, index:0)
            commandEncoder?.setBuffer(self.regionUniformBuffer,    offset:0, index:1)
            commandEncoder?.setBuffer(self.scaleUniformBuffer,     offset:0, index:2)
            commandEncoder?.setBuffer(self.clippingBuffer,         offset:0, index:3)
            
            self.configure(self.kernel_impHistogramCounter, command: commandEncoder!)
            
            commandEncoder?.dispatchThreadgroups(self.threadgroups, threadsPerThreadgroup:self.threadgroupCounts);
            commandEncoder?.endEncoding()
        }
    }
    
    ///  Apply analyzer to the source frame. The method applyes every time automaticaly 
    ///  when any changes occur with the filter, or dirty property is set. 
    ///  Usually you don't need call the method except cases you sure you have to launch new computation.
    ///
    open override func apply() -> IMPImageProvider {
        
        if let texture = source?.texture{
            
            apply( texture, buffer: histogramUniformBuffer)
            
            histogram.update(data: histogramUniformBuffer.contents(), dataCount: threadgroups.width)
            
            for s in solvers {
                let size = CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height))
                s.analizerDidUpdate(self, histogram: self.histogram, imageSize: size)
            }
            
            for o in analizerUpdateHandlers{
                o(histogram)
            }
        }
        
        return source!
    }
}
