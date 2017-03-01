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

public protocol IMPDestinationSizeProvider {
    var destinationSize:NSSize? {get set}
}

public class IMPFunction: IMPContextProvider, IMPDestinationSizeProvider, Equatable {
    
    public struct GroupSize {
        public var width:Int  = 16
        public var height:Int = 16
    }
    
    public var destinationSize: NSSize?
    public var kernelName:String
    public var name:String {
        return _name
    }
    public var context:IMPContext
    public var groupSize:GroupSize = GroupSize()
    public var threadsPerThreadgroup:MTLSize {
        return MTLSizeMake(groupSize.width, groupSize.height, 1)
    }
    public var kernel:MTLFunction? { return _kernel }
    public var library:MTLLibrary { return context.defaultLibrary }
    public var pipeline:MTLComputePipelineState? { return _pipeline }
    
    public func commandEncoder(from buffer: MTLCommandBuffer) -> MTLComputeCommandEncoder {
        let encoder = buffer.makeComputeCommandEncoder()
        encoder.setComputePipelineState(pipeline!)
        return encoder
    }
    
    let _name:String
    
    public var optionsHandler:((
        _ function:IMPFunction,
        _ command:MTLComputeCommandEncoder,
        _ inputTexture:MTLTexture?,
        _ outputTexture:MTLTexture?)->Void)? = nil
    
    public required init(context:IMPContext,
                         kernelName:String = "kernel_passthrough",
                         name:String? = nil) {
        self.context = context
        self.kernelName = kernelName
        
        if name != nil {
            self._name = name!
        }
        else {
            self._name = context.uid + ":"  + String.uniqString() + ":" + self.kernelName
        }
    }
    
    public static func == (lhs: IMPFunction, rhs: IMPFunction) -> Bool {
        return lhs.name == rhs.name
    }
    
    private lazy var _kernel:MTLFunction? = {
        return self.library.makeFunction(name: self.kernelName)
    }()
    
    private lazy var _pipeline:MTLComputePipelineState? = {
        if self.kernel == nil {
            fatalError(" *** IMPFunction: \(self.name) has not found...")
        }
        do{
            return try self.context.device.makeComputePipelineState(function: self.kernel!)
        }
        catch let error as NSError{
            fatalError(" *** IMPFunction: \(error)")
        }
    }()
}
