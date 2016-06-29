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
    public let bounds:BoundsType
    public let size:Int
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return _controlPoints }
    
    public var curve:[Float] {
        return _curve
    }
    
    public required init(bounds:BoundsType=(float2(0),float2(1)), size:Int=256, maxControlPoints:Int=32, function:FunctionType=IMPSpline.cubicFunction){
        self.function = function
        self.bounds = bounds
        self.size = size
        self.maxControlPoints = maxControlPoints
        self.segments = Float.range(start: self.bounds.first.x, step: self.bounds.last.x/Float(self.size), end: self.bounds.last.x)
        defer {
            _controlPoints.append(bounds.first)
            _controlPoints.append(bounds.last)
            updateCurve()
        }
    }
    
    public func isBounds(point p:float2) -> Bool {
        return (abs(p.x-bounds.first.x) <= FLT_EPSILON || abs(p.x-bounds.last.x) <= FLT_EPSILON)
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
        
        print(_controlPoints)
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
    
    public func set(point point: float2, atIndex:Int){
        if isBounds(point: point) {
            return
        }
        _controlPoints[atIndex] = point
        updateCurve()
    }
    
    public func set(points points: [float2]){
        reset()
        add(points: points)
    }
    
    public func removeAll(){
        reset()
        updateCurve()
    }

    func indexOf(point point:float2?, dist:Float = 0.05) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if distance(_controlPoints[i], p) < dist {
                return i
            }
        }
        return nil
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
        print("executeObservers \(controlPoints)")
        for o in observers {
            o(spline: self)
        }
    }
    
    private func findXPoint(point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if abs(_controlPoints[i].x - p.x) < 1/Float(size/2) {
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

