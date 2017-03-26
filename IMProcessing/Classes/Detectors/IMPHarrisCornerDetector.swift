//
//  IMPHarrisCornerDetector.swift
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal
import Accelerate


/** Harris corner detector
 
 First pass: reduce to luminance and take the derivative of the luminance texture (GPUImageXYDerivativeFilter)
 
 Second pass: blur the derivative (GaussianBlur)
 
 Third pass: apply the Harris corner detection calculation
 
 This is the Harris corner detector, as described in
 C. Harris and M. Stephens. A Combined Corner and Edge Detector. Proc. Alvey Vision Conf., Univ. Manchester, pp. 147-151, 1988.
 
 Sources:  https://github.com/BradLarson/GPUImage2
 
 */
public class IMPHarrisCornerDetector: IMPResampler{
    
    public typealias PointsListObserver = ((_ corners: [IMPCorner], _ imageSize:NSSize) -> Void)
    
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
    
    
    public var threshold:Float {
        set {
            nonMaximumSuppression.threshold = newValue
        }
        get{ return nonMaximumSuppression.threshold }
    }
    
    public var passImmediatelyProcessing = true
    
    public override var source: IMPImageProvider? {
        didSet{
            if passImmediatelyProcessing {
                self.process()
            }
        }
    }
    
    public override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "HarrisCornerDetector")
        
        super.configure()
        
        maxSize = 800
        blurRadius  = IMPHarrisCornerDetector.defaultBlurRadius
        sensitivity = IMPHarrisCorner.defaultSensitivity
        threshold   = IMPNonMaximumSuppression.defaultThreshold
        texelRadius = IMPHarrisCornerDetector.defaultTexelRadius
        
        pointsScannerKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        pointsScannerKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)

        addObserver(newSource: { (source) in
            
        })
        
        add(filter: xyDerivative) { (source) in
            self.derivativeTexture = source.texture
        }
        add(filter: blurFilter)
        add(filter: harrisCorner)
        add(filter: nonMaximumSuppression)
        
        add(function: pointsScannerKernel) { (result) in
            self.readCorners(result)
            complete?(result)
        }
    }
    
    fileprivate var derivativeTexture:MTLTexture?
    
    func pointsBufferGetter() -> MTLBuffer {
        //
        // to echange data should be .storageModeShared!!!!
        //
        return context.device.makeBuffer(length: MemoryLayout<IMPCorner>.size * Int(pointsMax), options: .storageModeShared)
    }
    
    public let pointsMax:uint = 4096
    fileprivate lazy var pointsBuffer:MTLBuffer = self.pointsBufferGetter()
    fileprivate lazy var pointsCountBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    
    lazy var edgeDetector:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)

    private lazy var xyDerivative:IMPXYDerivative = IMPXYDerivative(context: self.context)
    private lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var harrisCorner:IMPHarrisCorner = IMPHarrisCorner(context: self.context)
    private lazy var nonMaximumSuppression:IMPNonMaximumSuppression = IMPNonMaximumSuppression(context: self.context)
    
    private lazy var regionSize:Int = {
        return Int(sqrt(Float(self.pointsScannerKernel.maxThreads)))
    }()
    
    private lazy var pointsScannerKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_pointsScanner")
        
        f.optionsHandler = { (function, command, input, output) in
            
            memset(self.pointsCountBuffer.contents(),0,MemoryLayout<uint>.size)
            
            command.setBuffer(self.pointsBuffer,       offset: 0, at: 0)
            command.setBuffer(self.pointsCountBuffer,  offset: 0, at: 1)
            
            if let texture = self.derivativeTexture {
                command.setTexture(texture, at: 2)
            }

            var mmx = uint(self.pointsMax)
            command.setBytes(&mmx, length: MemoryLayout.size(ofValue: mmx),   at: 2)
        }
        
        return f
    }()

    
    private var isReading = false
    
    fileprivate func getPoints(_ countBuff:MTLBuffer, _ maximumsBuff:MTLBuffer) -> [IMPCorner] {
        
        let count = Int(countBuff.contents().bindMemory(to: uint.self,
                                                        capacity: MemoryLayout<uint>.size).pointee)
        
        var maximums = [IMPCorner](repeating:IMPCorner(), count:  count)
        
        memcpy(&maximums, maximumsBuff.contents(), MemoryLayout<IMPCorner>.size * count)
        
        return maximums.sorted { return $0.point.x<$1.point.x /*&& $0.point.y<$1.point.y*/ }
    }

    fileprivate func readCorners(_ destination: IMPImageProvider) {
        guard let size = destination.size else { return }
        
        let points = getPoints(pointsCountBuffer,pointsBuffer)
        
        for o in cornersObserverList {
            o(points,size)
        }
        
        
//        guard !isReading else { return }
//        
//        isReading = true
//        
//        guard let size = destination.size else { return }
//        
//        let width       = Int(size.width)
//        let height      = Int(size.height)
//        
//        if let (buffer,bytesPerRow,imageSize) = destination.read() {
//            let rawPixels = buffer.contents().bindMemory(to: UInt8.self, capacity: imageSize)
//
//            var corners = [float2]()
//        
//            for x in stride(from: 0, to: width, by: 1){
//                for y in stride(from: 0, to: height, by: 1){
//                    
//                    let colorByte = rawPixels[y * bytesPerRow + x * 4]
//                    
//                    if (colorByte > 0) {
//                        let xCoordinate = Float(x) / Float(width)
//                        let yCoordinate = Float(y) / Float(height)
//                        corners.append(float2(xCoordinate, yCoordinate))
//                    }
//                }
//            }
//            
//            for o in cornersObserverList {
//                o(corners,size)
//            }
//            isReading = false
//        }
    }
    
    func addObserver(corners observer: @escaping PointsListObserver) {
        cornersObserverList.append(observer)
    }
    
    private lazy var cornersObserverList = [PointsListObserver]()
}




public class IMPCornersDetector: IMPResampler {
    
    public typealias PointsListObserver = ((_ corners: [IMPCorner], _ imageSize:NSSize) -> Void)

    public var passImmediatelyProcessing = true

    public override var source: IMPImageProvider? {
        didSet{
            if passImmediatelyProcessing {
                self.process()
            }
        }
    }
    
    public override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "CornersDetector")
        
        maxSize = 400
        harrisCornerDetector.maxSize = nil
        harrisCornerDetector.passImmediatelyProcessing = false

        super.configure(){ (source) in
            print(" configure source size = \(source.size)")

            //self.edgeDetector.source = source
        }
        
        add(filter: harrisCornerDetector) { (result) in
            let pointsCountBuffer = self.harrisCornerDetector.pointsCountBuffer
            let count = Int(pointsCountBuffer.contents().bindMemory(to: uint.self,
                                                            capacity: MemoryLayout<uint>.size).pointee)
            
            self.regionScannerKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            self.regionScannerKernel.preferedDimension = MTLSize(width: count, height: 1, depth: 1)
        }
        
        add(function: regionScannerKernel){ (source) in
            print(" add source size = \(source.size)")
            self.readCorners(source)
            complete?(source)
        }
    }
    
    lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())
    
    //lazy var edgeDetector:IMPCannyEdges = IMPCannyEdges(context:  IMPContext())
    //lazy var edgeDetector:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    
    private lazy var regionScannerKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_pointsRegionScanner")
        
        f.optionsHandler = { (function, command, input, output) in
            
            command.setBuffer(self.harrisCornerDetector.pointsBuffer,      offset: 0, at: 0)
            command.setBuffer(self.harrisCornerDetector.pointsCountBuffer, offset: 0, at: 1)
            
            var mmx = uint(self.harrisCornerDetector.pointsMax)
            command.setBytes(&mmx, length: MemoryLayout.size(ofValue: mmx), at: 2)
            
            command.setBuffer(self.cornersBuffer, offset: 0, at: 3)

//            if let texture = self.edgeDetector.destination.texture {
//                command.setTexture(texture, at: 2)
//            }
            if let texture = self.harrisCornerDetector.derivativeTexture {
                command.setTexture(texture, at: 2)
            }

        }
        
        return f
    }()

    fileprivate lazy var cornersBuffer:MTLBuffer = self.context.device.makeBuffer(
        length: MemoryLayout<IMPCorner>.size * Int(self.harrisCornerDetector.pointsMax),
        options: .storageModeShared)

    
    fileprivate func getPoints(_ countBuff:MTLBuffer, _ maximumsBuff:MTLBuffer) -> [IMPCorner] {
        
        let count = Int(countBuff.contents().bindMemory(to: uint.self,
                                                        capacity: MemoryLayout<uint>.size).pointee)
        
        var maximums = [IMPCorner](repeating:IMPCorner(), count:  count)
        
        memcpy(&maximums, maximumsBuff.contents(), MemoryLayout<IMPCorner>.size * count)
        
        return maximums //.sorted { return $0.y>$1.y }
    }

    
    fileprivate func readCorners(_ destination: IMPImageProvider) {
        guard let size = destination.size else { return }
        
        let points = getPoints(harrisCornerDetector.pointsCountBuffer,cornersBuffer)
        
        for o in cornersObserverList {
            o(points,size)
        }
    }
    
    func addObserver(corners observer: @escaping PointsListObserver) {
        cornersObserverList.append(observer)
    }
    private lazy var cornersObserverList = [PointsListObserver]()

}
