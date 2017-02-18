//
//  IMPFunction.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 12.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

public class IMPFunction: IMPContextProvider, Equatable {
    
    public struct GroupSize {
        public var width:Int  = 16
        public var height:Int = 16
    }
    
    public let name:String
    public var context:IMPContext
    public var groupSize:GroupSize = GroupSize()
    public var threadsPerThreadgroup:MTLSize {
        return MTLSizeMake(groupSize.width, groupSize.height, 1)
    }
    public var kernel:MTLFunction? { return _kernel }
    public var library:MTLLibrary { return context.defaultLibrary }
    public var pipeline:MTLComputePipelineState? { return _pipeline }
    public var uid:String {return _uid}
    
    public var optionsHandler:((_ function:IMPFunction, _ command:MTLComputeCommandEncoder)->Void)? = nil
    
    public required init(context:IMPContext, name:String) {
        self.context = context
        self.name = name
    }
    
    public static func == (lhs: IMPFunction, rhs: IMPFunction) -> Bool {
        //return lhs.name == rhs.name && lhs.context.device === rhs.context.device
        return lhs.uid == rhs.uid
    }
    
    
    private lazy var _kernel:MTLFunction? = {
        return self.library.makeFunction(name: self.name)
    }()
    
    private lazy var _pipeline:MTLComputePipelineState? = {
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
    
    private lazy var _uid:String = self.context.uid + ":" + self.name
}
