    //
//  IMPFunction.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 16.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

open class IMPFunction: NSObject, IMPContextProvider {

    //
    // inherits ==/!= from NSObject
    //
    
    public struct GroupSize {
        public var width:Int  = 16
        public var height:Int = 16
    }

    open let name:String
    open var context:IMPContext!
    open var groupSize:GroupSize = GroupSize()

    open lazy var kernel:MTLFunction? = {
        return self.library.makeFunction(name: self.name)
    }()
    
    open lazy var library:MTLLibrary = {
        return self.context.defaultLibrary
    }()
    
    open lazy var pipeline:MTLComputePipelineState? = {
        if self.kernel == nil {
            fatalError(" *** IMPFunction: \(self.name) has not foumd...")
        }
        do{
            return try self.context.device.makeComputePipelineState(function: self.kernel!)
        }
        catch let error as NSError{
            fatalError(" *** IMPFunction: \(error)")
        }
    }()
    
    public required init(context:IMPContext, name:String) {
        self.context = context
        self.name = name
    }
}
