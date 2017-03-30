//
//  IMPCornerLinesDetector.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 30/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal


public class IMPCornerLinesDetector: IMPHoughSpaceDetector {
    
    public typealias LinesListObserver = ((_ horisontal: [IMPPolarLine], _ vertical: [IMPPolarLine], _ imageSize:NSSize) -> Void)
    
    public func addObserver(lines observer: @escaping LinesListObserver) {
        linesObserverList.append(observer)
    }
    
    
    public static let defaultBlurRadius:Float = 2
    public static let defaultTexelRadius:Float = 2
    
    public var blurRadius:Float {
        set{
            blurFilter.radius = newValue
            dirty = true
        }
        get { return blurFilter.radius }
    }
    
    public var texelRadius:Float {
        set{
            xyDerivative.texelRadius = newValue
            dirty = true
        }
        get { return xyDerivative.texelRadius }
    }
    
    public var sensitivity:Float {
        set{
            harrisCorner.sensitivity = newValue
        }
        get{ return harrisCorner.sensitivity }
    }
    
    
//    public var threshold:Float {
//        set {
//            nonMaximumSuppression.threshold = newValue
//        }
//        get{ return nonMaximumSuppression.threshold }
//    }
    
    
    //public var pointsMax:Int = 4096 { didSet{ pointsBuffer = self.pointsBufferGetter() } }
    public override func configure(complete:CompleteHandler?=nil) {
    
        blurRadius  = IMPCornerLinesDetector.defaultBlurRadius
        sensitivity = IMPHarrisCorner.defaultSensitivity
        nonMaximumSuppression.threshold   = IMPNonMaximumSuppression.defaultThreshold
        texelRadius = IMPCornerLinesDetector.defaultTexelRadius
        
        extendName(suffix: "LinesDetector")
        super.configure()
  
        
        updateSettings()
        
        func linesHandlerCallback(){
            guard let size = edgesImage?.size else { return }
            let h = getLines(accum: getGPULocalMaximums(maximumsCountHorizonBuffer,maximumsHorizonBuffer), size:size)
            let v = getLines(accum: getGPULocalMaximums(maximumsCountVerticalBuffer,maximumsVerticalBuffer), size:size)
            if h.count > 0 || v.count > 0 {
                for l in linesObserverList {
                    l(h, v, size)
                }
            }
        }
        
        add(filter: xyDerivative) { (source) in
            self.edgesImage = source
            self.updateSettings()
        }
        add(filter: blurFilter)
        add(filter: harrisCorner)
        add(filter: nonMaximumSuppression)
        
        add(function:houghTransformKernel)
        
        add(function:houghSpaceLocalMaximumsKernel) { (result) in
            linesHandlerCallback()
            complete?(result)
        }
    }
    
    
    internal override func updateSettings() {
        super.updateSettings()
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
    
    
    private lazy var xyDerivative:IMPXYDerivative = IMPXYDerivative(context: self.context)
    private lazy var blurFilter:IMPGaussianBlur = IMPGaussianBlur(context: self.context)
    private lazy var harrisCorner:IMPHarrisCorner = IMPHarrisCorner(context: self.context)
    private lazy var nonMaximumSuppression:IMPNonMaximumSuppression = IMPNonMaximumSuppression(context: self.context)

    private lazy var accumHorizonBuffer:MTLBuffer = self.accumBufferGetter()
    private lazy var accumVerticalBuffer:MTLBuffer = self.accumBufferGetter()
    
    private lazy var maximumsHorizonBuffer:MTLBuffer = self.maximumsBufferGetter()
    private lazy var maximumsVerticalBuffer:MTLBuffer = self.maximumsBufferGetter()
    
    private lazy var maximumsCountHorizonBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    private lazy var maximumsCountVerticalBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    
    private lazy var regionInBuffer:MTLBuffer  = self.context.makeBuffer(from: IMPRegion())
    
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
    
    private func getGPULocalMaximums(_ countBuff:MTLBuffer, _ maximumsBuff:MTLBuffer) -> [uint2] {
        
        let count = Int(countBuff.contents().bindMemory(to: uint.self,
                                                        capacity: MemoryLayout<uint>.size).pointee)
        var maximums = [uint2](repeating:uint2(0), count:  count)
        memcpy(&maximums, maximumsBuff.contents(), MemoryLayout<uint2>.size * count)
        return maximums.sorted { return $0.y>$1.y }
    }
    
    
    private lazy var linesObserverList = [LinesListObserver]()
}
