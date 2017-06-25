//
//  IMPCurve.swift
//  IMPCurveTest
//
//  Created by denis svinarchuk on 16.06.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Accelerate
import Surge
import simd

public class IMPCurve {
    
    public enum ApproximationType {
        case interpolated
        case smooth
    }
    
    public typealias UpdateHandlerType = ((_ curve:IMPCurve)->Void)
    public typealias BoundsType = (first:float2,last:float2)
    
    public var interpolator:IMPInterpolator {return _interpolator }
    public var bounds:BoundsType        { return _bounds }
    public var edges:([float2],[float2])   { return _edges }
    public let maxControlPoints:Int
    public let segments:[Float]
    public var controlPoints:[float2] { return _controlPoints }
    public var precision:Float?
    public var userInfo:Any? { didSet { updateCurve() } }
    public let type:ApproximationType
    
    private var _bounds:BoundsType
    private var _edges:([float2],[float2])
    
    public var values:[Float] {
        return _curve
    }
    
    public required init(interpolator:IMPInterpolator,
                         type:ApproximationType,
                         bounds:BoundsType            = (float2(0),float2(1)),
                         edges:([float2],[float2])    = ([float2(0)+float2(Float.ulpOfOne)],[float2(1)-float2(Float.ulpOfOne)]),
                         initials:([float2],[float2]) = ([float2(0)],[float2(1)]),
                         maxControlPoints:Int = 32
                         ){
        
        self.type = type
        self._interpolator = interpolator
        self._bounds = bounds
        self._edges = edges
        self.maxControlPoints = maxControlPoints
        self.segments = Float.range(start: self._bounds.first.x, step: self._bounds.last.x/Float(self._interpolator.resolution), end: self._bounds.last.x)
        
        defer {
            var inits = [float2]()
            if initials.0.count>0 {
                inits.append(contentsOf: initials.0)
            }
            else{
                inits.append(bounds.first)
            }
            if initials.1.count>0 {
                inits.append(contentsOf: initials.1)
            }
            else {
                    inits.append(bounds.last)
            }
            _controlPoints.append(contentsOf: inits)
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
        for p in points { _ = add(point: p) }
        updateCurve()
    }
    
    private func add(point p: float2) -> Int? {
        if findXPoint(point: p) != nil {
            return nil
        }
        if let i = indexOf(point: p) {
            _controlPoints[i] = p
            return i
        }
        
        if let index = _controlPoints.index(where: { (cp) -> Bool in
            return cp.x>p.x
        }) {
            _controlPoints.insert(p, at: index)
            return index
        }
        else if closeness(one: p, two: bounds.first) {
            _controlPoints.insert(p, at: 0)
            return 0
        }
        else {
            _controlPoints.append(p)
            return _controlPoints.count - 1
        }
    }
    
    public func remove(points: [float2], complete:((_ flag:Bool)->Void)? = nil){
        var f = false

        func doneBlock(){
            updateCurve()
            complete?(f)
        }
        
        for p in points {
            
            if let i = indexOf(point: p) {
                
                let doRestoreLast = _controlPoints.count-1 == i
                let doRestoreFirst = i == 0
                
                _controlPoints.remove(at: i)
                
                if doRestoreLast {
                    _controlPoints.append(bounds.last)
                }
                if doRestoreFirst {
                    _controlPoints.insert(bounds.first, at: 0)
                }
                
                f = true
            }
        }
        doneBlock()
    }
    
    public func set(point: float2, at atIndex:Int) -> float2? {
        var point = point
        var result:float2? = nil

         if atIndex < _controlPoints.count {

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
            result = _controlPoints[atIndex]
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
    
    public func addCloseTo(_ xy:float2, complete:((_ flag:Bool, _ point:float2?, _ index:Int?)->Void)? = nil) {
        
        var isNew = false
        
        func location(_ i:Int, spline:IMPCurve) -> float2 {
            let x = i.float/spline._curve.count.float
            let y = spline._curve[i]
            return float2(x,y)
        }
        
        var currentPoint:float2? = nil
        var currentIndex:Int? = nil
        
        if maxControlPoints <= controlPoints.count {
            currentIndex = indexOf(point: xy)
            if let index = currentIndex {
                currentPoint = _controlPoints[index]
            }
            complete?(isNew, currentPoint, currentIndex)
            return
        }
        
        if maxControlPoints <= controlPoints.count {
            for i in 0..<controlPoints.count {
                let p = controlPoints[i]
                if distance(p, xy) < closeDistance {
                    currentPoint = set(point: xy, at: i)
                    currentIndex = i
                    break
                }
            }
        }
        else {
            if type == .smooth {
                if let index = indexOf(point: xy) {
                    currentIndex = index
                    _controlPoints[index] = xy
                    complete?(isNew, currentPoint, currentIndex)
                    return
                }
            }
            for i in 0..<_curve.count {
                if distance(location(i, spline: self), xy) < closeDistance {
                    currentPoint = xy
                    if let index = indexOf(point: xy) {
                        currentIndex = index
                        _controlPoints[index] = xy
                    }
                    else {
                        currentIndex = add(point: xy)
                        isNew = true
                    }
                    updateCurve()
                    break
                }
            }
        }
        
        complete?(isNew, currentPoint, currentIndex)
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
        return precision ?? 1/Float(interpolator.resolution/2)
    }
    
    private func reset() {
        _controlPoints.removeAll()
        updateCurve()
    }
    
    private var _interpolator:IMPInterpolator
    
    private var _curve = [Float]() {
        didSet{
            executeObservers()
        }
    }
    
    private var observers = [UpdateHandlerType]()
    
    private var _controlPoints:[float2] = [float2]()
    
    private func updateCurve()  {
        _curve.removeAll()
        _interpolator.controls = controlPoints
        _interpolator.controls.insert(contentsOf: _edges.0, at: 0)
        _interpolator.controls.append(contentsOf: _edges.1)
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
        
        for i in 0..<controlPoints.count {
            if abs(controlPoints[i].x - p.x) < closeDistance {
                return i
            }
        }
        return nil
    }
}
