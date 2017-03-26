//
//  IMPLinesDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 25.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal


public class IMPLinesDetector: IMPResampler {
    
    
    public typealias LinesListObserver = ((_ horisontal: [IMPPolarLine], _ vertical: [IMPPolarLine], _ imageSize:NSSize) -> Void)
    
    public override var source: IMPImageProvider? { didSet{ process() } }
    
    public override var maxSize:CGFloat? { didSet{ updateSettings() } }
    
    public var rhoStep:Float   = 1 { didSet{updateSettings()} }
    
    public var thetaStep:Float = M_PI.float/180.float{ didSet{updateSettings()} }
    
    public var minTheta:Float  = 0 { didSet{updateSettings()} }
    
    public var maxTheta:Float  = M_PI.float{ didSet{updateSettings()} }
    
    public var threshold:Int = 50 { didSet{dirty = true} }
    
    public var linesMax:Int = 175 { didSet{dirty = true} }
    
    public var radius:Int = 8 {
        didSet{
            erosion.dimensions = (radius,radius)
            dilation.dimensions = (radius,radius)
            dirty = true
        }
    }
    
    public override func configure(complete:CompleteHandler?=nil) {
        
        maxSize = 800
        //sobelEdges.rasterSize = 2
        erosion.dimensions = (radius,radius)
        dilation.dimensions = (radius,radius)
        
        extendName(suffix: "LinesDetector")
        super.configure()
        
        updateSettings()
        
        func linesHandlerCallback(){
            guard let size = edgesImage?.size else { return }
            let h = getLines(what: 0)
            let v = getLines(what: 1)
            if h.count > 0 || v.count > 0 {
                for l in linesObserverList {
                    l(h, v, size)
                }
            }
        }
        
        add(filter: dilation)
        add(filter: erosion)
        add(filter:gaussDerivativeEdges)
        
        add(filter:sobelEdges) { (result) in
            self.edgesImage = result
            self.updateSettings()
        }
        
        add(function:houghTransformKernel)
        
        add(function:houghSpaceLocalMaximumsKernel) { (result) in
            linesHandlerCallback()
            complete?(result)
        }
    }
    
    private var edgesImage:IMPImageProvider?
    
    lazy var regionSize:Int = {
        return Int(sqrt(Float(self.houghSpaceLocalMaximumsKernel.maxThreads)))
    }()
    
    private func updateSettings() {
        numangle = UInt32(round((maxTheta - minTheta) / thetaStep))
        if let size = edgesImage?.cgsize {
            
            numrho = UInt32(round(((size.width.float + size.height.float) * 2 + 1) / rhoStep))
            
            accumSize = (numangle+2) * (numrho+2)
            accumHorizonBuffer = self.accumBufferGetter()
            accumVerticalBuffer = self.accumBufferGetter()
            
            maximumsHorizonBuffer = self.maximumsBufferGetter()
            maximumsVerticalBuffer = self.maximumsBufferGetter()

            maximumsCountHorizonBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size,
                                                                        options: .storageModeShared)
            maximumsCountVerticalBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size,
                                                                         options: .storageModeShared)

            houghSpaceLocalMaximumsKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            houghSpaceLocalMaximumsKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
            
        }
    }
    
    private var accumSize:UInt32 = 0
    private var numangle:UInt32 = 0
    private var numrho:UInt32 = 0
    
    func accumBufferGetter() -> MTLBuffer {
        //
        // to echange data should be .storageModeShared!!!!
        //
        return context.device.makeBuffer(length: MemoryLayout<UInt32>.size * Int(accumSize), options: .storageModeShared)
    }
    
    func maximumsBufferGetter() -> MTLBuffer {
        //
        // to echange data should be .storageModeShared!!!!
        //
        return context.device.makeBuffer(length: MemoryLayout<uint2>.size * Int(accumSize), options: .storageModeShared)
    }
    
    
    private lazy var accumHorizonBuffer:MTLBuffer = self.accumBufferGetter()
    private lazy var accumVerticalBuffer:MTLBuffer = self.accumBufferGetter()
    
    private lazy var maximumsHorizonBuffer:MTLBuffer = self.maximumsBufferGetter()
    private lazy var maximumsVerticalBuffer:MTLBuffer = self.maximumsBufferGetter()
    
    private lazy var maximumsCountHorizonBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    private lazy var maximumsCountVerticalBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    
    private lazy var regionInBuffer:MTLBuffer  = self.context.makeBuffer(from: IMPRegion())
    
    private lazy var erosion:IMPMorphology = IMPErosion(context: self.context)
    private lazy var dilation:IMPMorphology = IMPDilation(context: self.context)

    private lazy var houghTransformKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_houghTransformAtomicOriented")
        
        f.optionsHandler = { (function, command, input, output) in
            
            command.setBuffer(self.accumHorizonBuffer,     offset: 0, at: 0)
            command.setBuffer(self.accumVerticalBuffer,     offset: 0, at: 1)
            command.setBytes(&self.numrho,    length: MemoryLayout.size(ofValue: self.numrho),   at: 2)
            command.setBytes(&self.numangle,  length: MemoryLayout.size(ofValue: self.numangle), at: 3)
            command.setBytes(&self.rhoStep,   length: MemoryLayout.size(ofValue: self.rhoStep),  at: 4)
            command.setBytes(&self.thetaStep, length: MemoryLayout.size(ofValue: self.thetaStep),at: 5)
            command.setBytes(&self.minTheta,  length: MemoryLayout.size(ofValue: self.minTheta), at: 6)
            command.setBuffer(self.regionInBuffer,  offset: 0, at: 7)
        }
        
        return f
    }()
    
    private lazy var houghSpaceLocalMaximumsKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_houghSpaceLocalMaximumsOriented")
        
        f.optionsHandler = { (function, command, input, output) in
            
            command.setBuffer(self.accumHorizonBuffer,         offset: 0, at: 0)
            command.setBuffer(self.accumVerticalBuffer,        offset: 0, at: 1)
            command.setBuffer(self.maximumsHorizonBuffer,      offset: 0, at: 2)
            command.setBuffer(self.maximumsVerticalBuffer,     offset: 0, at: 3)
            command.setBuffer(self.maximumsCountHorizonBuffer, offset: 0, at: 4)
            command.setBuffer(self.maximumsCountVerticalBuffer,offset: 0, at: 5)
            
            command.setBytes(&self.numrho,    length: MemoryLayout.size(ofValue: self.numrho),   at: 6)
            command.setBytes(&self.numangle,  length: MemoryLayout.size(ofValue: self.numangle), at: 7)
            command.setBytes(&self.threshold, length: MemoryLayout.size(ofValue: self.threshold), at: 8)
        }
        
        return f
    }()
    
    lazy var gaussDerivativeEdges:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    lazy var sobelEdges:IMPSobelEdges = IMPSobelEdges(context: self.context)
    //lazy var sobelEdges:IMPRasterizedSobelEdges = IMPRasterizedSobelEdges(context: self.context)
    
    private func getGPULocalMaximums(_ countBuff:MTLBuffer, _ maximumsBuff:MTLBuffer) -> [uint2] {
        
        let count = Int(countBuff.contents().bindMemory(to: uint.self,
                                                        capacity: MemoryLayout<uint>.size).pointee)
        var maximums = [uint2](repeating:uint2(0), count:  count)
        memcpy(&maximums, maximumsBuff.contents(), MemoryLayout<uint2>.size * count)
        return maximums.sorted { return $0.y>$1.y }
    }
    
    
    private func getLines(what:Int) -> [IMPPolarLine]  {
        guard var size = edgesImage?.size else {return []}
        
        let _sorted_accum = what == 0 ? getGPULocalMaximums(maximumsCountHorizonBuffer,maximumsHorizonBuffer) :
        getGPULocalMaximums(maximumsCountVerticalBuffer,maximumsVerticalBuffer)
        
        // stage 4. store the first min(total,linesMax) lines to the output buffer
        let linesMax = min(self.linesMax, _sorted_accum.count)
        
        let scale:Float = 1/(Float(numrho)+2)
        
        var lines = [IMPPolarLine]()
        
        var i = 0
        repeat {
            
            if i >= linesMax - 1 { break }
            
            let idx = Float(_sorted_accum[i].x)
            i += 1
            let n = floorf(idx * scale) - 1
            let f = (n+1) * (Float(numrho)+2)
            let r = idx - f - 1
            
            let rho = (r - (Float(numrho) - 1) * 0.5) * rhoStep
            
            if abs(rho) > sqrt(size.height.float * size.height.float + size.width.float * size.width.float){
                continue
            }
            
            let angle = minTheta + n * thetaStep
            
            let line = IMPPolarLine(rho: rho, theta: angle)
            
            lines.append(line)
            
        } while lines.count < linesMax && i < linesMax
        
        return lines
    }
    
    func addObserver(lines observer: @escaping LinesListObserver) {
        linesObserverList.append(observer)
    }
    
    private lazy var linesObserverList = [LinesListObserver]()
    
}
