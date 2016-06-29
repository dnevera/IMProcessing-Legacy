//: Playground - noun: a place where people can play

import Cocoa
import simd

public class IMPSpline {
    
    public typealias FunctionType = ((controls:[float2])-> [Float])
    public typealias RangeType = (first:float2,last:float2)
    
    public let function:FunctionType
    public let range:RangeType
    public let size:Int
    public let maxControlPoints:Int
    
    public required init(range:RangeType, size:Int, maxControlPoints:Int, function:FunctionType){
        self.function = function
        self.range = range
        self.size = size
        self.maxControlPoints = maxControlPoints
        defer {
            controlPoints.append(range.first)
            controlPoints.append(range.last)
        }
    }
    
    var controlPoints = [float2]()
    
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
    }
    
    func findClosePoint(point:float2?) -> Int? {
        
        guard let p = point else { return  nil}
        
        for i in 0..<controlPoints.count {
            if distance(controlPoints[i], p) < 1/Float(size/2) {
                return i
            }
        }
        return nil
    }
    
    func isBounds(point p:float2) -> Bool {
        return (distance(p, range.first) <= FLT_EPSILON || distance(p, range.last) <= FLT_EPSILON)
    }
}

let defaultRange = Float.range(start: 0, step: 1/256, end: 1)

let spline = IMPSpline(range: (float2(0),float2(1)), size: 256, maxControlPoints: 10) { (controls) -> [Float] in
        return []
}

let v:Float = 1

