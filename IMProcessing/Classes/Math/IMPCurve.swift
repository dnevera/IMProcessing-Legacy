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

public protocol IMPInterpolator{
    var controls:[float2] {get set}
    var resolution:Int {get}
    init(resolution:Int)
    func value(at x:Float) -> Float
}

public extension IMPInterpolator {
   
    public subscript(_ t: Float) -> Float {
        return value(at: t)
    }
    
    public var step:Float {
        return 1/Float(resolution)
    }

    public func bounds(at t:Int) -> Int {
        return t <= 0 ? 0 :  t >= (controls.count-1) ? controls.count - 1 : t
    }
    
    //public func index(at t:Float) -> Int {
    //    return Int(t*Float(resolution))+1
    //}

    public func controlIndices(at x: Float) -> (i1:Int,i2:Int)? {
        guard let i = controls.index(where: { (cp) -> Bool in return cp.x>x }) else { return nil }
        //let i = index(at: x)
        return (bounds(at:i-1), bounds(at: i))
    }
    
}

public class IMPLinearInterpolator : IMPInterpolator {
    
    public let resolution: Int
    
    public var controls = [float2]()
    
    public required init(resolution:Int) {
        self.resolution = resolution
    }
    
    public func value(at x: Float) -> Float {
        guard let (k1,k2) = controlIndices(at: x) else {return x}
        
        let P0 = controls[k1]
        let P1 = controls[k2]
        
        let d = P1.x - P0.x
        let x = d == 0 ? 0 : (x-P0.x)/d
        
        return P0.y + (P1.y-P0.y)*x
    }
}

public class IMPCurve {
    
    public typealias UpdateHandlerType = ((_ curve:IMPCurve)->Void)
    public typealias FunctionType = ((_ controls:[float2], _ segments:[Float], _ userInfo:Any?)-> [Float])
    public typealias BoundsType = (first:float2,last:float2)
    
    public var interpolator:IMPInterpolator {return _interpolator }
    public var bounds:BoundsType { return _bounds }
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return interpolator.controls }
    public var precision:Float?
    public var userInfo:Any? {
        didSet {
            updateCurve()
        }
    }
    
    public var _bounds:BoundsType
    
    public var values:[Float] {
        return _curve
    }
    
    public required init(bounds:BoundsType    = (float2(0),float2(1)),
                         maxControlPoints:Int = 32,
                         interpolator:IMPInterpolator){
        
        self._interpolator = interpolator
        self._bounds = bounds
        self.maxControlPoints = maxControlPoints
        self.segments = Float.range(start: self._bounds.first.x, step: self._bounds.last.x/Float(self._interpolator.resolution), end: self._bounds.last.x)
        defer {
            self._interpolator.controls.append(bounds.first)
            self._interpolator.controls.append(bounds.last)
            updateCurve()
        }
    }
    
    public func update()  {
        updateCurve()
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
                _interpolator.controls[i] = p
                continue
            }
            if let index = _interpolator.controls.index(where: { (cp) -> Bool in
                return cp.x>p.x
            }) {
                _interpolator.controls.insert(p, at: index)
            }
            else {
                _interpolator.controls.append(p)
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
            
            if let i = indexOf(point: p) {
                if i > 0 && i < interpolator.controls.count-1{
                    _interpolator.controls.remove(at: i)
                    f = true
                }
            }
        }
        updateCurve()
        complete?(f)
    }
    
    public func set(point: float2, atIndex:Int) -> float2? {
        var point = point
        
        if atIndex == 0 || atIndex == interpolator.controls.count-1 {
            
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
            
            _interpolator.controls[atIndex] = point
            updateCurve()
            return point
        }
        
        var result:float2? = nil
        
        if atIndex < _interpolator.controls.count {
            
            let cp = _interpolator.controls[atIndex]
            
            
            if outOfBounds(point:point) {
                if !isBounds(point: cp) {
                    _interpolator.controls.remove(at: atIndex)
                }
            }
            else {
                result = point
            }
        }
        
        if let p = result {
            _interpolator.controls[atIndex] = p
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

    
    public func closestPointOfCurve(to point:float2) -> float2 {
        var dist = MAXFLOAT
        var closestPoint = point
        
        for i in 0..<_curve.count {
            let x = Float(i)/Float(_curve.count) * bounds.last.x
            let y = _curve[i]
            let p = float2(x,y)
            let ndist = simd.distance(p, point)
            if  ndist < dist {
                dist = ndist
                closestPoint = p
            }
        }
        
        return closestPoint
    }
    
    public func closeToCurve(point: float2, distance:Float?=nil) -> float2? {

        let d = distance ?? closeDistance
        
        for i in 0..<_curve.count {
            let x = Float(i)/Float(_curve.count) * bounds.last.x
            let y = _curve[i]
            let p = float2(x,y)
            if simd.distance(float2(x,y), point) <= d {
                return p
            }
        }
        return nil
    }
    
    public func indexOf(point:float2?, distance:Float?=nil) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<interpolator.controls.count {
            if closeness(one: interpolator.controls[i], two: p, distance: distance) {
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
        return precision ?? 1/Float(interpolator.resolution/2)
    }
    
    private func reset() {
        _interpolator.controls.removeAll()
        _interpolator.controls.append(bounds.first)
        _interpolator.controls.append(bounds.last)
    }
    
    private var _interpolator:IMPInterpolator
    
    private var _curve = [Float]() {
        didSet{
            executeObservers()
        }
    }
    
    private var observers = [UpdateHandlerType]()
    
    private func updateCurve()  {
        _curve.removeAll()
        for x in segments {
            _curve.append(interpolator.value(at: x))
        }
    }
    
    private func executeObservers()  {
        for o in observers {
            o(self)
        }
    }
    
    private func findXPoint(point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<interpolator.controls.count {
            if abs(interpolator.controls[i].x - p.x) < closeDistance {
                return i
            }
        }
        return nil
    }
}
