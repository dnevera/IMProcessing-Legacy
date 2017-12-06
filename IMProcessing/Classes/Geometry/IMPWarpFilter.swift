//
//  IMPWarpPerspectiveFilter.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


import Metal

/// Warp transformation filter
open class IMPWarpFilter: IMPFilter, IMPGraphicsProvider {
    
    open var model:float4x4 {
        return transformation
    }

    /// Source image quad
    open var sourceQuad = IMPQuad() {
        didSet{
            transformation = sourceQuad.transformTo(destination: destinationQuad)
            dirty = true
        }
    }
    
    /// Destination image quad
    open var destinationQuad = IMPQuad() {
        didSet{
            transformation = sourceQuad.transformTo(destination: destinationQuad)
            dirty = true
        }
    }
    
    open var backgroundColor:IMPColor = IMPColor.white
    
    /// Graphic function
    open var graphics:IMPGraphics!
    
    /// Create Warp with new graphic function
    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_warpTransformation", fragment: "fragment_passthrough")
    }
    
    open override func main(source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider? {
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                var width  = texture.width.float
                var height = texture.height.float
                                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                        pixelFormat: texture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    provider.texture = self.context.device.makeTexture(descriptor: descriptor)
                }
                
                self.renderPassDescriptor.colorAttachments[0].texture = provider.texture
                self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
                self.renderPassDescriptor.colorAttachments[0].clearColor = self.clearColor
                self.renderPassDescriptor.colorAttachments[0].storeAction = .store
                
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: self.renderPassDescriptor)
                                
                renderEncoder?.setRenderPipelineState(self.graphics.pipeline!)
                
                renderEncoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
                renderEncoder?.setVertexBuffer(self.matrixBuffer, offset: 0, index: 1)
                
                renderEncoder?.setFragmentTexture(source.texture, index:0)
                
                renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: self.vertices.count, instanceCount: self.vertices.count/3)
                renderEncoder?.endEncoding()
            }
        }
        return provider
    }
    
    var renderPassDescriptor = MTLRenderPassDescriptor()
    
    var transformation = float4x4(diagonal:float4(1)){
        didSet{
            var m = transformation.cmatrix
            memcpy(_matrixBuffer.contents(), &m, _matrixBuffer.length)
        }
    }
    
    lazy var _matrixBuffer:MTLBuffer = {
        var m = self.transformation.cmatrix
        var mm = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.transformation.cmatrix), options: MTLResourceOptions())
        memcpy(mm?.contents(), &m, (mm?.length)!)
        return mm!
    }()

    var matrixBuffer: MTLBuffer {
        get {
            return _matrixBuffer
        }
    }
    
    lazy var vertices = IMPPhotoPlate(aspect: 1, region: IMPRegion())
    
    lazy var vertexBuffer: MTLBuffer = {
        return self.context.device.makeBuffer(bytes: self.vertices.raw, length: self.vertices.length, options: MTLResourceOptions())
    }()!
}
