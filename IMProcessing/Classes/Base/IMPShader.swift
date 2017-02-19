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

public class IMPShader: IMPContextProvider, IMPShaderProvider, Equatable {
   
    public var backgroundColor: NSColor = NSColor.clear
    public let vertexName:String
    public let fragmentName:String
    public var uid:String {return _uid}
    public var context:IMPContext
    public var name:String {
        return _name
    }
    
    public var verticesBuffer:MTLBuffer {
        return _verticesBuffer
    }
    
    public var vertices:IMPVertices! {
        didSet{
            _verticesBuffer = context.device.makeBuffer(bytes: vertices.raw, length: vertices.length, options: [])
        }
    }
    
    public func commandEncoder(from buffer: MTLCommandBuffer, width destination: MTLTexture?) -> MTLRenderCommandEncoder {
        
        renderPassDescriptor.colorAttachments[0].texture     = destination
        renderPassDescriptor.colorAttachments[0].loadAction  = .clear
        renderPassDescriptor.colorAttachments[0].clearColor  = self.clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        let encoder = buffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder.setCullMode(.front)
        encoder.setRenderPipelineState(pipeline!)
        return encoder
    }

    
    public var optionsHandler:((
        _ function:IMPShader,
        _ command:MTLRenderCommandEncoder,
        _ inputTexture:MTLTexture?,
        _ outputTexture:MTLTexture?)->Void)? = nil
    
    
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
    
    public required init(context:IMPContext,
                         vertex:String,
                         fragment:String,
                         withName:String? = nil,
                         vertexDescriptor:MTLVertexDescriptor? = nil) {
        self.context = context
        self.vertexName = vertex
        self.fragmentName = fragment
        self._vertexDescriptor = vertexDescriptor
        if withName != nil {
            self._name = withName!
        }
        defer {
            vertices = IMPPhotoPlate()
        }
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
    
    lazy var renderPassDescriptor:MTLRenderPassDescriptor = {
        return MTLRenderPassDescriptor()
    }()

    private lazy var _name:String = self.vertexName + ":" + self.fragmentName
    private lazy var _uid:String = self.context.uid + ":" + self._name
    var _verticesBuffer: MTLBuffer!
}
