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
                thetaStep:Float = Float.pi/180,
                minTheta:Float = 0,
                maxTheta:Float = Float.pi ) {
        
        self.bytesPerRow = bytesPerRow
        
        imageWidth = width
        imageHeight = height

        self.rhoStep = rhoStep
        self.thetaStep = thetaStep
        self.minTheta = minTheta
        self.maxTheta = maxTheta
        
        transform(image: image, rho: rhoStep, theta: thetaStep, min_theta: minTheta, max_theta: maxTheta)
    }

    public init(points:[float2],
                width:Int,
                height:Int,
                rhoStep:Float = 1,
                thetaStep:Float = Float.pi/180,
                minTheta:Float = 0,
                maxTheta:Float = Float.pi ) {
        
        self.bytesPerRow = width
        
        imageWidth = width
        imageHeight = height
        
        self.rhoStep = rhoStep
        self.thetaStep = thetaStep
        self.minTheta = minTheta
        self.maxTheta = maxTheta
        
        transform(points: points, rho: rhoStep, theta: thetaStep, min_theta: minTheta, max_theta: maxTheta)
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

    private func transform(image:UnsafeMutablePointer<UInt8>, rho:Float, theta:Float, min_theta:Float, max_theta:Float) {
        
        // stage 1. fill accumulator
                
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
    
    private func transform(points:[float2], rho:Float, theta:Float, min_theta:Float, max_theta:Float) {
        
        // stage 1. fill accumulator
        
        updateSettings()
        
        for p in points{
            for n in 0..<numangle {
                let x = p.x * imageWidth.float
                let y = p.y * imageHeight.float
                var r = round( x * _tabCos[n] + y * _tabSin[n] )
                
                r += (numrho.float - 1) / 2
                
                let index = (n+1) * (numrho+2) + r.int+1
                _accum[index] += 1
            }
        }
    }
    
    public func getLocalMaximums(threshold:Int = 50) -> [(index:Int,bins:Int)] {
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
        return _sorted_accum.sorted { return $0.1>$1.1 }
    }
    
    public func getPoint(from space:  [(index:Int,bins:Int)], at index: Int) -> (rho:Float,theta:Float,capcity:Int) {
        
        let scale:Float = 1/(numrho.float+2)

        let idx = space[index].index.float
        let n = floorf(idx * scale) - 1
        let f = (n+1) * (numrho.float+2)
        let r = idx - f - 1
        
        let rho = (r - (numrho.float - 1) * 0.5) * rhoStep
        let theta = minTheta + n * thetaStep
        
        return (rho,theta,space[index].bins)
    }
    
    public func getSquares(squaresMax:Int = 50, threshold:Int = 50, minDistance:Float = 20, distanceThreshold:Float=10, thetaTreshold:Float = Float.pi/180 * 5) -> [IMPQuad] {
        let space = getLocalMaximums(threshold: threshold)
        
        // stage 4. store the first min(total,linesMax) lines to the output buffer
        let sMax = min(squaresMax, space.count)
        
        var squares = [IMPQuad]()
        
        let t1 = Date()
        
        for i1 in 0..<sMax {
            
            let (rho1,theta1,cap1) = getPoint(from: space, at: i1)
            
            for i2 in 0..<sMax {
                
                if i1 == i2 { continue }
                
                let (rho2,theta2,cap2) = getPoint(from: space, at: i2)
                
                if abs(rho1-rho2) < minDistance { continue }
                
                if abs(rho1+rho2) < distanceThreshold {
                    if abs(theta1-theta2) < thetaTreshold ||
                        abs(theta1-(theta2-Float.pi)) < thetaTreshold ||
                        abs((theta1-Float.pi)-theta2) < thetaTreshold {
                        
                        print("  ->>> parallel[\(i1,i2)][\(cap1,cap2)] == rho1,rho2 = \(rho1+rho2) \(rho1,rho2) theta1,theta2 = \(theta1 * 180/Float.pi,theta2 * 180/Float.pi)")
                    }
                }
                
                if abs(abs(theta1-theta2) - Float.pi/2) < thetaTreshold {
                        //print("  -<<< ortho[\(i1,i2)][\(cap1,cap2)]    == rho1,rho2 = \(rho1+rho2) \(rho1,rho2) theta1,theta2 = \(theta1 * 180/M_PI.float,theta2 * 180/M_PI.float)")
                }
            }
            
            print("\n -- - - - - -- \n")
        }
        
        
        print(" squares time = \(-t1.timeIntervalSinceNow)")
        
        return squares
    }
    
    public func getLines(linesMax:Int = 50, threshold:Int = 50) -> [IMPLineSegment]  {
        
        let space = getLocalMaximums(threshold: threshold)
        
        // stage 4. store the first min(total,linesMax) lines to the output buffer
        let linesMax = min(linesMax, space.count)
        
        var lines = [IMPLineSegment]()

        for i in 0..<linesMax {

            let (rho,theta,_) = getPoint(from: space, at: i)
            
            let a = cos(theta)
            let b = sin(theta)
            
            let x0 = a * rho
            let y0 = b * rho
            
            let np = float2(x0,y0)
            
            let nv = IMPLineSegment(p0: float2(0), p1: np)
            
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
