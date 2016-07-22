//: Playground - noun: a place where people can play

import Cocoa
import simd
import Accelerate

public class Curves: AnyGenerator<Int>{
}



//public extension Float {
//    
//    /**
//     The code uses the recursive relation B_[i,n](u)=(1-u)*B_[i,n-1](u) + u*B_[i-1,n-1](u) to compute all nth-degree Bernstein polynomials
//     
//     - parameter count: The sum of the start point, the end point and all the knot points between
//     - self: Ranges from 0 to 1, and represents the current position of the curve
//     
//     - returns: [curve points]
//     */
//    public func bernsteinPolynom(count:Int) -> [Float] {
//        var array = [Float](count:count, repeatedValue:0)
//        
//        array[0] = 1
//        let u = 1-self
//        
//        for j in 1..<count{
//            var point:Float  = 0
//            for k in 0..<j-1 {
//                let t = array[k]
//                array[k] = point+u*t
//                point = u*t
//            }
//            array[j] = point
//        }
//        
//        return array
//    }
//    
//}
//
//public extension CollectionType where Generator.Element == Float {
//    public func bezierFunction(points:[float2]) -> [float2] {
//        var result = [float2]()
//        
//        for k in self {
//            let b = k.bernsteinPolynom(points.count)
//            var point = float2(0)
//            for j in 0..<b.count{
//                point.x = point.x + b[j]*points[j].x
//                point.y = point.y + b[j]*points[j].y
//            }
//            result.append(point)
//        }
//        
//        return result
//    }
//}
//
//let b = Float(2).bernsteinPolynom(3)
//let f = [Float](Float(0).stride(through: 1, by: 0.1))
//let bz = f.bezierFunction([float2(0.1,0), float2(0.2,0.5), float2(1,1)])
//
//print(f)
//
//for y in bz {
//    let y=y.x
//}
//
