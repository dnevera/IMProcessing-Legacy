//
//  IMPGraphics.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

public protocol IMPGraphicsProvider {
    var backgroundColor:IMPColor {get set}
    //var graphics:IMPGraphics! {get}
}

extension IMPGraphicsProvider{
    public var clearColor:MTLClearColor {
        get {
            let rgba = backgroundColor.rgba
            let color = MTLClearColor(red:   rgba.r.double,
                                      green: rgba.g.double,
                                      blue:  rgba.b.double,
                                      alpha: rgba.a.double)
            return color
        }
    }
}

open class IMPGraphics: NSObject, IMPContextProvider {
    
    open let vertexName:String
    open let fragmentName:String
    open var context:IMPContext!
    
    open lazy var library:MTLLibrary = {
        return self.context.defaultLibrary
    }()
    
    open lazy var pipeline:MTLRenderPipelineState? = {
        do {
            let renderPipelineDescription = MTLRenderPipelineDescriptor()
            
            renderPipelineDescription.vertexDescriptor = self.vertexDescriptor 
            
            renderPipelineDescription.colorAttachments[0].pixelFormat = IMProcessing.colors.pixelFormat
            renderPipelineDescription.vertexFunction   = self.context.defaultLibrary.makeFunction(name: self.vertexName)
            renderPipelineDescription.fragmentFunction = self.context.defaultLibrary.makeFunction(name: self.fragmentName)
            
            return try self.context.device.makeRenderPipelineState(descriptor: renderPipelineDescription)
        }
        catch let error as NSError{
            fatalError(" *** IMPGraphics: \(error)")
        }
    }()
    
    public required init(context:IMPContext, vertex:String, fragment:String, vertexDescriptor:MTLVertexDescriptor? = nil) {                
        self.context = context
        self.vertexName = vertex
        self.fragmentName = fragment
        self._vertexDescriptor = vertexDescriptor        
    }
    
    lazy var _defaultVertexDescriptor:MTLVertexDescriptor = {
        var v = MTLVertexDescriptor()
        v.attributes[0].format = .float3;
        v.attributes[0].bufferIndex = 0;
        v.attributes[0].offset = 0;
        v.attributes[1].format = .float3;
        v.attributes[1].bufferIndex = 0;
        v.attributes[1].offset = MemoryLayout<float3>.size;  
        v.layouts[0].stride = MemoryLayout<IMPVertex>.size 
        
        return v
    }()
    
    var _vertexDescriptor:MTLVertexDescriptor? 
    open var vertexDescriptor:MTLVertexDescriptor {
        return _vertexDescriptor ?? _defaultVertexDescriptor
    }     
}
