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


extension Array where Element: Equatable {
    func uniq() -> [Element] {
        return self.reduce([], { (objects, object) -> [Element] in
            var objects = objects
            if !objects.contains(object) {
                objects.append(object)
            }
            return objects
        })
    }
}

public class IMPCurve: Hashable {
    public /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    let hashValue: Int = UUID().hashValue
    
    public static func ==(lhs: IMPCurve, rhs: IMPCurve) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    public enum ApproximationType {
        case interpolated
        case smooth
    }
    
    public typealias UpdateHandlerType = ((_ curve:IMPCurve)->Void)
    
    public var values:[Float] { return _curve }

    public var interpolator:IMPInterpolator  {return _interpolator }
    
    public var bounds:IMPInterpolator.Bounds {
        set{
            _interpolator.bounds = newValue; updateCurve() 
        }
        get{  return _interpolator.bounds }
    }
    
    public let maxControlPoints:Int
    public var controlPoints:[float2] { return _controlPoints }

    public var edges:([float2],[float2]) { return _edges }
    public let segments:[Float]
    
    public var precision:Float?
    
    public let type:ApproximationType
    
    public var userInfo:Any? { didSet { updateCurve() } }
    
    private var _edges:([float2],[float2])
    private var _initials:([float2],[float2])
    private var _initialBounds:IMPInterpolator.Bounds
    
    public required init(interpolator:IMPInterpolator,
                         type:ApproximationType,
                         bounds:IMPInterpolator.Bounds = (float2(0),float2(1)),
                         edges:([float2],[float2])     = ([float2(0)],[float2(1)]),
                         initials:([float2],[float2])  = ([],[]),
                         maxControlPoints:Int = 32
        ){
        
        self.type = type
        self._interpolator = interpolator
        self._interpolator.bounds = bounds
        _initialBounds = bounds
        self._edges = edges
        self._initials = initials
        self.maxControlPoints = maxControlPoints
        self.segments = Surge.linspace(Float(0), Float(1), num: self._interpolator.resolution) 
        
        defer {
            resetControlPoints()
            updateCurve()
        }
    }
    
    private func resetControlPoints(){
        var inits = [float2]()
        if self._initials.0.count>0 {
            inits.append(contentsOf: self._initials.0)
        }
        
        if _initials.1.count>0 {
            inits.append(contentsOf: self._initials.1)
        }
        
        _controlPoints.append(contentsOf: inits)        
    }
    
    public func update()  {
        updateCurve()
    }
    
    public func addUpdateObserver(observer:@escaping UpdateHandlerType){
        observers.append(observer)
    }
    
    public func removeAllUpdateObservers(){
        observers.removeAll()
    }
    
    public func add(points: [float2]) {
        let sorted = points.sorted { return $0.x<$1.x }
        for p in sorted { _ = add(point: p) }
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
        
        _controlPoints.append(p)
        
        if _controlPoints.count >= 2{ 
            _controlPoints[0] = bounds.left
            _controlPoints[1] = bounds.right
        }

        if maxControlPoints >= 2 {
                        
            if _controlPoints.count == 1 && _initials.0.count == 0 {
                _initials.0.append(_controlPoints[0])
            }
            
            if _controlPoints.count == 2 && _initials.1.count == 0 {
                _initials.1.append(_controlPoints[1])
            }                    
        }
                
        return _controlPoints.count-1
    }
    
    public func remove(points: [float2], complete:((_ flag:Bool)->Void)? = nil){
        var f = false
        
        for p in points {
            if let i = indexOf(point: p) {
                _controlPoints.remove(at: i)
                f = true
            }
        }
        
        updateCurve()
        complete?(f)
    }
    
    private func _set(point: float2, at atIndex:Int) -> float2? {
        var point = point
        var result:float2? = nil
        
        if atIndex < _controlPoints.count {
            
            if point.x<=0 { point.x = 0 }
            
            if point.x>=1 { point.x = 1 }
            
            if point.y<=0 { point.y = 0 }
            
            if point.y>=1 { point.y = 1 }
            
            _controlPoints[atIndex] = point
            result = _controlPoints[atIndex]
        }                
        return result
    }

    public func set(point: float2, at atIndex:Int) -> float2? {
        let r = _set(point:point, at: atIndex)
        updateCurve()
        return r
    }
    
    public func set(points: [float2]){
        _controlPoints.removeAll()
        add(points: points)
        updateCurve()
    }

    private func clearControlPoints(){
        _controlPoints.removeAll()        
        resetControlPoints()
    } 

    public func reset(){
        bounds = _initialBounds
        clearControlPoints()        
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
                    else if xy.x - _controlPoints[0].x > closeDistance &&
                         _controlPoints[_controlPoints.count-1].x - xy.x > closeDistance
                    {
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
            let x = Float(i)/Float(_curve.count) //* bounds.last.x
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
            let x = Float(i)/Float(_curve.count) //* bounds.last.x
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
    
    public var closeDistance:Float {
        return precision ?? 1/Float(_interpolator.resolution/2)
    }
        
    private var _interpolator:IMPInterpolator
    
    private var _curve = [Float]()
    
    private var observers = [UpdateHandlerType]()
    
    private var _controlPoints:[float2] = [float2]()
    
    private func updateCurve()  {
        _curve.removeAll()
        _interpolator.controls = _controlPoints
        _interpolator.controls.insert(contentsOf: _edges.0, at: 0)
        _interpolator.controls.append(contentsOf: _edges.1)
        for x in segments {
            _curve.append(_interpolator.value(at: x))
        }
        executeObservers()
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
