//
//  IMPLineSegment.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 25.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import simd
import Accelerate

public let IMPMinimumPoint:Float = FLT_EPSILON
public let IMPEPSPoint:Float = (1+FLT_EPSILON)

public struct IMPLineSegment: Equatable {
    
    public init(line: IMPPolarLine, size:NSSize) {
        let angle = line.theta
        let rho = line.rho
        
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
            y1 = B == 0 ? 1 : C/B/size.height.float
            x2 = 1
            
            x1 = B == 0 ? x2 : 0
            y2 = y1
        }
        else if B == 0 {
            y1 = 0
            x2 = A == 0 ? 1 : C/A/size.width.float
            
            x1 = x2
            y2 = A == 0 ? y1 : 1
        }
        else {
            if angle.degrees >= 45 && angle.degrees <= 135 {
                //y = (r - x cos(t)) / sin(t)
                x1 = 0
                y1 = (rho - x1 * a) / b / size.height.float
                
                x2 = size.width.float
                y2 = (rho - x2 * a) / b / size.height.float
                x2 /= size.width.float
                
            }
            else{
                //x = (r - y sin(t)) / cos(t);
                y1 = 0
                x1 = (rho - y1 * b) / a / size.width.float
                y2 = size.height.float
                x2 = (rho - y1 * b) / a / size.width.float
                y2 /= size.height.float
            }
        }
        
        let delim  = float2(1)
        self.p0 = clamp(float2(x1,y1)/delim, min: float2(0), max: float2(1))
        self.p1 = clamp(float2(x2,y2)/delim, min: float2(0), max: float2(1))                
    }
    
    public init(p0:float2,p1:float2){
        self.p0 = float2(p0.x,p0.y)
        self.p1 = float2(p1.x,p1.y)
    }
    
    public static func == (lhs: IMPLineSegment, rhs: IMPLineSegment) -> Bool {
        return lhs.p0 == rhs.p0 && lhs.p1 == rhs.p1
    }
    
    public let p0:float2
    public let p1:float2
    
    /// Standard form of line equation: Ax + By = C
    /// float3.x = A
    /// float3.y = B
    /// float3.z = C
    public var standardForm:float3 {
        get {
            var f = float3()
            f.x =  p0.y-p1.y
            f.y =  p1.x-p0.x
            f.z = -(p0.x*p1.y - p1.x*p0.y)
            return f
        }
    }
    
    ///  Standard form of line perpendicular the line
    ///
    ///  - parameter point:
    ///
    ///  - returns: standard form for line defined by normal vector of the line segment
    public func normalForm(toPoint point:float2) -> float3 {
        let form1 = standardForm
        
        let a1 = form1.x
        let b1 = form1.y
        
        var f = float3()
        f.x = -b1
        f.y = a1
        f.z = a1*point.y - b1*point.x
        
        return f
    }
    
    public func determinants(line:IMPLineSegment) -> (D:Float,Dx:Float,Dy:Float){
        return determinants(standardForm: line.standardForm)
    }
    
    public func determinants(standardForm form:float3) -> (D:Float,Dx:Float,Dy:Float){
        let form1 = standardForm
        let form2 = form
        
        let a1 = form1.x
        let b1 = form1.y
        let c1 = form1.z
        
        let a2 = form2.x
        let b2 = form2.y
        let c2 = form2.z
        
        let D = float2x2(rows: [
            float2(a1,b1),
            float2(a2,b2)
            ]).determinant
        
        let Dx = float2x2(rows: [
            float2(c1,b1),
            float2(c2,b2)
            ]).determinant
        
        let Dy = float2x2(rows: [
            float2(a1,c1),
            float2(a2,c2)
            ]).determinant
        
        return (D,Dx,Dy)
    }
    
    public var isParallelToX:Bool {
        return abs(p0.y - p1.y) <= IMPMinimumPoint
    }
    
    public var isParallelToY:Bool {
        return abs(p0.x - p1.x) <= IMPMinimumPoint
    }
    
    public func contains(point:float2) -> Bool {
        return abs(float3x3(rows: [
            float3(point.x,point.y,1),
            float3(p0.x,p0.y,1),
            float3(p1.x,p1.y,1)
            ]).determinant) <= IMPMinimumPoint
    }
    
    public func normalIntersection(point:float2) -> float2 {
        //
        // Solve equations:
        //
        //  ax + by = c
        //  a(y-y0) + b(x-x0) = 0
        //
        //  or
        //
        //  a1x + b1y = c2
        //  a2x + b2y = c2, where a2 = -b1, b2 = a1, c2 = a1y0 - b1x0
        //
        
        let form = normalForm(toPoint: point)
        
        let (D,Dx,Dy) = determinants(standardForm: form)
        
        return float2(Dx/D,Dy/D)
    }
    
    
    public func distanceTo(point:float2) -> float2 {
        return normalIntersection(point: point) - point
    }
    
    public func distanceTo(parallelLine line:IMPLineSegment) -> Float {
        if line.isParallel(toLine: self){
            let p = line.normalIntersection(point: p0)
            return distance(p0,p)
        }
        else {
            return Float.nan
        }
    }
    
    public func crossPoint(line:IMPLineSegment) -> float2 {
        //
        // a1*x + b1*y = c1 - self line
        // a2*x + b2*y = c2 - another line
        //
        let (D,Dx,Dy) = determinants(line: line)
        return float2(Dx/D,Dy/D)
    }
    
    public func isParallel(toLine line:IMPLineSegment) -> Bool {
        let form1 = self.standardForm
        let form2 = line.standardForm
        
        let a1 = form1.x
        let b1 = form1.y
        
        let a2 = form2.x
        let b2 = form2.y
        
        return abs(float2x2(rows: [
            float2(a1,b1),
            float2(a2,b2)
            ]).determinant) <= IMPMinimumPoint
    }
}
