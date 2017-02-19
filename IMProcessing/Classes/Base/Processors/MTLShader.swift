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
    
    override func processBigImage(image:CIImage, index:Int) -> CIImage? {
            return processImage(image: image)
    }
    
    override func processImage(image:CIImage) -> CIImage? {
        if let shader = shader
        {
            return process(image: image,
                           in: shader.context,
                           threadsPerThreadgroup: MTLSize(width: 1,height: 1,depth: 1),
                           command: {
                            (commandBuffer, threadgroups, threadsPerThreadgroup, input, output) in
                            
                            if let sourceTexture      = input,
                                let destinationTexture = output{
                             
                                
                                
                            }
            })
        }
        return nil
    }
}

