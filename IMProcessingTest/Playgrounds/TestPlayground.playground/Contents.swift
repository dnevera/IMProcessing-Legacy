//: Playground - noun: a place where people can play

import Cocoa
import Metal

var str = "Hello, playground"

var a = [1,2,3,4,34,4,56,13,34,5,6,6,6]

a.count.toIntMax()

a.indices.count.toIntMax()


MemoryLayout.size(ofValue: a) * Int(a.count.toIntMax())

let dev = MTLCreateSystemDefaultDevice()
let d = dev?.maxThreadsPerThreadgroup

print(d)


var bits = 0b0000

bits |= 0b0001
bits |= 0b0010
bits |= 0b0100
bits |= 0b1000

(((bits % 0b1111) == 0) && bits>0)