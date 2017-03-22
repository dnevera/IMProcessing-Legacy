//
//  RowView.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 22/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public struct RowView<Member> {
    internal var matrix: IMPMatrix<Member>
    
    internal init(matrix: IMPMatrix<Member>) {
        self.matrix = matrix
    }
}

extension RowView: ExpressibleByArrayLiteral {
    public init() {
        self.matrix = IMPMatrix()
    }
    
    public init<S: Sequence>(_ rows: S) where S.Iterator.Element == [Member] {
        self.init()
        append(contentsOf: rows)
    }
    
    public init(arrayLiteral elements: [Member]...) {
        self.init(elements)
    }
}

extension RowView: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return Array(self).description
    }
    
    public var debugDescription: String {
        return Array(self).debugDescription
    }
}

extension RowView: MutableCollection, RangeReplaceableCollection {
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return 0
    }
    
    public mutating func replaceSubrange<C : Collection>(_ subRange: Range<Int>, with newElements: C) where C.Iterator.Element == [Member] {
        let expectedCount = matrix.count > 0 ? matrix.columns.count : (newElements.first?.count ?? 0)
        newElements.forEach{ row in
            precondition(row.count == expectedCount, "Incompatable vector size.")
        }
        matrix.rowBacking.replaceSubrange(subRange, with: newElements)
    }
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return matrix.rowBacking.count
    }
    
    public subscript(index: Int) -> [Member] {
        get {
            return matrix.rowBacking[index]
        }
        set {
            precondition(newValue.count == matrix.columns.count, "Incompatible vector size.")
            matrix.rowBacking[index] = newValue
        }
    }
}

