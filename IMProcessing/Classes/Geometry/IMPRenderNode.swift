//
//  IMPRenderNode.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 26.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// 3D Node rendering
open class IMPRenderNode: IMPContextProvider {
    
    public enum ReflectMode {
        case mirroring
        case none
    }    
    
    open var context:IMPContext!
    
    open var model:IMPTransfromModel {
        get{
            return currentMatrixModel
        }
    }

    open var identityModel:IMPTransfromModel {
        get{
            var matrix = matrixIdentityModel
            matrix.projection.aspect = aspect
            matrix.projection.fovy   = fovy
            matrix.projection.near   = 0
            matrix.projection.far    = 1
            matrix.scale = float3(1)
            matrix.angle = float3(0)
            matrix.translation = float3(0)
            return matrix
        }
    }

    open var aspect = Float(1) {
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Angle in radians which node rotation in scene
    open var angle = float3(0) {
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    
    /// Node scale
    open var scale = float3(1){
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    ///
    open var rotationPoint = float2(0) {
        didSet {
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Node translation
    open var translation = float2(0){
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Field of view in radians
    open var fovy:Float = M_PI.float/2{
        didSet{
            updateMatrixModel(currentDestinationSize)
        }
    }
    
    /// Flip mode
    open var reflectMode:(horizontal:ReflectMode, vertical:ReflectMode) = (horizontal:.none, vertical:.none) {
        didSet{
            switch reflectMode.horizontal {
            case .mirroring:
                reflectionVector.x =  1
                reflectionVector.y = -1
            default:
                reflectionVector.x =  0
                reflectionVector.y =  1
            }
            switch reflectMode.vertical {
            case .mirroring:
                reflectionVector.z =  1
                reflectionVector.w = -1
            default:
                reflectionVector.z =  0
                reflectionVector.w =  1                
            }
        }
    }
   
    /// Create Node
    public init(context: IMPContext, vertices: IMPVertices){
        self.context = context
        defer{
            self.vertices = vertices
            self.currentMatrixModel = matrixIdentityModel
        }
    }
    
    ///  Render node
    ///
    ///  - parameter commandBuffer: command buffer
    ///  - parameter pipelineState: graphics pipeline
    ///  - parameter source:        source texture
    ///  - parameter destination:   destination texture
    open func render(_ commandBuffer: MTLCommandBuffer,
                       pipelineState: MTLRenderPipelineState,
                       source: IMPImageProvider,
                       destination: IMPImageProvider,
                       clearColor:MTLClearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1),
                       configure: ((_ command:MTLRenderCommandEncoder)->Void)?=nil
        ) {
        
        currentDestination = destination
        
        if let input = source.texture {
            if let texture = destination.texture {
                render(commandBuffer, pipelineState: pipelineState, source: input, destination: texture, clearColor: clearColor, configure: configure)
            }
        }
     }
    
    open func render(_ commandBuffer:  MTLCommandBuffer,
                       pipelineState: MTLRenderPipelineState,
                       source: MTLTexture,
                       destination: MTLTexture,
                       clearColor:MTLClearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1),
                       configure: ((_ command:MTLRenderCommandEncoder)->Void)?=nil
        ) {
        
        
        let width  = destination.width
        let height = destination.height
        let depth  = destination.depth
        
        currentDestinationSize = MTLSize(width: width,height: height,depth:depth)
        
        renderPassDescriptor.colorAttachments[0].texture = destination
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = clearColor
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        renderEncoder?.setCullMode(.front)
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.setVertexBuffer(matrixBuffer, offset: 0, index: 1)
        
        renderEncoder?.setFragmentBuffer(flipVectorBuffer, offset: 0, index: 0)
        renderEncoder?.setFragmentTexture(source, index:0)
        
        if let configure = configure {
            configure(renderEncoder!)
        }
        
        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: vertices.count/3)
        renderEncoder?.endEncoding()
    }
    
    open var vertices:IMPVertices! {
        didSet{
            vertexBuffer = context.device.makeBuffer(bytes: vertices.raw, length: vertices.length, options: MTLResourceOptions())
        }
    }
    
    lazy var renderPassDescriptor:MTLRenderPassDescriptor = {
        return MTLRenderPassDescriptor()                
    }()
    
    var vertexBuffer: MTLBuffer!
    
    var matrixIdentityModel:IMPTransfromModel {
        get{
            var m = IMPTransfromModel()
            m.translation.z = -1
            return m
        }
    }
    
    var reflectionVector = float4(0,1,0,1)
    
    lazy var _reflectionVectorBuffer:MTLBuffer = {
        return self.context.device.makeBuffer(length: MemoryLayout<float4>.size, options: MTLResourceOptions())
    }()!
    
    var flipVectorBuffer:MTLBuffer {
        memcpy(_reflectionVectorBuffer.contents(), &reflectionVector, _reflectionVectorBuffer.length)
        return _reflectionVectorBuffer
    } 

    var currentDestinationSize = MTLSize(width: 1,height: 1,depth: 1) {
        didSet {
            if oldValue.width != currentDestinationSize.width ||
            oldValue.height != currentDestinationSize.height
            {
                updateMatrixModel(currentDestinationSize)
            }
        }
    }
    
    var currentDestination:IMPImageProvider?
    
    var currentMatrixModel:IMPTransfromModel! {
        didSet {
            var matrix = currentMatrixModel.matrix
            memcpy(matrixBuffer.contents(), &matrix, matrixBuffer.length)
        }
    }
    
    func updateMatrixModel(_ size:MTLSize) -> IMPTransfromModel  {
        
        var matrix = matrixIdentityModel
        
        matrix.projection.aspect = aspect
        matrix.projection.fovy   = fovy
        matrix.projection.near   = 0
        matrix.projection.far    = 1
        
        matrix.angle = angle
        matrix.translation = float3(translation.x,translation.y,0)
        matrix.scale = scale

        currentMatrixModel = matrix
        
        return currentMatrixModel
    }
    
    lazy var matrixBuffer: MTLBuffer = {
        return self.context.device.makeBuffer(length: MemoryLayout<float4x4>.size, options: MTLResourceOptions())
    }()!
}
