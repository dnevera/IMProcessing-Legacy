//
//  IMPMatrix.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 22/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

//
// Sources: https://github.com/JadenGeller/Dimensional
//

/**
 
 While a Matrix can be parameterized by any type, it is most useful if it is parameterized by some numeric type since it gains tons of special abilities!
 
 let a: Matrix = [[1, 2], [3, 4]]
 let b: Matrix = [[5, 10], [-5, 0]]
 
 print(a.determinant)      // -> -2
 print(a.dot(b) * (a + b)) // -> [[60, 120], [-20, 40]]
 print(a * b)              // -> [[-5, 10], [-5, 30]]
 Matrices composed of floating point types gain even more amazing powers, such as the ability to take an inverse!
 
 Not only does Matrix conform to MutableCollectionType, but it exposes two views RowView and ColumnView each of which conform to RangeReplaceableCollectionType allowing for complex manipulations.
 
 var x: Matrix = [[1, 2], [3, 4]]
 x.rows.append([5, 6])
 x.columns.insert([3, 6, 9], atIndex: 2)
 print(x) // -> [[1, 2, 3], [3, 4, 6], [5, 6, 9]]
 
 */

public struct IMPMatrix<Member> {
    internal var rowBacking: [[Member]]
    public var rawValue:[[Member]]{
        return rowBacking
    }
}

extension IMPMatrix: ExpressibleByArrayLiteral {
    public init() {
        self.rowBacking = []
    }
    
    public init(_ rows: [[Member]]) {
        self.init(RowView(rows))
    }
    
    public init(arrayLiteral elements: [Member]...) {
        self.init(elements)
    }
    
    public init(_ rows: RowView<Member>) {
        self.rowBacking = rows.matrix.rowBacking
    }
    
    public init(_ columns: ColumnView<Member>) {
        self.rowBacking = columns.matrix.rowBacking
    }
}

public extension IMPMatrix {
    public subscript(row row: Int, column column: Int) -> Member {
        get {
            return rowBacking[row][column]
        }
        set {
            rowBacking[row][column] = newValue
        }
    }
    
    public var rows: RowView<Member> {
        get {
            return RowView(matrix: self)
        }
        set {
            self = IMPMatrix(newValue)
        }
    }
    
    public var columns: ColumnView<Member> {
        get {
            return ColumnView(matrix: self)
        }
        set {
            self = IMPMatrix(newValue)
        }
    }
}

extension IMPMatrix: Collection {
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return 0
    }
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return rows.count * columns.count
    }
    
    public func positionWithIndex(_ index: Int) -> (row: Int, column: Int) {
        return (row: index / columns.count, column: index % columns.count)
    }
    
    public subscript(index: Int) -> Member {
        get {
            let position = positionWithIndex(index)
            return self[row: position.row, column: position.column]
        }
        set {
            let position = positionWithIndex(index)
            self[row: position.row, column: position.column] = newValue
        }
    }
}

extension IMPMatrix: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return rows.description
    }
    
    public var debugDescription: String {
        return rows.debugDescription
    }
}

public func ==<Member: Equatable>(lhs: IMPMatrix<Member>, rhs: IMPMatrix<Member>) -> Bool {
    return lhs.rowBacking.count == rhs.rowBacking.count && zip(lhs.rowBacking, rhs.rowBacking).reduce(true) { result, pair in result && pair.0 == pair.1 }
}

extension IMPMatrix {
    public func map<T>(transform: @escaping (Member) throws -> T) rethrows -> IMPMatrix<T> {
        return IMPMatrix<T>(RowView(try rows.map{ try $0.map(transform) }))
    }
    
    public func map<T>(transform:  @escaping (Member, _ row: Int, _ column: Int) throws -> T) rethrows -> IMPMatrix<T> {
        return IMPMatrix<T>(RowView(try rows.enumerated().map{ (r, columns) in
            try columns.enumerated().map{ (c, value) in
                try transform(value, r, c)
            }
            }))
    }
    
    public func zipWith<U, V>(_ matrix: IMPMatrix<U>, transform: @escaping (Member, U) -> V) -> IMPMatrix<V> {
        return IMPMatrix<V>(RowView(zip(self.rows, matrix.rows).map{ zip($0, $1).map(transform) }))
    }
}

extension IMPMatrix {
    public var isSquare: Bool {
        return rows.count == columns.count
    }
    
    public var transpose: IMPMatrix {
        return IMPMatrix(RowView(columns))
    }
}


public struct IMPMatrixDimensions{
    let width:Int
    let height:Int
    var dim:Int {
        return width < height ? width : height
    }
}

extension IMPMatrix where Member: ExpressibleByIntegerLiteral {
    
    public static func diagonal(_ dim: IMPMatrixDimensions, diagonalValue: Member, defaultValue: Member) -> IMPMatrix {
        var matrix = IMPMatrix(dimensions: dim, repeatedValue: defaultValue)
        for i in 0..<dim.dim {
            matrix[row: i, column: i] = diagonalValue
        }
        return matrix
    }
    
    public static func diagonal(_ dim: IMPMatrixDimensions) -> IMPMatrix {
        return diagonal(dim, diagonalValue: 1, defaultValue: 0)
    }
    
    public static func identity(size: Int) -> IMPMatrix {
        return diagonal(IMPMatrixDimensions(width: size, height: size))
    }
}


extension IMPMatrix {
    public init(dimensions: IMPMatrixDimensions, repeatedValue: Member) {
        self.rowBacking = Array(repeating: Array(repeating: repeatedValue, count: dimensions.width), count: dimensions.height)
    }
    
    public init(dimensions: (width:Int,height:Int), repeatedValue: Member) {
        self.rowBacking = Array(repeating: Array(repeating: repeatedValue, count: dimensions.width), count: dimensions.height)
    }
    
    public var dimensions: IMPMatrixDimensions {
        return IMPMatrixDimensions(width: columns.count, height: rows.count)
    }
}

public func ==(lhs: IMPMatrixDimensions, rhs: IMPMatrixDimensions) -> Bool {
    return lhs.width == rhs.width && lhs.height == rhs.height
}









