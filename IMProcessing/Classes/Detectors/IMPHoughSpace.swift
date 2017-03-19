//
//  IMPHoughSpace.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 13/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPHoughSpace {
    
    
    public let imageWidth:Int
    public let imageHeight:Int
    public let bytesPerRow:Int
    
    public let rhoStep:Float
    public let thetaStep:Float
    public let minTheta:Float
    public let maxTheta:Float
    
    public init(image:UnsafeMutablePointer<UInt8>,
                bytesPerRow:Int,
                width:Int,
                height:Int,
                rhoStep:Float = 1,
                thetaStep:Float = M_PI.float/180,
                minTheta:Float = 0,
                maxTheta:Float = M_PI.float ) {
        
        self.bytesPerRow = bytesPerRow
        //self.image = image
        
        imageWidth = width
        imageHeight = height

        self.rhoStep = rhoStep
        self.thetaStep = thetaStep
        self.minTheta = minTheta
        self.maxTheta = maxTheta
        
        transform(image: image, rho: rhoStep, theta: thetaStep, min_theta: minTheta, max_theta: maxTheta)
    }

    public init?(image:IMPImageProvider,
                rhoStep:Float = 1,
                thetaStep:Float = M_PI.float/180,
                minTheta:Float = 0,
                maxTheta:Float = M_PI.float ) {
        
        if let texture = image.texture?.pixelFormat != .rgba8Uint ?
            image.texture?.makeTextureView(pixelFormat: .rgba8Uint) :
            image.texture
        {
            imageWidth       = Int(texture.size.width)
            imageHeight      = Int(texture.size.height)
            
            self.bytesPerRow   = imageWidth * 4
        }
        else {
            return nil
        }
        
        self.rhoStep = rhoStep
        self.thetaStep = thetaStep
        self.minTheta = minTheta
        self.maxTheta = maxTheta

        updateSettings()
        
        let context = image.context
        var buffers = [MTLBuffer?]()
        
        //let accumBuffer     = context.device.makeBuffer(bytes: _accum, length: MemoryLayout<Int>.size * _accum.count, options: [.storageModeShared]) //context.makeBuffer(from: _accum)
        let accumBuffer     = context.device.makeBuffer(bytes: _accum, length: MemoryLayout<Int>.size * _accum.count, options: .storageModeManaged)
        let accumSizeBuffer = context.makeBuffer(from: _accum.count)
        let numrhoBuffer    = context.makeBuffer(from: numrho)
        let numangleBuffer  = context.makeBuffer(from: numangle)
        let rhoStepBuffer   = context.makeBuffer(from: rhoStep)
        let thetaStepBuffer = context.makeBuffer(from: thetaStep)
        let minThetaBuffer  = context.makeBuffer(from: minTheta)
        let regionInBuffer  = context.makeBuffer(from: IMPRegion())
     
        buffers.append(accumBuffer)
        buffers.append(accumSizeBuffer)
        buffers.append(numrhoBuffer)
        buffers.append(numangleBuffer)
        buffers.append(rhoStepBuffer)
        buffers.append(thetaStepBuffer)
        buffers.append(minThetaBuffer)
        buffers.append(regionInBuffer)
        
        let bufferOffsets = [Int](repeating: 0, count: buffers.count)

        let houghTransformKernel:IMPFunction = IMPFunction(context: context, kernelName: "kernel_houghTransformAtomic")

        houghTransformKernel.optionsHandler = { (function:IMPFunction, command:MTLComputeCommandEncoder, source:MTLTexture?, destination:MTLTexture?) -> Void in
            //command.setBuffers(buffers, offsets: bufferOffsets, with: NSRange(location: 0,length: buffers.count))
            command.setBuffer(accumBuffer,     offset: 0, at: 0)
            command.setBuffer(accumSizeBuffer, offset: 0, at: 1)
            command.setBuffer(numrhoBuffer,    offset: 0, at: 2)
            command.setBuffer(numangleBuffer,  offset: 0, at: 3)
            command.setBuffer(rhoStepBuffer,   offset: 0, at: 4)
            command.setBuffer(thetaStepBuffer, offset: 0, at: 5)
            command.setBuffer(minThetaBuffer,  offset: 0, at: 6)
            command.setBuffer(regionInBuffer,  offset: 0, at: 7)
            print("  -------  1")
        }
        
        let filter = IMPFilter(context: context)

        filter.add(function: houghTransformKernel)
        filter.source = image

        print("  -------  2")

        let dest = filter.destination
        
        //filter.addObserver(destinationUpdated:{ (destination) in
        filter.context.execute(action: { (commandBuffer) in
            let blit = commandBuffer.makeBlitCommandEncoder()
            blit.synchronize(resource: accumBuffer)
            blit.endEncoding()
            print("  -------  3")
        })

        print("  -------  4")

        memcpy(&_accum, accumBuffer.contents(), _accum.count * MemoryLayout<Int>.size)
        
        print(" accum = \(self._accum[0], self._accum[1])")
        //})
        //filter.process()
    }
    
    private func updateSettings() {
        numangle = round((self.maxTheta - self.minTheta) / self.thetaStep).int
        _accum = [Int](repeating:0, count:(numangle+2) * (numrho+2))
    }
    
    //
    // https://github.com/opencv/opencv/blob/master/modules/imgproc/src/hough.cpp
    //
    
    private var _accum = [Int]()
    
    var numangle:Int = 0 {
        didSet{
            let n = round((self.maxTheta - self.minTheta) / self.thetaStep).int
            
            let  irho:Float =  1 / self.rhoStep
            
            var ang = self.minTheta
            for n in 0..<n {
                self._tabSin[n] = sin(ang) * irho
                self._tabCos[n] = cos(ang) * irho
                ang += self.thetaStep
            }
        }
    }
    
    private lazy var numrho:Int   = round(((self.imageWidth.float + self.imageHeight.float) * 2 + 1) / self.rhoStep).int
    private lazy var _tabSin:[Float] = [Float](repeating:0, count:self.numangle)
    private lazy var _tabCos:[Float] = [Float](repeating:0, count:self.numangle)
    //private let image:UnsafeMutablePointer<UInt8>

    private func transform(image:UnsafeMutablePointer<UInt8>, rho:Float, theta:Float, min_theta:Float, max_theta:Float) {
        
        // stage 1. fill accumulator
        
        //numangle = round((max_theta - min_theta) / theta).int
        //_accum = [Int](repeating:0, count:(numangle+2) * (numrho+2))
        
        updateSettings()
        
        for j in stride(from: 0, to: imageWidth, by: 1){
            for i in stride(from: 0, to: imageHeight, by: 1){
                
                if image[i * bytesPerRow + j * 4] < 128 { continue }
                
                for n in 0..<numangle {
                    
                    var r = round( j.float * _tabCos[n] + i.float * _tabSin[n] )
                    r += (numrho.float - 1) / 2
                    
                    let index = (n+1) * (numrho+2) + r.int+1
                    _accum[index] += 1
                }
            }
        }
        
    }
    
    public func getLines(linesMax:Int = 50, threshold:Int = 50) -> [IMPLineSegment]  {
        
        // stage 2. find local maximums
        var _sorted_accum = [(Int,Int)]()
        
        for r in stride(from: 0, to: numrho, by: 1) {
            for n in stride(from: 0, to: numangle, by: 1){
                
                let base = (n+1) * (numrho+2) + r+1
                let bins = _accum[base]
                if( bins > threshold &&
                    bins > _accum[base - 1] && bins >= _accum[base + 1] &&
                    bins > _accum[base - numrho - 2] && bins >= _accum[base + numrho + 2] ){
                }
                _sorted_accum.append((base,bins))
            }
        }
        
        // stage 3. sort
        _sorted_accum = _sorted_accum.sorted { return $0.1>$1.1 }

        
        // stage 4. store the first min(total,linesMax) lines to the output buffer
        let linesMax = min(linesMax, _sorted_accum.count)
        
        let scale:Float = 1/(numrho.float+2)
        
        var lines = [IMPLineSegment]()

        for i in 0..<linesMax {
            let idx = _sorted_accum[i].0.float
            let n = floorf(idx * scale) - 1
            let f = (n+1) * (numrho.float+2)
            let r = idx - f - 1
            
            let rho = (r - (numrho.float - 1) * 0.5) * rhoStep
            
            //if rho < 0 { continue }
            
            let angle = minTheta + n * thetaStep
            
            let a = cos(angle)
            let b = sin(angle)
            
            let x0 = a * rho
            let y0 = b * rho
            
            let np = float2(x0,y0)
            
            let nv = IMPLineSegment(p0: float2(0), p1: np)
            
            //
            // a*x + b*y = c => floa3.x/y/z
            // x = (c - b*y)/a
            // y = (c - a*x)/b
            //
            let nf = nv.normalForm(toPoint: np)
            
            let A = round(nf.x)
            let B = round(nf.y)
            let C = round(nf.z)
            
            var x1:Float=0,y1:Float=0,x2:Float=0,y2:Float=0
            
            if A == 0 {
                y1 = B == 0 ? 1 : C/B/imageHeight.float
                x2 = 1
                
                x1 = B == 0 ? x2 : 0
                y2 = y1
            }
            else if B == 0 {
                y1 = 0
                x2 = A == 0 ? 1 : C/A/imageWidth.float
                
                x1 = x2
                y2 = A == 0 ? y1 : 1
            }
            else {
                
                x1 = 0
                y1 = C/B / imageHeight.float
                x2 = 1
                y2 = (C - A*imageWidth.float)/B / imageHeight.float
            }
            
            let delim  = float2(1)// float2(imageWidth.float,imageHeight.float)
            let point1 = clamp(float2(x1,y1)/delim, min: float2(0), max: float2(1))
            let point2 = clamp(float2(x2,y2)/delim, min: float2(0), max: float2(1))
            
            let segment = IMPLineSegment(p0: point1, p1: point2)
            
            lines.append(segment)
        }

        return lines
    }
}
