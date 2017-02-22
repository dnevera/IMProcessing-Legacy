//
//  MTLProcessor.swift
//  IMPCoreImageMTLKernel
//
//  Created by Denis Svinarchuk on 14/02/17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
import MetalPerformanceShaders
import CoreImage

class IMPCoreImageMTLKernel: IMPCIFilter{
    
    static var registeredFunctionList:[IMPFunction] = [IMPFunction]()
    static var registeredFilterList:[String:IMPCoreImageMTLKernel] = [String:IMPCoreImageMTLKernel]()
    
    //    static func register(name: String) {
    //        CIFilter.registerName(name, constructor: IMPCIFilterConstructor() as CIFilterConstructor,
    //                              classAttributes: [
    //                                kCIAttributeFilterCategories: ["IMPCoreImage"]
    //            ])
    //    }
    
    static func register(function:IMPFunction) -> IMPCoreImageMTLKernel {
        if let filter = registeredFilterList[function.uid] {
            return filter
        }
        else {
            let filter = IMPCoreImageMTLKernel()
            if #available(iOS 10.0, *) {
                filter.name = function.name
            } else {
                // Fallback on earlier versions
                fatalError("IMPCoreImageMPSUnaryKernel: ios >10.0 supports only")
            }
            filter.function = function
            filter.context = function.context
            filter.threadsPerThreadgroup = function.threadsPerThreadgroup
            registeredFilterList[function.uid] = filter
            return filter
        }
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        return self.function?.uid == (object as? IMPCoreImageMTLKernel)?.function?.uid
    }
        
    var function: IMPFunction? {
        didSet{
            guard let f = function else {
                return
            }
            if let index = IMPCoreImageMTLKernel.registeredFunctionList.index(of: f) {
                kernelIndex = index
            }
            else {
                kernelIndex = IMPCoreImageMTLKernel.registeredFunctionList.count
                IMPCoreImageMTLKernel.registeredFunctionList.append(f)
            }
        }
    }
    
    override func processBigImage(image:CIImage, index:Int) -> CIImage? {
        do {
            if #available(iOS 10.0, *) {
                let result = try ProcessorKernel.apply(withExtent: image.extent,
                                                       inputs: [image],
                                                       arguments: ["functionIndex" : index])
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
    
//    override func processImage(image:CIImage) -> CIImage? {
//        if let kernel = function
//        {
//            return process(image: image,
//                           command: {
//                            (commandBuffer, threadgroups, threadsPerThreadgroup, input, output) in
//
//                            if let sourceTexture      = input,
//                                let destinationTexture = output{
//                                
//                                IMPCoreImageMTLKernel.imageProcessor(kernel: kernel,
//                                                                     commandBuffer: commandBuffer,
//                                                                     threadgroups: threadgroups,
//                                                                     threadsPerThreadgroup: threadsPerThreadgroup,
//                                                                     input: sourceTexture,
//                                                                     output: destinationTexture)
//                            }
//            })
//        }
//        return nil
//    }
//    
    
    override func textureProcessor(_ commandBuffer: MTLCommandBuffer, _ threadgroups: MTLSize, _ threadsPerThreadgroup: MTLSize, _ input: MTLTexture?, _ output: MTLTexture?) {
        if let kernel = function{
            if let sourceTexture      = input,
                let destinationTexture = output{
                IMPCoreImageMTLKernel.imageProcessor(kernel: kernel,
                                                     commandBuffer: commandBuffer,
                                                     threadgroups: threadgroups,
                                                     threadsPerThreadgroup: threadsPerThreadgroup,
                                                     input: sourceTexture,
                                                     output: destinationTexture)
            }
        }
    }
    
    class func imageProcessor (
        kernel:IMPFunction,
        commandBuffer:MTLCommandBuffer,
        threadgroups:MTLSize,
        threadsPerThreadgroup:MTLSize,
        input:MTLTexture,
        output:MTLTexture
        )  {
        let commandEncoder =  kernel.commandEncoder(from: commandBuffer)
        
        commandEncoder.setTexture(input, at:0)
        commandEncoder.setTexture(output, at:1)
        
        if let handler = kernel.optionsHandler {
            handler(kernel, commandEncoder, input, output)
        }
        
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadsPerThreadgroup)
        commandEncoder.endEncoding()
    }
    
    @available(iOS 10.0, *)
    class ProcessorKernel: CIImageProcessorKernel {
        
        class func getMTLFunction(index:Int?) -> IMPFunction? {
            guard let i = index else {
                return nil
            }
            return registeredFunctionList[i]
        }
        
        override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
            
            guard
            let input              = inputs?.first,
            let sourceTexture      = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let commandBuffer      = output.metalCommandBuffer,
            let kernel             = ProcessorKernel.getMTLFunction(index: arguments?["functionIndex"] as? Int)
            else  {
                return
            }
            
            let width  = destinationTexture.size.width
            let height = destinationTexture.size.height
            
            let threadsPerThreadgroup = kernel.threadsPerThreadgroup
            let threadgroups = MTLSizeMake(
                (width) / threadsPerThreadgroup.width ,
                (height) / threadsPerThreadgroup.height,
                1);
            
            IMPCoreImageMTLKernel.imageProcessor(kernel: kernel,
                                                 commandBuffer: commandBuffer,
                                                 threadgroups: threadgroups,
                                                 threadsPerThreadgroup: threadsPerThreadgroup,
                                                 input: sourceTexture,
                                                 output: destinationTexture)
            
        }
    }
}

