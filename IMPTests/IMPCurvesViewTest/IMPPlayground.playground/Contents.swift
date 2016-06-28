//: Playground - noun: a place where people can play

import Cocoa
import simd

public class IMPSpline {
    
    public typealias FunctionType = ((controls:[float2])-> [Float])
    public typealias RangeType = (first:float2,last:float2)
    
    public var function:FunctionType
    public let range:RangeType
    public let size:Int
    
    public var controlPoints = [float2]() {
        didSet{
            
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

let spline = IMPSpline(range: (float2(0),float2(1)), size: 10) { (controls) -> [Float] in
    
}