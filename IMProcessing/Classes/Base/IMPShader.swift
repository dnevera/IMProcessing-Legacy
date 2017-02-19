//
//  IMPShader.swift
//  Pods
//
//  Created by denis svinarchuk on 19.02.17.
//
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal
import simd

public protocol IMPShaderProvider {
    var backgroundColor:NSColor {get set}
}

extension IMPShaderProvider{
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

public class IMPShader: IMPContextProvider, Equatable {
    
    public let vertexName:String
    public let fragmentName:String
    public var uid:String {return _uid}
    public var context:IMPContext
    
    public var optionsHandler:((_ function:IMPShader, _ command:MTLRenderCommandEncoder)->Void)? = nil

    public var library:MTLLibrary {
        return self.context.defaultLibrary
    }
    
    public lazy var pipeline:MTLRenderPipelineState? = {
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
    
    public static func == (lhs: IMPShader, rhs: IMPShader) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    lazy var _defaultVertexDescriptor:MTLVertexDescriptor = {
        var v = MTLVertexDescriptor()
        v.attributes[0].format = .float3
        v.attributes[0].bufferIndex = 0
        v.attributes[0].offset = 0
        v.attributes[1].format = .float3
        v.attributes[1].bufferIndex = 0
        v.attributes[1].offset = MemoryLayout<float3>.size
        v.layouts[0].stride = MemoryLayout<IMPVertex>.size
        
        return v
    }()
    
    var _vertexDescriptor:MTLVertexDescriptor?
    public var vertexDescriptor:MTLVertexDescriptor {
        return _vertexDescriptor ?? _defaultVertexDescriptor
    }
    
    private lazy var _uid:String = self.context.uid + ":" + self.vertexName + ":" + self.fragmentName
}
