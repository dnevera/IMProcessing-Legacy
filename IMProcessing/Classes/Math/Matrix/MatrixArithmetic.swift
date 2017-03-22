//
//  MatrixArithmetic.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 22/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public protocol NumericArithmeticType: ExpressibleByIntegerLiteral {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
    
    static func +=(lhs: inout Self, rhs: Self)
    static func -=(lhs: inout Self, rhs: Self)
    static func *=(lhs: inout Self, rhs: Self)
    static func /=(lhs: inout Self, rhs: Self)
}

public protocol SignedNumericArithmeticType: NumericArithmeticType {
    prefix static func -(value: Self) -> Self
}

public protocol FloatingPointArithmeticType: SignedNumericArithmeticType { }

extension Int8   : SignedNumericArithmeticType { }
extension Int16  : SignedNumericArithmeticType { }
extension Int32  : SignedNumericArithmeticType { }
extension Int64  : SignedNumericArithmeticType { }
extension Int    : SignedNumericArithmeticType { }
extension UInt8  : NumericArithmeticType { }
extension UInt16 : NumericArithmeticType { }
extension UInt32 : NumericArithmeticType { }
extension UInt64 : NumericArithmeticType { }
extension UInt   : NumericArithmeticType { }
extension Float32 : FloatingPointArithmeticType { }
extension Float64 : FloatingPointArithmeticType { }
extension Float80 : FloatingPointArithmeticType { }

//public prefix func -<T: SignedNumericArithmeticType>(value: IMPMatrix<T>) -> IMPMatrix<T> {
//    return value.map(-)
//}

public func *<T: NumericArithmeticType>(lhs: T, rhs: IMPMatrix<T>) -> IMPMatrix<T> {
    return rhs.map { lhs * $0 }
}

public func *<T: NumericArithmeticType>(lhs: IMPMatrix<T>, rhs: T) -> IMPMatrix<T> {
    return lhs.map { rhs * $0 }
}

public func +<T: NumericArithmeticType>(lhs: IMPMatrix<T>, rhs: IMPMatrix<T>) -> IMPMatrix<T> {
    precondition(lhs.dimensions == rhs.dimensions, "Cannot add matrices of different dimensions.")
    return lhs.zipWith(rhs, transform: +)
}

public func -<T: NumericArithmeticType>(lhs: IMPMatrix<T>, rhs: IMPMatrix<T>) -> IMPMatrix<T> {
    precondition(lhs.dimensions == rhs.dimensions, "Cannot subract matrices of different dimensions.")
    return lhs.zipWith(rhs, transform: -)
}

extension IMPMatrix where Member: NumericArithmeticType {
    public func dot(_ other: IMPMatrix<Member>) -> Member {
        precondition(dimensions == other.dimensions, "Cannot take the dot product of matrices of different dimensions.")
        return zipWith(other, transform: *).reduce(0, +)
    }
}

extension IMPMatrix where Member: SignedNumericArithmeticType {
    public var determinant: Member {
        precondition(isSquare, "Cannot find the determinant of a non-square IMPMatrix.")
        precondition(!isEmpty, "Cannot find the determinant of an empty IMPMatrix.")
        
        guard count != 1 else { return self[row: 0, column: 0] } // Base case
        
        // Recursive case
        var sum: Member = 0
        var polarity: Member = 1
        
        let topRow = rows[0]
        for (column, value) in topRow.enumerated() {
            var subMatrix = self
            subMatrix.rows.removeFirst()
            subMatrix.columns.remove(at: column)
            sum += polarity * value * subMatrix.determinant
            
            polarity *= -1
        }
        
        return sum
    }
    
    public var cofactor: IMPMatrix {
        return map { (value, row, column) in
            var subMatrix = self
            subMatrix.rows.remove(at: row)
            subMatrix.columns.remove(at: column)
            let polarity: Member = ((row + column) % 2 == 0 ? 1 : -1)
            return subMatrix.determinant * polarity
        }
    }
    
    public var adjoint: IMPMatrix {
        return cofactor.transpose
    }
}

extension IMPMatrix where Member: FloatingPointArithmeticType {
    public var inverse: IMPMatrix {
        return adjoint * (1 / determinant)
    }
}

extension IMPMatrix where Member: NumericArithmeticType {
    public func transformVector(_ vector: [Member]) -> [Member] {
        return rows.map{ row in zip(row, vector).map(*).reduce(0, +) }
    }
}

public func *<T: NumericArithmeticType>(lhs: IMPMatrix<T>, rhs: IMPMatrix<T>) -> IMPMatrix<T> {
    precondition(lhs.columns.count == rhs.rows.count, "Incompatible dimensions for IMPMatrix multiplication.")
    return IMPMatrix(lhs.rows.map(rhs.transpose.transformVector))
}

