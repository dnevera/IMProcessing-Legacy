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
infix operator ==> : AdditionPrecedence


/// Async redirect source image frame to another filter
///
/// - Parameters:
///   - sourceFilter: source image frame updatable filter
///   - destinationFilter: destination filter which should recieve the same source image frames
/// - Returns: destination filter
///
@discardableResult public func =><T:IMPFilter>(sourceFilter:T, destinationFilter:T) -> T {
    sourceFilter.addObserver(newSource: { (source) in
        destinationFilter.source = source
    })
    return destinationFilter
}


/// Async redirect result image frames to enclosure process block
///
/// - Parameters:
///   - filter: processed filter
///   - action: next processing action
/// - Returns: filter
///
@discardableResult public func --><T:IMPFilter>(filter:T, action:  @escaping ((_ image:IMPImageProvider) -> Void)) -> T {
    filter.addObserver(newSource:{ (source) in
        filter.context.runOperation(.async, {
            filter.process()
        })
    })

    filter.addObserver(destinationUpdated: {(destination) in
        filter.context.runOperation(.async) {
            action(destination)
        }
    })
    
    return filter
}

/// Async redirect result image frames to next processing filter
///
/// - Parameters:
///   - sourceFilter: source filter which processed image frames
///   - destinationFilter: next filter which should process next processing stage
/// - Returns: next filter
//
@discardableResult public func --><T:IMPFilter>(sourceFilter:T, nextFilter:T) -> T {
    
    sourceFilter.addObserver(newSource:{ (source) in
        sourceFilter.context.runOperation(.async, {
            sourceFilter.process()
        })
    })
    
    sourceFilter.addObserver(destinationUpdated: { (destination) in
        nextFilter.context.runOperation(.async, {
            nextFilter.source = destination
            nextFilter.process()
        })
    })
    
    return nextFilter
}


/// Async redirect source(!) image frames to next processing filter
///
/// - Parameters:
///   - sourceFilter: source filter which processed image frames
///   - destinationFilter: next filter which should process next processing stage
/// - Returns: next filter
//
@discardableResult public func ==><T:IMPFilter>(sourceFilter:T, nextFilter:T) -> T {
    
    sourceFilter.addObserver(newSource:{ (source) in
        sourceFilter.context.runOperation(.async, {
            sourceFilter.process()
        })
    })
    
    sourceFilter.addObserver(newSource: { (source) in
        nextFilter.context.runOperation(.async, {
            nextFilter.source = source
            nextFilter.process()
        })
    })
    
    return nextFilter
}
