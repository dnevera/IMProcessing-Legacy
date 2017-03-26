//
//  IMPEdgelsDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 24.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
import Accelerate


/**
 Sources: https://infi.nl/nieuws/marker-detection-for-augmented-reality-applications/blog/view/id/56/#article_2
 */

extension IMPEdgel : Equatable {
    public func isOrientationCompatible(_ cmp:IMPEdgel) -> Bool {
        return (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.38
    }
    
    public static func == (lhs: IMPEdgel, rhs: IMPEdgel) -> Bool {
        return lhs.position == rhs.position && lhs.slope == rhs.slope
    }
}


class LineSegment {
    
    static var maxEdgels = 5
    
    init() {}
    
    func atLine(_ cmp:IMPEdgel ) -> Bool {
        
        if( !start.isOrientationCompatible( cmp ) ) { return false }
        
        // distance to line: (AB x AC)/|AB|
        // A = r1
        // B = r2
        // C = cmp
        
        // AB ( r2.x - r1.x, r2.y - r1.y )
        // AC ( cmp.x - r1.x, cmp.y - r1.y )
        
        var cross = (end.position.x-start.position.x) * ( cmp.position.y-start.position.y)
        
        cross -= (end.position.y-start.position.y) * (cmp.position.x-start.position.x)
        
        let d1 = start.position.x-end.position.x
        let d2 = start.position.y-end.position.y
        
        let distance = cross / length(float2(d1, d2))
        
        return fabs(distance) < 0.75
    }
    
    func addSupport(_ cmp: IMPEdgel ) {
        supportEdgels.append(cmp)
    }
    
    func isOrientationCompatible(_ cmp: LineSegment) -> Bool {
        return  (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.92
    }
    
    func getIntersection(_ b: LineSegment ) -> float2 {
        var intersection = float2()
        
        let denom = ((b.end.position.y - b.start.position.y)*(end.position.x - start.position.x)) -
            ((b.end.position.x - b.start.position.x)*(end.position.y - start.position.y))
        
        let nume_a = ((b.end.position.x - b.start.position.x)*(start.position.y - b.start.position.y)) -
            ((b.end.position.y - b.start.position.y)*(start.position.x - b.start.position.x))
        
        let ua = nume_a / denom
        
        intersection.x = start.position.x + ua * (end.position.x - start.position.x)
        intersection.y = start.position.y + ua * (end.position.y - start.position.y)
        
        return intersection
    }
    
    var start = IMPEdgel()
    var end   = IMPEdgel()
    
    var slope = float2()
    var remove = false
    var start_corner = false
    var end_corner = false
    
    var supportEdgels = [IMPEdgel]()
    
    static func == (lhs: LineSegment, rhs: LineSegment) -> Bool {
        return (lhs.start.position.x == rhs.start.position.x &&
            lhs.start.position.y == rhs.start.position.y &&
            lhs.end.position.x == rhs.end.position.x &&
            lhs.end.position.y == rhs.end.position.y)
    }
    
    static func findLineSegment(edgelsIn:[IMPEdgel]) -> [LineSegment] {
        
        var edgels = edgelsIn
        
        var lineSegments = [LineSegment]()
        var lineSegmentInRun = LineSegment()
        
        repeat {
            lineSegmentInRun.supportEdgels.removeAll()
            
            for _ in 0..<25 {
                var r1 = IMPEdgel()
                var r2 = IMPEdgel()
                
                let max_iterations = 100
                var iteration = 0
                var ir1 = 0
                var ir2 = 0
                
                repeat {
                    ir1 = Int(arc4random_uniform(UInt32(edgels.count))) //(rand()%(edgels.size()));
                    ir2 = Int(arc4random_uniform(UInt32(edgels.count))) //(rand()%(edgels.size()));
                    
                    r1 = edgels[ir1]
                    r2 = edgels[ir2]
                    iteration += 1
                    
                } while ( ( ir1 == ir2 || !r1.isOrientationCompatible( r2 ) ) && iteration < max_iterations );
                
                if( iteration < max_iterations ) {

                    let lineSegment = LineSegment ()
                    
                    lineSegment.start = r1
                    lineSegment.end = r2
                    lineSegment.slope = r1.slope
                    
                    for o in edgels {
                        if lineSegment.atLine(o)  {
                            lineSegment.addSupport( o )
                        }
                    }
                    
                    if( lineSegment.supportEdgels.count > lineSegmentInRun.supportEdgels.count ) {
                        lineSegmentInRun = lineSegment
                    }
                }
            }
            
            // slope van de line bepalen
            if( lineSegmentInRun.supportEdgels.count >= LineSegment.maxEdgels ) {
                var u1:Float = 0
                var u2:Float = 50000
                let slope = (lineSegmentInRun.start.position - lineSegmentInRun.end.position)
                let orientation = float2( -lineSegmentInRun.start.slope.y, lineSegmentInRun.start.slope.x )
                
                if abs(slope.x) <= abs(slope.y) {
                    for it in lineSegmentInRun.supportEdgels {
                        
                        if (it.position.y > u1) {
                            u1 = it.position.y
                            lineSegmentInRun.start = it
                        }
                        
                        if (it.position.y < u2) {
                            u2 = it.position.y
                            lineSegmentInRun.end = it
                        }
                    }
                } else {
                    for it in lineSegmentInRun.supportEdgels {

                        if (it.position.x > u1) {
                            u1 = it.position.x
                            lineSegmentInRun.start = it
                        }
                        
                        if (it.position.x < u2) {
                            u2 = it.position.x
                            lineSegmentInRun.end = it
                        }
                    }
                }
                
                // switch startpoint and endpoint according to orientation of edge
                
                if dot( lineSegmentInRun.end.position - lineSegmentInRun.start.position, orientation ) < 0.0 {
                    swap( &lineSegmentInRun.start, &lineSegmentInRun.end )
                }
                
                lineSegmentInRun.slope = normalize(lineSegmentInRun.end.position - lineSegmentInRun.start.position)
                
                lineSegments.append( lineSegmentInRun )
                
                for i in 0..<lineSegmentInRun.supportEdgels.count{
                    for it in edgels {
                        if( it.position.x == lineSegmentInRun.supportEdgels[i].position.x &&
                            it.position.y == lineSegmentInRun.supportEdgels[i].position.y ) {
                            edgels.removeObject(object: it)
                            break
                        }
                    }
                }
            }
        } while( lineSegmentInRun.supportEdgels.count >= LineSegment.maxEdgels && edgels.count >= LineSegment.maxEdgels )
        
        return lineSegments
    }
}


public class IMPEdgelsDetector: IMPResampler{
    
    struct Edgel {
        var position = float2(0)
        var slope    = float2(0)
        
        func isOrientationCompatible(cmp:Edgel) -> Bool {
            return (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.38
        }
    }
    
    lazy var regionSize:Int = {
        return Int(sqrt(Float(self.edgelsKernel.maxThreads)))
    }()
    
    public override var source: IMPImageProvider? {
        didSet{
            if let size = source?.size {
                let gw = (Int(size.width)+regionSize-1)/regionSize
                let gh = (Int(size.height)+regionSize-1)/regionSize
                
                edegelSizeBuffer = context.device.makeBuffer(length: MemoryLayout<uint>.size * gw * gh,
                                                             options: .storageModeShared)
            }
            //memset(edegelSizeBuffer.contents(),0,MemoryLayout<uint>.size)
        }
    }
    
    public var rasterSize:uint = 5
    
    public override func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "EdgelsDetector")
        super.configure()
        
        maxSize = 400
        
        //edgelsKernel.threadsPerThreadgroup = MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        edgelsKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        edgelsKernel.preferedDimension =  MTLSize(width: self.regionSize, height: self.regionSize, depth: 1)
        
        erosion.dimensions = (Int(rasterSize),Int(rasterSize))
        dilation.dimensions = (Int(rasterSize/2),Int(rasterSize/2))
        blur.radius = 2
        
        //add(filter: blur)
        
        add(filter: gaussianDerivative)
        //add(filter: dilation)
        //add(filter: erosion)
        
        add(function: edgelsKernel){ (result) in
            
            guard let size = self.source?.size else { return }
            let gw = (Int(size.width)+self.regionSize-1)/self.regionSize
            let gh = (Int(size.height)+self.regionSize-1)/self.regionSize
            
            let t0 = Date()

            let count = gw * gh
            
            let mem = self.edegelSizeBuffer.contents().bindMemory(to: uint.self,
                                                                   capacity:  MemoryLayout<uint>.size * count)
            
            let amem = self.edegelArrayBuffer.contents().bindMemory(to: IMPEdgelList.self, capacity:  MemoryLayout<IMPEdgelList>.size * count)
            
            //var edgels = [IMPEdgelList](repeating:IMPEdgelList(), count:count)
            
            //memcpy(&edgels, self.edegelArrayBuffer.contents(), MemoryLayout<IMPEdgelList>.size * count)
            

            for x in 0..<gw{
                for y in 0..<gh{
                    let aid   = x + gw * y
                    let count = Int(mem[aid])
                    
                    if count > 5 {
                        
                        var t1 = Date()

                        //print("m[\(x,y)] = \(aid, count)")
                        var v = (amem + aid).pointee.array
                        
                        var edgels = [IMPEdgel](repeating:IMPEdgel(), count:count)
                        
                        memcpy(&edgels, &v, count * MemoryLayout<IMPEdgel>.size)
                        
                        //print(" ---- copy time = \(-t1.timeIntervalSinceNow)")

                        
                        t1 = Date()
                        
                        let segments = LineSegment.findLineSegment(edgelsIn: edgels)

                        print(" ---- findLineSegment time = \(-t1.timeIntervalSinceNow)")
                        print(" SEGMENTS count = \(segments.count)")
                        
                        if segments.count > 1 {
                            for (i,s) in segments.enumerated() {
                                print("s[\(i)] = \(s.start, s.end)")
                            }
                        }

                        //for e in edgels{
                         //   //let e = edgels[aid].array
                         //   print("\(e)")
                       // }
                    }
                }
            }
            
            print(" ---- total time = \(-t0.timeIntervalSinceNow)")

            
            //let count = Int(self.edegelSizeBuffer.contents().bindMemory(to: uint.self,
            //                                                            capacity: MemoryLayout<uint>.size).pointee)
            
            //let mem = self.edegelArrayBuffer.contents().bindMemory(to: IMPEdgel.self, capacity:  MemoryLayout<IMPEdgel>.size * count)
            
//            var edgels = [IMPEdgel](repeating:IMPEdgel(), count:count)
//            
//            memcpy(&edgels, self.edegelArrayBuffer.contents(), count)
//            
//            print(" EDGELS   count = \(count)")
//            
//            let segments = LineSegment.findLineSegment(edgelsIn: edgels)
//
//            print(" SEGMENTS count = \(segments.count)")
//
//            for (i,s) in segments.enumerated() {
//                print("s[\(i)] = \(s.start, s.end)")
//            }
        }
    }
    
    private lazy var gaussianDerivative:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    private lazy var blur:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var erosion:IMPErosion = IMPErosion(context: self.context)
    private lazy var dilation:IMPDilation = IMPDilation(context: self.context)
    
    private lazy var edegelSizeBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<uint>.size, options: .storageModeShared)
    private lazy var edegelArrayBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<IMPEdgelList>.size * 4096, options: .storageModeShared)
    
    private lazy var edgelsKernel:IMPFunction = {
        
        let f = IMPFunction(context: self.context, kernelName: "kernel_edgels")
        f.optionsHandler = { (function, command, input, output) in
            
            memset(self.edegelSizeBuffer.contents(),0,MemoryLayout<uint>.size)
            
            command.setBytes(&self.rasterSize,length:MemoryLayout<uint>.size,at:0)
            command.setBuffer(self.edegelSizeBuffer, offset: 0, at: 1)
            command.setBuffer(self.edegelArrayBuffer, offset: 0, at: 2)
            if let texture = self.source?.texture {
                command.setTexture(texture, at: 2)
            }
        }
        return f
    }()
}
