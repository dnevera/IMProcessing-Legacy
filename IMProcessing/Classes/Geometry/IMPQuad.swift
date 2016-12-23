//
//  IMPQuad.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 04.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation
import simd
import Accelerate

public let IMPMinimumPoint:Float = FLT_EPSILON
public let IMPEPSPoint:Float = (1+FLT_EPSILON)

public struct IMPLineSegment {
    
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
    
    public func determinants(line line:IMPLineSegment) -> (D:Float,Dx:Float,Dy:Float){
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

    public init(p0:float2,p1:float2){
        self.p0 = float2(p0.x,p0.y)
        self.p1 = float2(p1.x,p1.y)
    }
    
    public func contains(point point:float2) -> Bool {
        return abs(float3x3(rows: [
            float3(point.x,point.y,1),
            float3(p0.x,p0.y,1),
            float3(p1.x,p1.y,1)
            ]).determinant) <= IMPMinimumPoint
    }
        
    public func normalIntersection(point point:float2) -> float2 {
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

    
    public func distanceTo(point point:float2) -> float2 {
        return normalIntersection(point: point) - point
    }
    
    public func distanceTo(parallelLine line:IMPLineSegment) -> Float {
        if line.isParallel(toLine: self){
            let p = line.normalIntersection(point: p0)
            return distance(p0,p)
        }
        else {
            return Float.NaN
        }
    }
    
    public func crossPoint(line line:IMPLineSegment) -> float2 {
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

public struct IMPTriangle {
    
    public let p0:float2
    public let pc:float2 // base vertex, center of transformation
    public let p1:float2
    
    public let aspect:Float
    
    public init(p0:float2,pc:float2,p1:float2, aspect:Float = 1){
        self.aspect = aspect
        self.p0 = float2(p0.x*aspect,p0.y)
        self.pc = float2(pc.x*aspect,pc.y)
        self.p1 = float2(p1.x*aspect,p1.y)
    }
    
    public func contains(point:float2) -> Bool {
        return IMPLineSegment(p0: p0, p1: pc).contains(point: point) || IMPLineSegment(p0: pc, p1: p1).contains(point: point)
    }
    
    public func normalIntersections(point point:float2) -> [float2] {
        let line0 = IMPLineSegment(p0: p0, p1: pc)
        let line1 = IMPLineSegment(p0: p1, p1: pc)
        return [line0.normalIntersection(point: point), line1.normalIntersection(point: point)]
    }
    
    public func distancesTo(point point:float2) -> [float2] {
        let line0 = IMPLineSegment(p0: p0, p1: pc)
        let line1 = IMPLineSegment(p0: p1, p1: pc)
        return [line0.distanceTo(point: point),line1.distanceTo(point: point)]
    }
    
    /// Vector of distance from base vertex to opposite side
    public var heightVector:float2 {
        get{
            let line1 = IMPLineSegment(p0: p0, p1: p1)
            return line1.normalIntersection(point: pc) - pc
        }
    }
}


///  @brief Base quadrangle
public struct IMPQuad {
    
    /// Left bottom point of the quad
    public var left_bottom  = float2( -1, -1)
    
    /// Left top point of the quad
    public var left_top     = float2( -1,  1)
    
    /// Right bottom point of the quad
    public var right_bottom = float2(  1, -1)
    
    /// Right top point of the quad
    public var right_top    = float2(  1,  1)
    
    public var aspect:Float = 1 {
        didSet {
            if oldValue != aspect {
                setAspect(ratio: aspect)
            }
        }
    }
    
    public static let null = IMPQuad(left_bottom: float2(0), left_top: float2(0), right_bottom: float2(0), right_top: float2(0))
    
    public func lerp(final final:IMPQuad, t:Float) -> IMPQuad {
        let lb = left_bottom.lerp(final: final.left_bottom, t: t)
        let lt = left_top.lerp(final: final.left_top, t: t)
        let rt = right_top.lerp(final: final.right_top, t: t)
        let rb = right_bottom.lerp(final: final.right_bottom, t: t)
        return IMPQuad(left_bottom: lb, left_top: lt, right_bottom: rb, right_top: rt)
    }
    
    public subscript(index: Int) -> float2 {
        get {
            let i = index < 0 ? (4-abs(index))%4 : index%4
            
            if i == 0 {
                return left_bottom
            }
            else if i == 1 {
                return left_top
            }
            else if i == 2 {
                return right_top
            }
            return right_bottom
        }
        
        set {
            let i = index < 0 ? (4-abs(index))%4 : index%4
            
            if i == 0 {
                left_bottom = newValue
            }
            else if i == 1 {
                left_top = newValue
            }
            else if i == 2 {
                right_top = newValue
            }
            right_bottom = newValue
        }
    }
    
    public init(){}
    public init(left_bottom:float2,left_top:float2, right_bottom:float2, right_top:float2){
        self.left_bottom = left_bottom
        self.left_top = left_top
        self.right_bottom = right_bottom
        self.right_top = right_top
    }
    
    public init(region:IMPRegion, aspect:Float = 1, scale:Float=1){
        crop(region: region)
        defer{
            self.aspect = aspect
            self.scale = scale
        }
    }
    
    ///  Crop quad
    ///
    ///  - parameter region: rectangle region
    public mutating func crop(region region:IMPRegion){
        left_bottom.x = left_bottom.x * (1-2*region.left)
        left_bottom.y = left_bottom.y * (1-2*region.bottom)
        
        left_top.x = left_top.x * (1-2*region.left)
        left_top.y = left_top.y * (1-2*region.top)
        
        right_bottom.x = right_bottom.x * (1-2*region.right)
        right_bottom.y = right_bottom.y * (1-2*region.bottom)
        
        right_top.x = right_top.x * (1-2*region.right)
        right_top.y = right_top.y * (1-2*region.top)
    }
    
    public var scale:Float = 1 {
        didSet{
            left_bottom *= scale
            left_top *= scale
            right_top *= scale
            right_bottom *= scale
        }
    }
    
    private mutating func setAspect(ratio ratio:Float){
        left_bottom.x *= ratio
        left_top.x *= ratio
        right_top.x *= ratio
        right_bottom.x *= ratio
    }
    
    
    /// Basis matrix
    public var basis:float3x3 {
        get{
            let A = float3x3(rows:[
                [left_bottom.x,left_top.x,right_bottom.x],
                [left_bottom.y,left_top.y,right_bottom.y],
                [1,1,1]
                ])
            let B = float3(right_top.x,right_top.y,1)
            let X = A.inverse * B
            // C = (Ai)*B
            return A * float3x3(diagonal: X)
        }
    }
    
    ///  Projection transformation matrix on 2D plain from the self to destination
    ///
    ///  - parameter destination: destination quad
    ///
    ///  - returns: transformation matrix
    public func transformTo(destination d:IMPQuad) -> float4x4 {
        let t = d.basis * self.basis.inverse
        
        return float4x4(rows: [
            [t[0,0], t[1,0], 0, t[2,0]],
            [t[0,1], t[1,1], 0, t[2,1]],
            [0     , 0     , 1, 0   ],
            [t[0,2], t[1,2], 0, t[2,2]]
            ])
    }
    
    ///  Test whether the point belongs to the quad
    ///
    ///  - parameter point: point coords
    ///
    ///  - returns: result
    public func contains(point point:float2) -> Bool {
        return pnpoly(point:point)
    }

    ///  Test whether the point belongs to the rect of the quad pints
    ///
    ///  - parameter point: point coords
    ///
    ///  - returns: result
    public func containsRect(point point:float2) -> Bool {
        if point.x>=left_bottom.x-IMPMinimumPoint && point.y>=left_bottom.y-IMPMinimumPoint {
            if point.x>=left_top.x-IMPMinimumPoint && point.y<=left_top.y+IMPMinimumPoint {
                if point.x<=right_top.x+IMPMinimumPoint && point.y<=right_top.y+IMPMinimumPoint {
                    if point.x<=right_bottom.x+IMPMinimumPoint && point.y>=right_bottom.y-IMPMinimumPoint {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    
    public func intersects(quad quad:IMPQuad) -> Bool {
        for i in 0..<4{
            let line = IMPLineSegment(p0: self[i], p1: self[i+1])
            for j in 0..<4{
                let qline = IMPLineSegment(p0: quad[j], p1: quad[j+1])
                let p = qline.crossPoint(line: line)
                if contains(point: p) {
                    return true
                }
            }
        }
        return false
    }

    
    ///  Get translation vector between two quads
    ///
    ///  - parameter quad: another quad
    ///
    ///  - returns: translation (offset) vector
    public func translation(quad quad:IMPQuad) -> float2 {
                
        let distances = insetCornerDistances(quad: quad)
        
        // result offset
        var offset = float2(0)
        
        // summarize distances
        for p in distances {
            offset += p
        }
        
        //
        // covert to relation aspect ratio
        //
        //offset.x /= aspect
        
        return offset
    }
    
    ///  Find inset triangles
    ///
    ///  - parameter quad: another quad
    ///
    ///  - returns: triangles 
    ///
    public func insetTriangles(quad quad:IMPQuad) -> [IMPTriangle] {
        
        var triangles = [IMPTriangle]()
        
        for i in 0..<4 {
            let p0 = quad[i-1]
            let pc = quad[i+0]
            let p1 = quad[i+1]
            
            let cp0 = self[i-1]
            let cpc = self[i+0]
            let cp1 = self[i+1]
            
            
            let cornerLine1 = IMPLineSegment(p0: cpc, p1: cp0)
            let cornerLine2 = IMPLineSegment(p0: cpc, p1: cp1)
            
            let baseline1 = IMPLineSegment(p0: pc, p1:  p0)
            let baseline2 = IMPLineSegment(p0: pc, p1:  p1)
            
            let crossPoint1 = cornerLine1.crossPoint(line: baseline1)
            let crossPoint2 = cornerLine2.crossPoint(line: baseline1)
            
            let crossPoint12 = cornerLine1.crossPoint(line: baseline2)
            let crossPoint22 = cornerLine2.crossPoint(line: baseline2)
            
            if contains(point: crossPoint1) && contains(point: crossPoint2){
                let t = IMPTriangle(p0: crossPoint1, pc: cpc, p1: crossPoint2)
                triangles.append(t)
            }
            
            if contains(point: crossPoint12) && contains(point: crossPoint22){
                let t = IMPTriangle(p0: crossPoint12, pc: cpc, p1: crossPoint22)
                triangles.append(t)
            }
        }
        return triangles
    }
    
    
    // MARK - utils
    func insetCornerDistances(quad quad:IMPQuad) -> [float2] {
        var a = [float2]()
        
        for i in 0..<4 {
            
            let p0 = quad[i-1]
            let pc = quad[i+0]
            
            let qline  = IMPLineSegment(p0: p0, p1: pc)
            
            let bp0 = self[i-1]
            let bpc = self[i+0]
            let bp1 = self[i+1]
            
            let bline = IMPLineSegment(p0: bp0, p1: bpc)

            if !bline.isParallel(toLine: qline) {
                
                let p  = IMPTriangle(p0: bp0, pc: bpc, p1: bp1).normalIntersections(point: pc)
                a += quad.getInPlaceDistance(p, base: pc)
                
            }
        }
        
        if a.isEmpty {

            // Parralels ?

            for i in 0..<4 {
                let qp1 = quad[i+1]
                
                let p0 = self[i]
                let p1 = self[i+1]
                
                let  line = IMPLineSegment(p0: p0,  p1: p1)
                
                let p = line.normalIntersection(point: qp1)
                
                if quad.contains(point: p) {
                    a.append(p - qp1)
                }
                
            }
        }
        
        return a
    }
  
    func getInPlaceDistance(points:[float2], base:float2) -> [float2] {
        var a    = [float2]()
        for p in points {
            if contains(point: p) {
                
                a.append(p-base)
            }
        }
        return a
    }
    
    func pnpoly(point point:float2) -> Bool {
        
        var c = false
        let x = point.x
        let y = point.y
        
        var j=3
        
        for i in 0..<4 {
            
            let ii  = self[i]
            let jj  = self[j]
            
            j += 1
            
            let xpi = ii.x * IMPEPSPoint
            let ypi = ii.y * IMPEPSPoint
            
            let xpj = jj.x * IMPEPSPoint
            let ypj = jj.y * IMPEPSPoint
            
            if ((
                (ypi<ypj) && (ypi<=y) && (y<=ypj) &&
                    ((ypj - ypi) * (x - xpi) > (xpj - xpi) * (y - ypi))
                ) || (
                    (ypi>ypj) && (ypj<=y) && (y<=ypi) &&
                        ((ypj - ypi) * (x - xpi) < (xpj - xpi) * (y - ypi))
                )) {
                c = !c
            }
        }
        return c
    }
}

public func - (left:IMPQuad,right:IMPQuad) -> IMPQuad {
    let left_bottom  = left.left_bottom - right.left_bottom
    let left_top     = left.left_top - right.left_top
    let right_top    = left.right_top - right.right_top
    let right_bottom = left.right_bottom - right.right_bottom
    return IMPQuad(left_bottom: left_bottom, left_top: left_top, right_bottom: right_bottom, right_top: right_top)
}

public func + (left:IMPQuad,right:IMPQuad) -> IMPQuad {
    let left_bottom  = left.left_bottom + right.left_bottom
    let left_top     = left.left_top + right.left_top
    let right_top    = left.right_top + right.right_top
    let right_bottom = left.right_bottom + right.right_bottom
    return IMPQuad(left_bottom: left_bottom, left_top: left_top, right_bottom: right_bottom, right_top: right_top)
}

public extension IMPRegion{
    public init(region quad: IMPQuad, // angle must be == 0
                       inquad box:IMPQuad) {
        
        self = IMPRegion()
        
        let leftx   = fmin(box.left_bottom.x, box.left_top.x)
        let bottomy = fmin(box.left_bottom.y, box.right_bottom.y)
        
        let rightx   = fmax(box.right_bottom.x, box.right_top.x)
        let topy     = fmax(box.left_top.y, box.right_top.y)
        
        let w = rightx - leftx
        let h = topy - bottomy
        
        self.left   = fabs(leftx - quad.left_bottom.x)/w
        self.bottom = fabs(bottomy - quad.left_bottom.y)/h
        
        self.right = fabs(rightx - quad.right_top.x)/w
        self.top   = fabs(topy - quad.right_top.y)/h        
    }
}
