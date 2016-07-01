//
//  IMPCurveFunctions.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 29/06/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing
import Accelerate
import simd

infix operator <- { associativity right precedence 90 }

public func <- (left:IMPSpline, right:[float2]) {
    left._controlPoints = right
}

public func <- (spline:IMPSpline, xy:float2) -> float2? {
    
    func location(i:Int, spline:IMPSpline) -> float2 {
        let x = i.float/spline.curve.count.float
        let y = spline.curve[i]
        return float2(x,y)
    }
    
    var currentPoint:float2?
    
    if spline.maxControlPoints == spline.controlPoints.count {
        for i in 0..<spline.controlPoints.count {
            let p = spline.controlPoints[i]
            if distance(p, xy) < spline.precision {
                currentPoint = xy
                spline.set(point: xy, atIndex: i)
                break
            }
        }
    }
    else if let i = spline.indexOf(point: xy, distance: spline.precision) {
        spline.set(point: xy, atIndex: i)
        currentPoint = xy
    }
    else if distance(spline.bounds.first, xy) < spline.precision {
        spline.set(point: xy, atIndex: 0)
        currentPoint = xy
    }
    else if distance(spline.bounds.last, xy) < spline.precision {
        spline.set(point: xy, atIndex: spline.controlPoints.count-1)
        currentPoint = xy
    }
    else {
        for i in 0..<spline.curve.count {
            if distance(location(i, spline: spline), xy) < spline.precision {
                spline.add(points: [xy])
                currentPoint = xy
                break
            }
        }
    }    
    return currentPoint
}

public func - (left:IMPSpline, right:[float2]) {
    left.remove(points: right)
}

public func - (left:IMPSpline, right:float2) {
    left.remove(points: [right])
}

public class IMPSpline {
    
    public typealias UpdateHandlerType = ((spline:IMPSpline)->Void)
    public typealias FunctionType = ((controls:[float2], segments:[Float])-> [Float])
    public typealias BoundsType = (first:float2,last:float2)
    
    public let function:FunctionType
    public var bounds:BoundsType { return _bounds }
    public let size:Int
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return _controlPoints }
    public var precision:Float?
    
    public var _bounds:BoundsType

    public var curve:[Float] {
        return _curve
    }
    
    public required init(bounds:BoundsType=(float2(0),float2(1)), size:Int=256, maxControlPoints:Int=32, function:FunctionType=IMPCurveFunction.cubic){
        self.function = function
        self._bounds = bounds
        self.size = size
        self.maxControlPoints = maxControlPoints
        self.segments = Float.range(start: self._bounds.first.x, step: self._bounds.last.x/Float(self.size), end: self._bounds.last.x)
        defer {
            _controlPoints.append(bounds.first)
            _controlPoints.append(bounds.last)
            updateCurve()
        }
    }
    
    public func isBounds(point p:float2) -> Bool {
        return (abs(p.x-bounds.first.x) <= closeDistance || abs(p.x-bounds.last.x) <= closeDistance)
    }
    
    public func addUpdateObserver(observer:UpdateHandlerType){
        observers.append(observer)
    }
    
    public func removeAllUpdateObservers(){
        observers.removeAll()
    }
    
    public func add(points points: [float2]) {
        for p in points {
            if isBounds(point: p) {
                continue
            }
            if findXPoint(p) != nil {
                continue
            }
            if let i = indexOf(point: p) {
                _controlPoints[i] = p
                continue
            }
            _controlPoints.append(p)
        }
        
        _controlPoints = [float2](_controlPoints.suffix(maxControlPoints))
        _controlPoints = _controlPoints.sort({ (one, two) -> Bool in
            if distance(one, bounds.first) <= FLT_EPSILON {
                return false
            }
            else if distance(two, bounds.last) <= FLT_EPSILON {
                return true
            }
            return (one.x < two.x) && (one.y < two.y)
        })
        updateCurve()        
    }
    
    public func remove(points points: [float2]){
        for p in points {
            if isBounds(point: p) {
                continue
            }
            if let i = _controlPoints.indexOf(p) {
                _controlPoints.removeAtIndex(i)
            }
        }
        updateCurve()
    }
    
    public func set(point point: float2, atIndex:Int) -> float2? {
        var point = point
        
        if atIndex == 0 || atIndex == _controlPoints.count-1 {
            
            if point.x<bounds.first.x {
                point.x = bounds.first.x
            }

            if point.x>bounds.last.x {
                point.x = bounds.last.x
            }

            if point.y<bounds.first.y {
                point.y = bounds.first.y
            }
            
            if point.y>bounds.last.y {
                point.y = bounds.last.y
            }

            _controlPoints[atIndex] = point
            updateCurve()
            return point
        }
        
        var result:float2? = nil
        
        if atIndex < _controlPoints.count {
            
            let cp = _controlPoints[atIndex]
            
            
            if outOfBounds(point:point) {
                if !isBounds(point: cp) {
                    _controlPoints.removeAtIndex(atIndex)
                }
            }
            else {
                result = point
            }
        }

        if let p = result {
            _controlPoints[atIndex] = p
        }
        
        updateCurve()
        
        return result
    }
    
    public func set(points points: [float2]){
        reset()
        add(points: points)
    }
    
    public func removeAll(){
        reset()
        updateCurve()
    }
    
    public func closeToCurve(point point: float2, distance:Float?=nil) -> float2? {
        
        for i in 0..<curve.count {
            let x = Float(i)/Float(curve.count) * bounds.last.x
            let y = curve[i]
            let p = float2(x,y)
            if simd.distance(p, point) <= distance ?? closeDistance {
                return p
            }
        }
        
        return nil
    }
    
    public func indexOf(point point:float2?, distance:Float?=nil) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if closeness(one: _controlPoints[i], two: p, distance: distance) {
                return i
            }
        }
        return nil
    }

    public func closeness(one one: float2, two: float2, distance:Float?=nil) -> Bool {
        return simd.distance(one, two) <= distance ?? closeDistance
    }
    
    public func outOfBounds(point point: float2) -> Bool {
        return (point.x < bounds.first.x || point.x > bounds.last.x ||
            point.y < bounds.first.y || point.y > bounds.last.y)
    }
    
    var closeDistance:Float {
        return precision ?? 1/Float(size/2)
    }
    
    private func reset() {
        _controlPoints.removeAll()
        _controlPoints.append(bounds.first)
        _controlPoints.append(bounds.last)
    }

    private var _controlPoints = [float2]() {
        didSet{
            if _controlPoints.count >= 2{
                updateCurve()
            }
        }
    }
    
    internal var _curve = [Float]() {
        didSet{
            executeObservers()
        }
    }
    
    private var observers = [UpdateHandlerType]()
    
    private func updateCurve()  {
        _curve = self.function(controls: _controlPoints, segments: segments)
    }
    
    private func executeObservers()  {
        for o in observers {
            o(spline: self)
        }
    }
    
    private func findXPoint(point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if abs(_controlPoints[i].x - p.x) < closeDistance {
                return i
            }
        }
        return nil
    }
}

public enum IMPCurveFunction: String {
    
    case Cubic       = "Cubic"
    case CatmullRom  = "CatmullRom"
    case Bezier      = "Bezier"
    
    public var spline:IMPSpline {
        switch self {
        case .CatmullRom:
            return IMPSpline(function: IMPCurveFunction.catmullRom)
        case .Bezier:
            return IMPSpline(maxControlPoints: 2, function: IMPCurveFunction.bezier)
        default:
            return IMPSpline()
        }
    }
   
    public static var catmullRom:IMPSpline.FunctionType = { (controls, segments) -> [Float] in
        var c = [float2](controls)
        if c.count == 2 {
            c.append(float2(1))
        }
        return segments.catmullRomSpline(c)
    }
    
    public static var cubic:IMPSpline.FunctionType = { (controls, segments) -> [Float] in
        return segments.cubicSpline(controls)
    }
    
    public static var bezier:IMPSpline.FunctionType = { (controls, segments) -> [Float] in
        return segments.cubicBezierSpline(controls)
    }

}

