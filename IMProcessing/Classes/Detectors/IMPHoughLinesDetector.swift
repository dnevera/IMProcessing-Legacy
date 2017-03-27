//
//  IMPHoughLinesDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 11.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal
import Darwin


//public protocol IMPHoughSpaceFilter{
//    var maxSize:CGFloat? {get set}
//    var blurRadius:Float {get set}
//}

fileprivate class IMPHoughSpaceCannyEdge:IMPCannyEdges{}

fileprivate class IMPHoughSpaceHarrisConner:IMPResampler{
    
    var blurRadius:Float {
        set{
            blurFilter.radius = newValue
            dirty = true
        }
        get { return blurFilter.radius }
    }
    
    override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "HoughSpace HarrisCornerDetector")
        
        super.configure()
        
        blurFilter.radius = 2
        xyDerivative.texelRadius = 1.5
        harrisCorner.sensitivity = 10
        nonMaximumSuppression.threshold = 0.2
        
        add(filter: xyDerivative)
        add(filter: blurFilter)
        add(filter: harrisCorner)
        add(filter: nonMaximumSuppression){ (source) in
            complete?(source)
        }
    }
    
    private lazy var xyDerivative:IMPXYDerivative = IMPXYDerivative(context: self.context)
    private lazy var blurFilter:IMPGaussianBlur = IMPGaussianBlur(context: self.context)
    private lazy var harrisCorner:IMPHarrisCorner = IMPHarrisCorner(context: self.context)
    private lazy var nonMaximumSuppression:IMPNonMaximumSuppression = IMPNonMaximumSuppression(context: self.context)
}


public class IMPHoughLinesDetector: IMPFilter {
    
    public enum Filtering {
        case edges
        case crossLines
    }
    
    private var filtering:Filtering
    
    public init(context: IMPContext, name: String? = nil, filtering:Filtering = .edges) {
        self.filtering = filtering
        super.init(context: context, name: name)
    }
    
    public required init(context: IMPContext, name: String?) {
        fatalError("IMPHoughLinesDetector.init(context:name:) could not been ovverided")
    }
    
    public typealias LinesListObserver = ((_ lines: [IMPPolarLine], _ imageSize:NSSize) -> Void)
    
    public override var source: IMPImageProvider? { didSet{ process() } }
    
    public var maxSize:CGFloat? {
        set{
            if filtering == .edges {
                cannyEdge.maxSize = newValue
            }
            else {
                crossLines.maxSize = newValue
            }
            updateSettings()
            dirty = true
        }
        get{ return filtering == .edges ? cannyEdge.maxSize : crossLines.maxSize }
    }
    
    public var blurRadius:Float {
        set{
            if filtering == .edges {
                cannyEdge.blurRadius = newValue
            }
            else {
                crossLines.blurRadius = newValue
            }
            dirty = true
        }
        get { return filtering == .edges ? cannyEdge.blurRadius : crossLines.blurRadius }
    }
    
    public var rhoStep:Float   = 1 { didSet{updateSettings()} }
    
    public var thetaStep:Float = M_PI.float/180.float{ didSet{updateSettings()} }
    
    public var minTheta:Float  = 0 { didSet{updateSettings()} }
    
    public var maxTheta:Float  = M_PI.float{ didSet{updateSettings()} }
    
    public var threshold:Int = 50 { didSet{process()} }
    
    public var linesMax:Int = 50 { didSet{process()} }

    public override func configure(complete:CompleteHandler?=nil) {
        
        if filtering == .edges {
            cannyEdge.maxSize = 800
            cannyEdge.blurRadius = 2
        }
        else {
            crossLines.maxSize = 800
            crossLines.blurRadius = 2
        }
        
        extendName(suffix: "HoughLinesDetector")
        super.configure()
        
        updateSettings()
        
        func linesHandlerCallback(){
            guard let size = edgesImage?.size else { return }
            let lines = getLines()
            if lines.count > 0 {
                for l in linesObserverList {
                    l(lines, size)
                }
            }
        }

        if filtering == .edges {
            add(filter:cannyEdge) { (result) in
                self.edgesImage = result
                self.updateSettings()
            }
        }
        else{
            add(filter: crossLines) { (result) in
                self.edgesImage = result
                self.updateSettings()
            }
        }
        
        add(function:houghTransformKernel)
        
        add(function:houghSpaceLocalMaximumsKernel) { (result) in
            //self.context.runOperation(.sync, {
                linesHandlerCallback()
            //})
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
            accumBuffer = self.accumBufferGetter()
            
            maximumsBuffer = self.maximumsBufferGetter()
            
            //let threads = houghSpaceLocalMaximumsKernel.threadsPerThreadgroup
            //houghSpaceLocalMaximumsKernel.preferedDimension = MTLSizeMake(Int(numrho)/threads.width,Int(numangle)/threads.height,1)
            
            houghSpaceLocalMaximumsKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            houghSpaceLocalMaximumsKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)

            maximumsCountBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size,
                                                                 options: .storageModeShared)
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
    
    
    private lazy var accumBuffer:MTLBuffer = self.accumBufferGetter()
    private lazy var maximumsBuffer:MTLBuffer = self.maximumsBufferGetter()
    private lazy var maximumsCountBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    private lazy var regionInBuffer:MTLBuffer  = self.context.makeBuffer(from: IMPRegion())
    
    private lazy var houghTransformKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_houghTransformAtomic")
        
        f.optionsHandler = { (function, command, input, output) in
            
            command.setBuffer(self.accumBuffer,     offset: 0, at: 0)
            command.setBytes(&self.numrho,    length: MemoryLayout.size(ofValue: self.numrho),   at: 1)
            command.setBytes(&self.numangle,  length: MemoryLayout.size(ofValue: self.numangle), at: 2)
            command.setBytes(&self.rhoStep,   length: MemoryLayout.size(ofValue: self.rhoStep),  at: 3)
            command.setBytes(&self.thetaStep, length: MemoryLayout.size(ofValue: self.thetaStep),at: 4)
            command.setBytes(&self.minTheta,  length: MemoryLayout.size(ofValue: self.minTheta), at: 5)
            command.setBuffer(self.regionInBuffer,  offset: 0, at: 6)
        }
        
        return f
    }()
    
    private lazy var houghSpaceLocalMaximumsKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_houghSpaceLocalMaximums")
        
        f.optionsHandler = { (function, command, input, output) in
            
            command.setBuffer(self.accumBuffer,         offset: 0, at: 0)
            command.setBuffer(self.maximumsBuffer,      offset: 0, at: 1)
            command.setBuffer(self.maximumsCountBuffer, offset: 0, at: 2)
            
            command.setBytes(&self.numrho,    length: MemoryLayout.size(ofValue: self.numrho),   at: 3)
            command.setBytes(&self.numangle,  length: MemoryLayout.size(ofValue: self.numangle), at: 4)
            command.setBytes(&self.threshold, length: MemoryLayout.size(ofValue: self.threshold), at: 5)
        }
        
        return f
    }()
    
    private lazy var cannyEdge:IMPCannyEdges = IMPCannyEdges(context: self.context)
    private lazy var crossLines:IMPHoughSpaceHarrisConner = IMPHoughSpaceHarrisConner(context: self.context)

//    private func getGPULocalMaximums() -> [uint2] {
//        
//        let count = Int(maximumsCountBuffer.contents().bindMemory(to: uint.self,
//                                                                  capacity: MemoryLayout<uint>.size).pointee)
//        
//        var maximums = [uint2](repeating:uint2(0), count:  count)
//        
//        memcpy(&maximums, maximumsBuffer.contents(), MemoryLayout<uint2>.size * count)
//        
//        return maximums.sorted { return $0.y>$1.y }
//    }
    
    private func getCPULocalMaximums() -> [uint2] {
        let _accum = self.accumBuffer.contents().bindMemory(to: UInt32.self, capacity: self.accumBuffer.length)
        
        // stage 2. find local maximums
        var _sorted_accum = [uint2]()
        
        for r in stride(from: 0, to: Int(numrho), by: 1) {
            for n in stride(from: 0, to: Int(numangle), by: 1){
                
                let base = (n+1) * (Int(numrho)+2) + r + 1
                let bins = Int(_accum[Int(base)])
                
                if bins == 0 { continue }
                
                if( bins > threshold &&
                    bins > Int(_accum[base - 1]) && bins >= Int(_accum[base + 1]) &&
                    bins > Int(_accum[base - Int(numrho) - 2]) && bins >= Int(_accum[base + Int(numrho) + 2]) ){
                    _sorted_accum.append(uint2(UInt32(base),UInt32(bins)))
                }
            }
        }
        
        // stage 3. sort
        return _sorted_accum.sorted { return $0.y>$1.y }
    }
    
    
    private func getGPULocalMaximums(_ countBuff:MTLBuffer, _ maximumsBuff:MTLBuffer) -> [uint2] {
        
        let count = Int(countBuff.contents().bindMemory(to: uint.self,
                                                        capacity: MemoryLayout<uint>.size).pointee)
        var maximums = [uint2](repeating:uint2(0), count:  count)
        memcpy(&maximums, maximumsBuff.contents(), MemoryLayout<uint2>.size * count)
        return maximums.sorted { return $0.y>$1.y }
    }
    

    
    private func getLines() -> [IMPPolarLine]  {
        guard var size = edgesImage?.size else {return []}
        
        let _sorted_accum = getGPULocalMaximums(maximumsCountBuffer,maximumsBuffer)
        
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

    
//    private func getLines() -> [IMPLineSegment]  {
//        guard var size = edgesImage?.size else {return []}
//        
//        let _sorted_accum = getGPULocalMaximums()
//        
//        // stage 4. store the first min(total,linesMax) lines to the output buffer
//        let linesMax = min(self.linesMax, _sorted_accum.count)
//        
//        let scale:Float = 1/(Float(numrho)+2)
//        
//        var lines = [IMPLineSegment]()
//        
//        for i in 0..<linesMax {
//            
//            let idx = Float(_sorted_accum[i].x)
//            let n = floorf(idx * scale) - 1
//            let f = (n+1) * (Float(numrho)+2)
//            let r = idx - f - 1
//            
//            let rho = (r - (Float(numrho) - 1) * 0.5) * rhoStep
//            
//            let angle = minTheta + n * thetaStep
//            
//            let a = cos(angle)
//            let b = sin(angle)
//            
//            let x0 = a * rho
//            let y0 = b * rho
//            
//            let np = float2(x0,y0)
//            
//            let nv = IMPLineSegment(p0: float2(0), p1: np)
//            
//            //
//            // a*x + b*y = c => floa3.x/y/z
//            // x = (c - b*y)/a
//            // y = (c - a*x)/b
//            //
//            let nf = nv.normalForm(toPoint: np)
//            
//            let A = round(nf.x)
//            let B = round(nf.y)
//            let C = round(nf.z)
//            
//            var x1:Float=0,y1:Float=0,x2:Float=0,y2:Float=0
//            
//            if A == 0 {
//                y1 = B == 0 ? 1 : C/B/size.height.float
//                x2 = 1
//                
//                x1 = B == 0 ? x2 : 0
//                y2 = y1
//            }
//            else if B == 0 {
//                y1 = 0
//                x2 = A == 0 ? 1 : C/A/size.width.float
//                
//                x1 = x2
//                y2 = A == 0 ? y1 : 1
//            }
//            else {
//                
//                x1 = 0
//                y1 = C/B / size.height.float
//                x2 = 1
//                y2 = (C - A*size.width.float)/B / size.height.float
//            }
//            
//            let delim  = float2(1)
//            let point1 = clamp(float2(x1,y1)/delim, min: float2(0), max: float2(1))
//            let point2 = clamp(float2(x2,y2)/delim, min: float2(0), max: float2(1))
//            
//            let segment = IMPLineSegment(p0: point1, p1: point2)
//            
//            lines.append(segment)
//        }
//        
//        return lines
//    }

    
//    private var isReading = false
//    
//    
//    private func readLines(_ destination: IMPImageProvider) {
//        
//        guard let size = destination.size else {
//            isReading = false
//            return
//        }
//
//        guard !isReading else {
//            isReading = false
//            return
//        }
//        isReading = true
//
//        let width       = Int(size.width)
//        let height      = Int(size.height)
//        
//        if let (buffer,bytesPerRow,imageSize) = destination.read() {
//            
//            let rawPixels = buffer.contents().bindMemory(to: UInt8.self, capacity: imageSize)
//            
//            print(" readLines width,height \(width,height)")
//            
//            let hough = IMPHoughSpace(image: rawPixels,
//                                   bytesPerRow: bytesPerRow,
//                                   width: width,
//                                   height: height)
//            
//            let lines = hough.getLines(threshold: 20)
//            
//            if lines.count > 0 {
//                for l in linesObserverList {
//                    l(lines, size)
//                }
//            }
//            
//        }
//        isReading = false
//    }

    func addObserver(lines observer: @escaping LinesListObserver) {
        linesObserverList.append(observer)
    }
    
    private lazy var linesObserverList = [LinesListObserver]()
    
}
