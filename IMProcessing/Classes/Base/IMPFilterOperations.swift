//
//  IMPFilterOperations.swift
//  IMPPatchDetectorTest
//
//  Created by Denis Svinarchuk on 06/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

infix operator => : AdditionPrecedence
infix operator --> : AdditionPrecedence


/// Redirect source image frame to another filter
///
/// - Parameters:
///   - sourceFilter: source image frame updatable filter
///   - destinationFilter: destination filter which should recieve the same source image frames
/// - Returns: destination filter
///
@discardableResult public func =><T:IMPFilter>(sourceFilter:T, destinationFilter:T) -> T {
    sourceFilter.addObserver(newSource: { (source) in
        destinationFilter.source = source
        destinationFilter.process()
    })
    return destinationFilter
}


/// Redirect result image frames to enclosure process block
///
/// - Parameters:
///   - filter: processed filter
///   - action: next processing action
/// - Returns: filter
///
@discardableResult public func --><T:IMPFilter>(filter:T, action:  @escaping ((_ image:IMPImageProvider) -> Void)) -> T {
    filter.addObserver(destinationUpdated: action)
    return filter
}


/// Redirect result image frames to next processing filter
///
/// - Parameters:
///   - sourceFilter: source filter which processed image frames
///   - destinationFilter: next filter which should process next processing stage
/// - Returns: next filter
//
@discardableResult public func --><T:IMPFilter>(sourceFilter:T, nextFilter:T) -> T {
    (sourceFilter --> { (destination) in
        nextFilter.source = destination
    }).process()
    return nextFilter
}
