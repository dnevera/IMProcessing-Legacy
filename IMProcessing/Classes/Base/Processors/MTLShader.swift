//
//  MTLShader.swift
//  Pods
//
//  Created by denis svinarchuk on 19.02.17.
//
//

import Metal
import MetalPerformanceShaders
import CoreImage

class IMPCoreImageMTLShader: IMPCIFilter{
    
    override var destinationSize: NSSize? {
        set{
            shader?.destinationSize = newValue
        }
        get{
            return shader?.destinationSize
        }
    }

    static var registeredShaderList:[IMPShader] = [IMPShader]()
    static var registeredFilterList:[String:IMPCoreImageMTLShader] = [String:IMPCoreImageMTLShader]()
    
    static func register(shader:IMPShader) -> IMPCoreImageMTLShader {
        if let filter = registeredFilterList[shader.uid] {
            return filter
        }
        else {
            let filter = IMPCoreImageMTLShader()
            if #available(iOS 10.0, *) {
                filter.name = shader.name
            } else {
                // Fallback on earlier versions
                fatalError("IMPCoreImageMPSUnaryKernel: ios >10.0 supports only")
            }
            filter.shader = shader
            filter.context = shader.context
            registeredFilterList[shader.uid] = filter
            return filter
        }
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        return self.shader?.uid == (object as? IMPCoreImageMTLShader)?.shader?.uid
    }
    
    var shader: IMPShader? {
        didSet{
            guard let f = shader else {
                return
            }
            if let index = IMPCoreImageMTLShader.registeredShaderList.index(of: f) {
                kernelIndex = index
            }
            else {
                kernelIndex = IMPCoreImageMTLShader.registeredShaderList.count
                IMPCoreImageMTLShader.registeredShaderList.append(f)
            }
        }
    }
    
    override func textureProcessor(_ commandBuffer: MTLCommandBuffer,
                                   _ threadgroups: MTLSize,
                                   _ threadsPerThreadgroup: MTLSize,
                                   _ source: IMPImageProvider,
                                   _ destination: IMPImageProvider) {
        if let sourceTexture = source.texture,
            let shader   = self.shader,
            let vertices = shader.vertices,
            let destinationTexture = destination.texture
            {
            
            let renderEncoder = shader.commandEncoder(from: commandBuffer, width: destinationTexture)
            
            renderEncoder.setVertexBuffer(shader.verticesBuffer, offset: 0, at: 0)
            renderEncoder.setFragmentTexture(sourceTexture, at:0)
            
            if let handler = shader.optionsHandler {
                handler(shader, renderEncoder, sourceTexture, destinationTexture)
            }
            
            renderEncoder.drawPrimitives(type: .triangle,
                                         vertexStart: 0,
                                         vertexCount: vertices.count,
                                         instanceCount: vertices.count/3)
            renderEncoder.endEncoding()
        }
    }    
}

