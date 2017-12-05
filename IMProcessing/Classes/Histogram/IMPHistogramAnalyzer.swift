//
//  IMPHistogramAnalyzer.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 07.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import Accelerate

///
/// Histogram updates handler.
///
public typealias IMPAnalyzerUpdateHandler =  ((_ histogram:IMPHistogram) -> Void)

///
/// Hardware uses to compute histogram.
///
public enum IMPHistogramAnalyzerHardware {
    case gpu
    case dsp
}

///
/// Common protocol defines histogram class API.
///
public protocol IMPHistogramAnalyzerProtocol:NSObjectProtocol,IMPFilterProtocol {
    
    var hardware:IMPHistogramAnalyzerHardware {get}
    var histogram:IMPHistogram {get set}
    var downScaleFactor:Float! {get set}
    var region:IMPRegion!  {get set}
    
    func addSolver(_ solver:  IMPHistogramSolver)
    func addUpdateObserver(_ observer:@escaping IMPAnalyzerUpdateHandler)
    
}

///
/// Histogram solvers protocol. Solvers define certain computations to calculate measurements metrics such as:
/// 1. histogram range (dynamic range)
/// 2. get peaks and valyes
/// 3. ... etc
///
public protocol IMPHistogramSolver {
    func analizerDidUpdate(_ analizer: IMPHistogramAnalyzerProtocol, histogram: IMPHistogram, imageSize: CGSize);
}


public extension IMPHistogramAnalyzerProtocol {
    public func setCenterRegionInPercent(_ value:Float){
        let half = value/2.0
        region = IMPRegion(
            left:   0.5 - half,
            right:  1.0 - (0.5+half),
            top:    0.5 - half,
            bottom: 1.0 - (0.5+half)
        )
    }
}


public extension IMPContext {
    public func hasFastAtomic() -> Bool {
        #if os(iOS)
            return self.device.supportsFeatureSet(.iOS_GPUFamily2_v1)
        #else
            return false
        #endif
    }
}

///
/// Histogram analizer uses to create IMPHistogram object from IMPImageProvider source.
///
open class IMPHistogramAnalyzer: IMPFilter,IMPHistogramAnalyzerProtocol {

    public typealias Hardware = IMPHistogramAnalyzerHardware

    ///
    /// Defines wich hardware uses to compute final histogram.
    /// DSP is faster but needs memory twice, GPU is slower but doesn't additanal memory.
    ///
    open var hardware:IMPHistogramAnalyzer.Hardware {
        return _hardware
    }
    var _hardware:IMPHistogramAnalyzer.Hardware!
    
    ///
    /// Histogram
    ///
    open var histogram = IMPHistogram(){
        didSet{
            channelsToCompute = UInt(histogram.channels.count)
        }
    }
    
    ///
    /// На сколько уменьшаем картинку перед вычисления гистограммы.
    ///
    open var downScaleFactor:Float!{
        didSet{
            scaleUniformBuffer = scaleUniformBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: MTLResourceOptions())
            memcpy(scaleUniformBuffer.contents(), &downScaleFactor, MemoryLayout<Float>.size)
            dirty = true
        }
    }
    fileprivate var scaleUniformBuffer:MTLBuffer!
    
    fileprivate var channelsToCompute:UInt?{
        didSet{
            channelsToComputeBuffer = channelsToComputeBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<UInt>.size, options: MTLResourceOptions())
            memcpy(channelsToComputeBuffer.contents(), &channelsToCompute, MemoryLayout<UInt>.size)
        }
    }
    fileprivate var channelsToComputeBuffer:MTLBuffer!
    
    fileprivate var solvers:[IMPHistogramSolver] = [IMPHistogramSolver]()
    
    ///
    /// Солверы анализирующие гистограмму в текущем инстансе
    ///
    open func addSolver(_ solver:IMPHistogramSolver){
        solvers.append(solver)
    }
    
    ///
    /// Регион внутри которого вычисляем гистограмму.
    ///
    open var region:IMPRegion!{
        didSet{
            regionUniformBuffer = regionUniformBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<IMPRegion>.size, options: MTLResourceOptions())
            memcpy(regionUniformBuffer.contents(), &region, MemoryLayout<IMPRegion>.size)
        }
    }
    internal var regionUniformBuffer:MTLBuffer!
    
    ///
    /// Кernel-функция счета
    ///
    open var kernel:IMPFunction {
        return _kernel
    }
    fileprivate var _kernel:IMPFunction!
    
    //
    // Буфер обмена контейнера счета с GPU
    //
    fileprivate var histogramUniformBuffer:MTLBuffer!
    
    //
    // Количество групп обсчета. Кратно <максимальное количество ядер>/размерность гистограммы.
    // Предполагаем, что количество ядер >= 256 - минимальной размерности гистограммы.
    // Расчет гистограммы просиходит в 3 фазы:
    // 1. GPU:kernel:расчет частичных гистограмм в локальной памяти, количество одновременных ядер == размерноси гистограммы
    // 2. GPU:kernel:сборка частичных гистограмм в глобальную блочную память группы
    // 3. CPU/DSP:сборка групп гистограм в финальную из частичных блочных
    //
    fileprivate var threadgroups = MTLSizeMake(8,8,1)
    
    ///
    /// Конструктор анализатора с произвольным счетчиком, который
    /// задаем kernel-функцией. Главное условие совместимость с типом IMPHistogramBuffer
    /// как контейнером данных гистограммы.
    ///
    ///
    public init(context: IMPContext, function: String, hardware:IMPHistogramAnalyzer.Hardware = .gpu) {
        super.init(context: context)
        
        _hardware = hardware

        _kernel = IMPFunction(context: self.context, name:function)
        
        if context.hasFastAtomic() || hardware == .dsp
        {
            histogramUniformBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramBuffer>.size, options: MTLResourceOptions())
        }
        else {
            let groups = kernel.pipeline!.maxTotalThreadsPerThreadgroup/histogram.size
            threadgroups = MTLSizeMake(groups,groups,1)
            histogramUniformBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPHistogramBuffer>.size * Int(threadgroups.width*threadgroups.height), options: MTLResourceOptions())
        }
        
        defer{
            region = IMPRegion(left: 0, right: 0, top: 0, bottom: 0)
            downScaleFactor = 1.0
            channelsToCompute = UInt(histogram.channels.count)
        }
    }
    
    convenience public init(context: IMPContext, hardware:IMPHistogramAnalyzer.Hardware) {
        
        var function = "kernel_impHistogramPartial"
        
        if hardware == .gpu {
            if context.hasFastAtomic() {
                function = "kernel_impHistogramAtomic"
            }
        }
        else {
            function = "kernel_impHistogramVImage"
        }
        
        self.init(context:context, function: function, hardware: hardware)
    }
    
    convenience required public init(context: IMPContext) {
        self.init(context:context, hardware: .gpu)
    }
    
    ///
    /// Замыкание выполняющаеся после завершения расчета значений солвера.
    /// Замыкание можно определить для обновления значений пользовательской цепочки фильтров.
    ///
    public func addUpdateObserver(_ observer:@escaping IMPAnalyzerUpdateHandler) {
        analizerUpdateHandlers.append(observer)
    }
    
    fileprivate var analizerUpdateHandlers:[IMPAnalyzerUpdateHandler] = [IMPAnalyzerUpdateHandler]()
    
    ///
    /// Перегружаем свойство источника: при каждом обновлении нам нужно выполнить подсчет новой статистики.
    ///
    open override var source:IMPImageProvider?{
        didSet{
            super.source = source
            if source?.texture != nil {
                // выполняем фильтр
                self.apply()
            }
        }
    }
    
    open override var destination:IMPImageProvider?{
        get{
            return source
        }
    }
    
    func applyKernel(_ texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer, commandBuffer:MTLCommandBuffer) {

        var blitEncoder = commandBuffer.makeBlitCommandEncoder()
        #if os(OSX)
            blitEncoder.synchronizeResource(texture)
        #endif
        blitEncoder.fill(buffer: buffer, range: NSMakeRange(0, buffer.length), value: 0)
        blitEncoder.endEncoding()
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        //
        // Создаем вычислительный пайп
        //
        commandEncoder.setComputePipelineState(self.kernel.pipeline!);
        commandEncoder.setTexture(texture, at:0)
        commandEncoder.setBuffer(buffer, offset:0, at:0)
        commandEncoder.setBuffer(self.channelsToComputeBuffer,offset:0, at:1)
        commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, at:2)
        commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, at:3)
        
        self.configure(self.kernel, command: commandEncoder)
        
        //
        // Запускаем вычисления
        //
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts);
        commandEncoder.endEncoding()
        
        #if os(OSX)
            blitEncoder = commandBuffer.blitCommandEncoder()
            blitEncoder.synchronizeResource(buffer)
            blitEncoder.endEncoding()
        #endif
    }
    
    func applyPartialKernel(_ texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        self.context.execute(complete: true) { (commandBuffer) -> Void in
            self.applyKernel(texture,
                threadgroups: threadgroups,
                threadgroupCounts: threadgroupCounts,
                buffer: buffer,
                commandBuffer: commandBuffer)
        }
        histogram.update(data:histogramUniformBuffer.contents(), dataCount: threadgroups.width*threadgroups.height)
    }
    
    func applyAtomicKernel(_ texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        context.execute(complete: true) { (commandBuffer) in
            self.applyKernel(texture,
                threadgroups: threadgroups,
                threadgroupCounts: threadgroupCounts,
                buffer: buffer,
                commandBuffer: commandBuffer)
        }
        histogram.update(data: buffer.contents())
    }
    
    fileprivate var analizeTexture:MTLTexture? = nil
    fileprivate var imageBuffer:MTLBuffer? = nil
    
    func applyVImageKernel(_ texture:MTLTexture, threadgroups:MTLSize, threadgroupCounts: MTLSize, buffer:MTLBuffer!) {
        
        context.execute(complete: true) { (commandBuffer) in
            
            let width  = Int(floor(Float(texture.width) * self.downScaleFactor))
            let height = Int(floor(Float(texture.height) * self.downScaleFactor))
            
            if self.analizeTexture?.width != width || self.analizeTexture?.height != height {
                let textureDescription = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rgba8Unorm,
                    width: width,
                    height:height, mipmapped: false)
                self.analizeTexture = self.context.device.makeTexture(descriptor: textureDescription)
            }
            
            if let actual = self.analizeTexture {
                
                let commandEncoder = commandBuffer.makeComputeCommandEncoder()
                
                commandEncoder.setComputePipelineState(self.kernel.pipeline!);
                commandEncoder.setTexture(texture, at:0)
                commandEncoder.setTexture(self.analizeTexture, at:1)
                commandEncoder.setBuffer(self.regionUniformBuffer,    offset:0, at:0)
                commandEncoder.setBuffer(self.scaleUniformBuffer,     offset:0, at:1)
                
                self.configure(self.kernel, command: commandEncoder)

                commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadgroupCounts);
                commandEncoder.endEncoding()
                
                let imageBufferSize = width*height*4
                
                if self.imageBuffer?.length != imageBufferSize {
                    self.imageBuffer = self.context.device.makeBuffer( length: imageBufferSize, options: MTLResourceOptions())
                }
                
                if let data = self.imageBuffer {
                    
                    let blitEncoder = commandBuffer.makeBlitCommandEncoder()
                    
                    #if os(OSX)
                    blitEncoder.synchronizeResource(actual)    
                    #endif
                    
                    blitEncoder.copy(from: actual,
                                                sourceSlice: 0,
                                                sourceLevel: 0,
                                                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                                sourceSize: MTLSize(width: width, height: height, depth: actual.depth),
                                                to: data,
                                                destinationOffset: 0,
                                                destinationBytesPerRow: width*4,
                                                destinationBytesPerImage: 0)
                    
                    #if os(OSX)
                        blitEncoder.synchronizeResource(actual)    
                    #endif

                    blitEncoder.endEncoding()
                    
                    var vImage = vImage_Buffer(
                        data: data.contents(),
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: width*4)
                    
                    vImageHistogramCalculation_ARGB8888(&vImage, self._vImage_hist, 0)
                    
                    self.histogram.update(red: self._vImage_red, green: self._vImage_green, blue: self._vImage_blue, alpha: self._vImage_alpha)
                }
            }
        }
    }

    static func _vImage_createChannel256() -> [vImagePixelCount] {
        return [vImagePixelCount](repeating: 0, count: Int(kIMP_HistogramSize))
    }
    
    typealias _vImagePointer = UnsafeMutablePointer<vImagePixelCount>
    typealias _vImagePointerOptional = UnsafeMutablePointer<vImagePixelCount>?
    
    let _vImage_red   = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_green = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_blue  = IMPHistogramAnalyzer._vImage_createChannel256()
    let _vImage_alpha = IMPHistogramAnalyzer._vImage_createChannel256()

    lazy var _vImage_rgba:[_vImagePointerOptional] = [
        _vImagePointer(mutating: self._vImage_red) as _vImagePointerOptional,
        _vImagePointer(mutating: self._vImage_green) as _vImagePointerOptional,
        _vImagePointer(mutating: self._vImage_blue) as _vImagePointerOptional,
        _vImagePointer(mutating: self._vImage_alpha) as _vImagePointerOptional]
    
    lazy var _vImage_hist:UnsafeMutablePointer<_vImagePointerOptional> = UnsafeMutablePointer<_vImagePointerOptional>(mutating: self._vImage_rgba)
    
    open func executeSolverObservers(_ texture:MTLTexture) {
        if observersEnabled {
            for s in solvers {
                let size = CGSize(width: CGFloat(texture.width), height: CGFloat(texture.height))
                s.analizerDidUpdate(self, histogram: self.histogram, imageSize: size)
            }
            
            for o in analizerUpdateHandlers{
                o(histogram)
            }
        }
    }
    
    func computeOptions(_ texture:MTLTexture) -> (MTLSize,MTLSize) {
        let width  = Int(floor(Float(texture.width) * self.downScaleFactor))
        let height = Int(floor(Float(texture.height) * self.downScaleFactor))
        
        let threadgroupCounts = MTLSizeMake(Int(self.kernel.groupSize.width), Int(self.kernel.groupSize.height), 1)
        
        let threadgroups = MTLSizeMake(
            (width  +  threadgroupCounts.width ) / threadgroupCounts.width ,
            (height + threadgroupCounts.height) / threadgroupCounts.height,
            1)
        
        return (threadgroups,threadgroupCounts)
    }
    
    open override func apply() -> IMPImageProvider {
        
        if let texture = source?.texture{
            
            if hardware == .gpu {
                
                if context.hasFastAtomic() {
                    let (threadgroups,threadgroupCounts) = computeOptions(texture)
                    applyAtomicKernel(texture,
                                      threadgroups: threadgroups,
                                      threadgroupCounts: threadgroupCounts,
                                      buffer: histogramUniformBuffer)
                }
                else {
                    applyPartialKernel(
                        texture,
                        threadgroups: threadgroups,
                        threadgroupCounts: MTLSizeMake(histogram.size, 1, 1),
                        buffer: histogramUniformBuffer)
                }
            }
                
            else if hardware == .dsp {
                let (threadgroups,threadgroupCounts) = computeOptions(texture)
                applyVImageKernel(texture,
                                  threadgroups: threadgroups,
                                  threadgroupCounts: threadgroupCounts,
                                  buffer: histogramUniformBuffer)
            }
            
            executeSolverObservers(texture)
        }
        
        //self.analizeTexture?.setPurgeableState(.Empty)
        //self.imageBuffer?.setPurgeableState(.Volatile)
        
        return source!
    }
}
