//
//  IMPCurve.swift
//  IMPCurveTest
//
//  Created by denis svinarchuk on 16.06.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Accelerate
import simd

public class IMPCurve {
    
    public typealias UpdateHandlerType = ((_ curve:IMPCurve)->Void)
    public typealias FunctionType = ((_ controls:[float2], _ segments:[Float])-> [Float])
    public typealias BoundsType = (first:float2,last:float2)
    
    public let function:FunctionType
    public var bounds:BoundsType { return _bounds }
    public let size:Int
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return _controlPoints }
    public var precision:Float?
    
    public var _bounds:BoundsType
    
    public var values:[Float] {
        return _curve
    }
    
    public required init(bounds:BoundsType    = (float2(0),float2(1)),
                         size:Int             = 256,
                         maxControlPoints:Int = 32,
                         function:@escaping FunctionType){
        
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
    
    public func addUpdateObserver(observer:@escaping UpdateHandlerType){
        observers.append(observer)
    }
    
    public func removeAllUpdateObservers(){
        observers.removeAll()
    }
    
    public func add(points: [float2]) {
        
        for p in points {
            if isBounds(point: p) {
                continue
            }
            if findXPoint(point: p) != nil {
                continue
            }
            if let i = indexOf(point: p) {
                _controlPoints[i] = p
                continue
            }
            if let index = (_controlPoints.index { $0.x > p.x }) {
                _controlPoints.insert(p, at: index)
            }
            else {
                _controlPoints.append(p)
            }
        }
        
        updateCurve()
    }
    
    public func remove(points: [float2], complete:((_ flag:Bool)->Void)? = nil){
        var f = false
        for p in points {
            if isBounds(point: p) {
                continue
            }
            if let i = _controlPoints.index(of: p) {
                if i != 0 && i != _controlPoints.count-1{
                    _controlPoints.remove(at: i)
                    f = true
                }
            }
        }
        updateCurve()
        complete?(f)
    }
    
    public func set(point: float2, atIndex:Int) -> float2? {
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
                    _controlPoints.remove(at: atIndex)
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
    
    public func set(points: [float2]){
        reset()
        add(points: points)
    }
    
    public func removeAll(){
        reset()
        updateCurve()
    }
    
    public func addCloseTo(_ xy:float2, complete:((_ flag:Bool, _ point:float2?)->Void)? = nil) {
        
        var isNew = false
        
        func location(_ i:Int, spline:IMPCurve) -> float2 {
            let x = i.float/spline._curve.count.float
            let y = spline._curve[i]
            return float2(x,y)
        }
        
        var currentPoint:float2? = nil
        
        if maxControlPoints == controlPoints.count {
            for i in 0..<controlPoints.count {
                let p = controlPoints[i]
                if distance(p, xy) < closeDistance {
                    currentPoint = set(point: xy, atIndex: i)
                    break
                }
            }
        }
        else if let i = indexOf(point: xy, distance: precision) {
            currentPoint = set(point: xy, atIndex: i)
        }
        else if distance(bounds.first, xy) < closeDistance {
            
            currentPoint = set(point: xy, atIndex: 0)
        }
        else if distance(bounds.last, xy) < closeDistance {
            currentPoint = set(point: xy, atIndex: controlPoints.count-1)
        }
        else {
            for i in 0..<_curve.count {
                if distance(location(i, spline: self), xy) < closeDistance {
                    add(points: [xy])
                    isNew = true
                    currentPoint = xy
                    break
                }
            }
        }
        
        complete?(isNew,currentPoint)
    }

    
    public func closeToCurve(point: float2, distance:Float?=nil) -> float2? {
        
        for i in 0..<_curve.count {
            let x = Float(i)/Float(_curve.count) * bounds.last.x
            let y = _curve[i]
            let p = float2(x,y)
            if simd.distance(p, point) <= distance ?? closeDistance {
                return p
            }
        }
        
        return nil
    }
    
    public func indexOf(point:float2?, distance:Float?=nil) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<_controlPoints.count {
            if closeness(one: _controlPoints[i], two: p, distance: distance) {
                return i
            }
        }
        return nil
    }
    
    public func closeness(one: float2, two: float2, distance:Float?=nil) -> Bool {
        return simd.distance(one, two) <= distance ?? closeDistance
    }
    
    public func outOfBounds(point: float2) -> Bool {
        return (point.x < bounds.first.x || point.x > bounds.last.x ||
            point.y < bounds.first.y || point.y > bounds.last.y)
    }
    
    private var closeDistance:Float {
        return precision ?? 1/Float(size/2)
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
        _curve = self.function(_controlPoints, segments)
    }
    
    private func executeObservers()  {
        for o in observers {
            o(self)
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
