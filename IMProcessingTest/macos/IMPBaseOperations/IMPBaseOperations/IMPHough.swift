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
    
    public init(image:UnsafeMutablePointer<UInt8>,
                bytesPerRow:Int,
                width:Int,
                height:Int,
                threshold:Int) {
        self.threshold = threshold
        imageWidth = width
        imageHeight = height
        accumulator = Accumulator(imageWidth: width, imageHeight: height)
        slopes = [Int](repeating:0, count: accumulator.width)
        transform(image: image, bytesPerRow: bytesPerRow, width:width, height:height)
    }
    
    public func getLines() -> [IMPLineSegment] {
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
