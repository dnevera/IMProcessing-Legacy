//
//  ColumnView.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 22/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public struct ColumnView<Member> {
    internal var matrix: IMPMatrix<Member>
    
    internal init(matrix: IMPMatrix<Member>) {
        self.matrix = matrix
    }
}

extension ColumnView: ExpressibleByArrayLiteral {
    public init() {
        self.matrix = IMPMatrix()
    }
    
    public init<S: Sequence>(_ columns: S) where S.Iterator.Element == [Member] {
        self.init()
        append(contentsOf: columns)
    }
    
    public init(arrayLiteral elements: [Member]...) {
        self.init(elements)
    }
}

extension ColumnView: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return Array(self).description
    }
    
    public var debugDescription: String {
        return Array(self).debugDescription
    }
}

extension ColumnView: MutableCollection, RangeReplaceableCollection {
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return 0
    }
    
    public mutating func replaceSubrange<C : Collection>(_ subRange: Range<Int>, with newElements: C) where C.Iterator.Element == [Member] {
        
        // Verify size
        let expectedCount = matrix.count > 0 ? matrix.rows.count : (newElements.first?.count ?? 0)
        newElements.forEach { column in
            precondition(column.count == expectedCount, "Incompatable vector size.")
        }
        if matrix.count == 0 { matrix.rowBacking = Array(repeating: Array(), count: expectedCount) }
        
        // Replace range
        matrix.rowBacking.indices.forEach { index in
            matrix.rowBacking[index].replaceSubrange(subRange, with: newElements.map { column in
                column[index]
            })
        }
    }
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return matrix.rowBacking.first?.count ?? 0
    }
    
    public subscript(index: Int) -> [Member] {
        get {
            return matrix.rows.indices.map{ i in matrix[row: i, column: index] }
        }
        set {
            precondition(newValue.count == matrix.rows.count, "Incompatible vector size.")
            zip(matrix.rows.indices, newValue).forEach { (i, v) in matrix[row: i, column: index] = v }
        }
    }
}
