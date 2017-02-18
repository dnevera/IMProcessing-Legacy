//
//  MPSProcessor.swift
//  IMPCoreImageMTLKernel
//
//  Created by Denis Svinarchuk on 14/02/17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
import MetalPerformanceShaders
import CoreImage

public protocol IMPMPSUnaryKernelProvider{
    var  name: String {get}
    func mps(device:MTLDevice) -> MPSUnaryImageKernel?
    var context:IMPContext? {get}
}

class IMPMPSUnaryKernel: IMPMPSUnaryKernelProvider{
    
    func mps(device:MTLDevice) -> MPSUnaryImageKernel? {
        return mpsKernel
    }
    
    var mpsKernel:MPSUnaryImageKernel? = nil
    class func make(kernel:MPSUnaryImageKernel) -> IMPMPSUnaryKernelProvider {
        let c = IMPMPSUnaryKernel()
        c._name = kernel.label!
        c.mpsKernel = kernel
        return c
    }
    
    var name: String { return _name}
    var _name:String = ""
    
    var context: IMPContext? = nil
    
}

class IMPCoreImageMPSUnaryKernel: IMPCIFilter{
    
    static var registeredFilter:[IMPCoreImageMPSUnaryKernel] = [IMPCoreImageMPSUnaryKernel]()
    
    static func register(mps:IMPMPSUnaryKernelProvider) -> IMPCoreImageMPSUnaryKernel {
        let filter = IMPCoreImageMPSUnaryKernel()
        filter.mps = mps
        if #available(iOS 10.0, *) {
            filter.name = mps.name
        } else {
            // Fallback on earlier versions
            fatalError("IMPCoreImageMPSUnaryKernel: ios >10.0 supports only")
        }
        
        if let index = registeredFilter.index(of: filter) {
            return registeredFilter[index]
        }
        else {
            let index = registeredFilter.count
            filter.kernelIndex = index
            registeredFilter.append(filter)
            return filter
        }
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        return self.mps?.name == self.mps?.name
    }
    
    var mps: IMPMPSUnaryKernelProvider?
    
    override func processBigImage(image:CIImage, index:Int) -> CIImage? {
        do {
            if #available(iOS 10.0, *) {
                let result = try ProcessorKernel.apply(withExtent: image.extent,
                                                       inputs: [image],
                                                       arguments: ["mpsIndex" : index])
                return result
            } else {
                return processImage(image: image)
            }
        }
        catch let error as NSError {
            print("error = \(error)")
        }
        
        return nil
    }
    
    override func processImage(image:CIImage) -> CIImage? {
        if let kernel = mps
        {
            return process(image: image,
                           in: kernel.context,
                           threadsPerThreadgroup: MTLSize(width: 1,height: 1,depth: 1),
                           command: {
                            (commandBuffer, threadgroups, threadsPerThreadgroup, input, output) in
                            
                            if let sourceTexture      = input,
                                let destinationTexture = output{
                                
                                IMPCoreImageMPSUnaryKernel.imageProcessor(kernel: kernel,
                                                                     commandBuffer: commandBuffer,
                                                                     input: sourceTexture,
                                                                     output: destinationTexture)
                            }
            })
        }
        return nil
    }
    
    class func imageProcessor (
        kernel:IMPMPSUnaryKernelProvider,
        commandBuffer:MTLCommandBuffer,
        input:MTLTexture,
        output:MTLTexture
        )  {
        let device  = output.device
        
        kernel.mps(device: device)?.encode(commandBuffer: commandBuffer,
                                           sourceTexture: input,
                                           destinationTexture: output)
    }
  
    
    @available(iOS 10.0, *)
    class ProcessorKernel: CIImageProcessorKernel {
        
        class func getMPS(index:Int?) -> IMPMPSUnaryKernelProvider? {
            guard let i = index else {
                return nil
            }
            return IMPCoreImageMPSUnaryKernel.registeredFilter[i].mps
        }
        
        override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
            guard
                let input              = inputs?.first,
                let sourceTexture      = input.metalTexture,
                let destinationTexture = output.metalTexture,
                let commandBuffer      = output.metalCommandBuffer,
                let kernel             = ProcessorKernel.getMPS(index: arguments?["mpsIndex"] as? Int)
                else  {
                    return
            }
            
            IMPCoreImageMPSUnaryKernel.imageProcessor(kernel: kernel,
                                                      commandBuffer: commandBuffer,
                                                      input: sourceTexture,
                                                      output: destinationTexture)
        }
    }
}