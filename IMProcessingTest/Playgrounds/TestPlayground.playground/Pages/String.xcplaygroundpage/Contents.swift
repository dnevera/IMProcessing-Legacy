//: [Previous](@previous)

import Foundation

var str = "Hello, playground"


extension String  {
    var isNumber : Bool {
        get{
           //return !self.isEmpty && self.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
            return !self.isEmpty && Float(self) != nil
        }
    }
}

var n = "0.0000123"

n.isNumber

//: [Next](@next)
