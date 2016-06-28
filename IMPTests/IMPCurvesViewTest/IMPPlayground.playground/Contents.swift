//: Playground - noun: a place where people can play

import Cocoa
import simd

public class IMPSpline {
    
    public typealias FunctionType = ((controls:[float2])-> [Float])
    public typealias RangeType = (first:float2,last:float2)
    
    public var function:FunctionType
    public let range:RangeType
    public let size:Int
    
    var controlPoints = [float2]()
    
    public func add(points points: [float2]) {
        
    }
    
    public func remove(points points: [float2]){
        for p in points {
            if
            (abs(p.x-range.first.x) < FLT_EPSILON
            &&
            abs(p.y-range.first.y) < FLT_EPSILON
            ) ||
            (abs(p.x-range.last.x) < FLT_EPSILON
            &&
            abs(p.y-range.last.y) < FLT_EPSILON)
            {
                continue
            }
            if let i = controlPoints.indexOf(p) {
                controlPoints.removeAtIndex(i)
            }
        }
    }
    
    public required init(range:RangeType, size:Int, function:FunctionType){
        self.function = function
        self.range = range
        self.size = size
        defer {
            controlPoints.append(range.first)
            controlPoints.append(range.last)
        }
    }
}

let defaultRange = Float.range(start: 0, step: 1/256, end: 1)

let spline = IMPSpline(range: (float2(0),float2(1)), size: 10) { (controls) -> [Float] in
    
}

let v:Float = 1

