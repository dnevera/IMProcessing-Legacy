//: Playground - noun: a place where people can play

import Cocoa
import simd

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
            controlPoints.append(bounds.first)
            controlPoints.append(bounds.last)
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
            if findClosePoint(p) != nil {
                continue
            }
            controlPoints.append(p)
        }
        
        controlPoints = [float2](controlPoints.suffix(maxControlPoints))
        controlPoints = controlPoints.sort({ (one, two) -> Bool in
            if distance(one, bounds.first) <= FLT_EPSILON {
                return false
            }
            else if distance(two, bounds.last) <= FLT_EPSILON {
                return true
            }
            return (one.x < two.x) && (one.y < two.y)
        })
        updateCurve()
        
        print(controlPoints)
    }
    
    public func remove(points points: [float2]){
        for p in points {
            if isBounds(point: p) {
                continue
            }
            if let i = controlPoints.indexOf(p) {
                controlPoints.removeAtIndex(i)
            }
        }
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
    
    private func reset() {
        controlPoints.removeAll()
        controlPoints.append(bounds.first)
        controlPoints.append(bounds.last)
    }
    
    private var controlPoints = [float2]()
    private var _curve = [Float]() {
        didSet{
            executeObservers()
        }
    }
    
    private var observers = [UpdateHandlerType]()
    
    private func updateCurve()  {
        _curve = self.function(controls: controlPoints, segments: segments)
    }
    
    private func executeObservers()  {
        for o in observers {
            o(spline: self)
        }
    }
    
    private func findClosePoint(point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<controlPoints.count {
            if abs(controlPoints[i].x - p.x) < 1/Float(size/2) {
                return i
            }
        }
        return nil
    }
}

infix operator <- { associativity right precedence 90 }
public func <- (left:IMPSpline, right:[float2]) {
    left.set(points: right)
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

let cubic = IMPCurveFunction.Cubic.spline
let bezier = IMPCurveFunction.Bezier.spline

cubic <- [float2(0.3,0),float2(0.9,1)]

let c = cubic.curve

for y in c {
    let y = y
}

