//: [Previous](@previous)

import Foundation
import simd
import Accelerate


var c = [float2(1),float2(10),float2(0),float2(3)]

var p = OpaquePointer(c)
var addr = UnsafeMutablePointer<Float>(p)

var max:Float = 0

vDSP_maxv(addr+1, 2, &max, vDSP_Length(c.count))

print(max)

