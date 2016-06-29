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
    left.set(points: right)
}

public func <- (left:IMPSpline, right:float2) {
    left.set(points: [right])
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
    
    public static var cubicFunction:FunctionType = { (controls, segments) -> [Float] in
        return segments.cubicSpline(controls)
    }
    
    public static var bezierFunction:FunctionType = { (controls, segments) -> [Float] in
        return segments.cubicBezierSpline(controls)
    }
    
    
    public let function:FunctionType
    public var bounds:BoundsType { return _bounds }
    public let size:Int
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return _controlPoints }
    
    public var _bounds:BoundsType

    public var curve:[Float] {
        return _curve
    }
    
    public required init(bounds:BoundsType=(float2(0),float2(1)), size:Int=256, maxControlPoints:Int=32, function:FunctionType=IMPSpline.cubicFunction){
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
    
    public func indexOf(point point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if closeness(one: _controlPoints[i], two: p) {
                return i
            }
        }
        return nil
    }

    public func closeness(one one: float2, two: float2) -> Bool {
        return distance(one, two) <= closeDistance
    }
    
    public func outOfBounds(point point: float2) -> Bool {
        return (point.x < bounds.first.x || point.x > bounds.last.x ||
            point.y < bounds.first.y || point.y > bounds.last.y)
    }
    
    var closeDistance:Float {
        return 1/Float(size/2)
    }
    
    private func reset() {
        _controlPoints.removeAll()
        _controlPoints.append(bounds.first)
        _controlPoints.append(bounds.last)
    }

    private var _controlPoints = [float2]()
    private var _curve = [Float]() {
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

public enum IMPCurveFunction {

    case Cubic
    case Bezier
    
    public var spline:IMPSpline {
        switch self {
        case .Bezier:
            return IMPSpline(maxControlPoints: 2, function: IMPSpline.bezierFunction)
        default:
            return IMPSpline()
        }
    }
}

