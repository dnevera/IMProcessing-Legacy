//
//  IMPHough.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 12.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public class Hough {
    
    public class Accumulator {
        public var bins:[Int]
        public let width:Int
        public let height:Int
        public let houghDistance:Float
        
        public func max(r:Int,t:Int) -> Int {
            return bins[(r*width) + t]
        }
        
        public init(imageWidth:Int, imageHeight: Int) {
            houghDistance = (sqrt(2.0) * Float( imageHeight>imageWidth ? imageHeight : imageWidth )) / 2.0
            width  = 180
            height = Int(houghDistance * 2)
            bins = [Int](repeating:0, count: Int(width) * Int(height))
        }
    }
    
    
    public var slopes:[Int]
    public let accumulator:Accumulator
    public let imageWidth:Int
    public let imageHeight:Int
    public let threshold:Int
    public let bytesPerRow:Int
    public let image:UnsafeMutablePointer<UInt8>
    
    public init(image:UnsafeMutablePointer<UInt8>,
                bytesPerRow:Int,
                width:Int,
                height:Int,
                threshold:Int) {
        
        self.threshold = threshold
        self.bytesPerRow = bytesPerRow
        self.image = image
        
        imageWidth = width
        imageHeight = height
        accumulator = Accumulator(imageWidth: width, imageHeight: height)
        slopes = [Int](repeating:0, count: accumulator.width)
        
        //transform(image: image, bytesPerRow: bytesPerRow, width:width, height:height)
        transform()
    }
    
    var lines = [IMPLineSegment]()
    
    //
    // https://github.com/opencv/opencv/blob/master/modules/imgproc/src/hough.cpp
    //
    
    // stage 1. fill accumulator

    var _accum = [Int]()
    
    public func transform(linesMax:Int = 50,
                          rho:Float = 1,
                          theta:Float = M_PI.float/180,
                          threshold:Int = 20,
                          min_theta:Float=0,
                          max_theta:Float=M_PI.float) {
        
        let numangle = round((max_theta - min_theta) / theta).int
        let numrho   = round(((imageWidth.float + imageHeight.float) * 2 + 1) / rho).int
        
        _accum = [Int](repeating:0, count:(numangle+2) * (numrho+2))
        
        var _tabSin = [Float](repeating:0, count:numangle)
        var _tabCos = [Float](repeating:0, count:numangle)
        let  irho:Float =  1 / rho
                
        var ang = min_theta
        for n in 0..<numangle {
            _tabSin[n] = sin(ang) * irho
            _tabCos[n] = cos(ang) * irho
            ang += theta
        }
        
        for i in stride(from: 0, to: imageHeight, by: 1){
            for j in stride(from: 0, to: imageWidth, by: 1){

                let colorByte = image[i * bytesPerRow + j * 4]
                
                if colorByte < 128 { continue }

                for n in 0..<numangle {
                    
                    var r = round( j.float * _tabCos[n] + i.float * _tabSin[n] )
                    r += (numrho.float - 1) / 2

                    let index = (n+1) * (numrho+2) + r.int+1
                    _accum[index] += 1
                }
            }
        }
        
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
        
        _sorted_accum = _sorted_accum.sorted { return $0.1>$1.1 }
        
        
        // stage 4. store the first min(total,linesMax) lines to the output buffer
        let linesMax = min(linesMax, _sorted_accum.count)
        
        let scale:Float = 1/(numrho.float+2)
        
        lines = [IMPLineSegment]()
        for i in 0..<linesMax {
            let idx = _sorted_accum[i].0.float
            let n = floorf(idx * scale) - 1
            let f = (n+1) * (numrho.float+2)
            let r = idx - f - 1
            
            let rho = (r - (numrho.float - 1) * 0.5) * rho
            
            if rho < 0 { continue }
            
            let angle = min_theta + n * theta
            
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

            let y1:Float = B == 0 ? imageHeight.float : C/B
            let x2:Float = A == 0 ? imageWidth.float : C/A

            let x1:Float = B == 0 ? x2 : 0
            let y2:Float = A == 0 ? y1 : 0

            let delim  = float2(imageWidth.float,imageHeight.float)
            let point1 = clamp(float2(x1,y1)/delim, min: float2(0), max: float2(1))
            let point2 = clamp(float2(x2,y2)/delim, min: float2(0), max: float2(1))
            
            let segment = IMPLineSegment(p0: point1, p1: point2)
            
            lines.append(segment)
            
            //print("line = \(angle * 180 / M_PI.float, rho) = normalForm \(A,B,C) segment = \(segment)")
        }
    }
    
    public func getLines() -> [IMPLineSegment]  {
        return lines
    }
    
    public func getLines__() -> [IMPLineSegment] {
        var lines = [IMPLineSegment]()
        
        if accumulator.bins.count == 0 { return lines }
        
        for r in stride(from: 0, to: accumulator.height, by: 1) {
            
            for t in stride(from: 0, to: accumulator.width, by: 1){
                
                //Is this point a local maxima (9x9)
                var max = accumulator.max(r: r, t: t)
                
                if max < threshold { continue }
                
                var exit = false
                for ly in stride(from: -4, through: 4, by: 1){
                    for lx in stride(from: -4, through: 4, by: 1) {
                        let newmax = accumulator.max(r: r+ly, t: t+lx)
                        if newmax > max {
                            max = newmax
                            exit = true
                            break
                        }
                        if exit { break }
                    }
                }
                
                if max > accumulator.max(r: r, t: t) { continue }
                
                
                var p0 = float2()
                var p1 = float2()
                
                let theta = Float(t) * M_PI.float / 180.0
                
                let rr = Float(r)
                let h  = Float(accumulator.height)/2
                let w  = Float(accumulator.width)/2
                
                if t >= 45 && t <= 135 {
                    //y = (r - x cos(t)) / sin(t)
                    let x1:Float = 0
                    let y1 = ((rr-h) - ((x1-w) * cos(theta))) / sin(theta) + h
                    let x2 = w
                    let y2 = ((rr-h) - ((x2 - w) * cos(theta))) / sin(theta) + h
                    p0 = float2(x1, y1)
                    p1 = float2(x2, y2)
                }
                else {
                    
                    //x = (r - y sin(t)) / cos(t);
                    let y1:Float = 0
                    let x1 = ((rr-h) - ((y1 - h) * sin(theta))) / cos(theta) + w
                    let y2 = h
                    let x2 = ((rr-h)) - ((y2 - h) * sin(theta)) / cos(theta) + w
                    p0 = float2(x1,y1)
                    p1 = float2(x2,y2)
                }
                
                let delim = float2(Float(imageWidth),Float(imageHeight))
                lines.append(IMPLineSegment(p0: p0/delim,
                                            p1: p1/delim))
            }
        }
        return lines
    }
    
    func transform(image:UnsafeMutablePointer<UInt8>, bytesPerRow:Int, width:Int, height:Int) {
        
        let center_x = Float(width)/2
        let center_y = Float(height)/2
        
        for x in stride(from: 0, to: width, by: 1){
            
            for y in stride(from: 0, to: height, by: 1){
                
                let colorByte = image[y * bytesPerRow + x * 4]
                
                if colorByte == 0 { continue }
                
                for t in stride(from: 0, to: accumulator.width, by: 1){
                    
                    let theta = t.float * M_PI.float / accumulator.width.float
                    
                    let r = (x.float - center_x ) * cos(theta) + (y.float - center_y) * sin(theta)
                    let index = ((round(r + accumulator.houghDistance) * accumulator.width.float)).int + t
                    accumulator.bins[index] += 1
                }
            }
        }
    }
}
