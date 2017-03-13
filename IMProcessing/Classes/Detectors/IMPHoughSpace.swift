//
//  IMPHoughSpace.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 13/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

import Foundation

public class HoughSpace {
    
    
    public let imageWidth:Int
    public let imageHeight:Int
    public let bytesPerRow:Int
    public let image:UnsafeMutablePointer<UInt8>
    
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
        self.image = image
        
        imageWidth = width
        imageHeight = height

        self.rhoStep = rhoStep
        self.thetaStep = thetaStep
        self.minTheta = minTheta
        self.maxTheta = maxTheta
        
        transform(rho: rhoStep, theta: thetaStep, min_theta: minTheta, max_theta: maxTheta)
    }
    
    //
    // https://github.com/opencv/opencv/blob/master/modules/imgproc/src/hough.cpp
    //
    
    var _accum = [Int]()
    
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
    
    lazy var numrho:Int   = round(((self.imageWidth.float + self.imageHeight.float) * 2 + 1) / self.rhoStep).int
    lazy var _tabSin:[Float] = [Float](repeating:0, count:self.numangle)
    lazy var _tabCos:[Float] = [Float](repeating:0, count:self.numangle)
    
    public func transform(rho:Float, theta:Float, min_theta:Float, max_theta:Float) {
        
        // stage 1. fill accumulator
        
        numangle = round((max_theta - min_theta) / theta).int
        _accum = [Int](repeating:0, count:(numangle+2) * (numrho+2))
        
        for i in stride(from: 0, to: imageHeight, by: 1){
            for j in stride(from: 0, to: imageWidth, by: 1){
                                
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
            
            if rho < 0 { continue }
            
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
            
            let y1:Float = B == 0 ? imageHeight.float : C/B
            let x2:Float = A == 0 ? imageWidth.float : C/A
            
            let x1:Float = B == 0 ? x2 : 0
            let y2:Float = A == 0 ? y1 : 0
            
            let delim  = float2(imageWidth.float,imageHeight.float)
            let point1 = clamp(float2(x1,y1)/delim, min: float2(0), max: float2(1))
            let point2 = clamp(float2(x2,y2)/delim, min: float2(0), max: float2(1))
            
            let segment = IMPLineSegment(p0: point1, p1: point2)
            
            lines.append(segment)
        }

        return lines
    }
}
