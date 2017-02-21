//
//  IMProcessorKernel.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 12.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
import MetalPerformanceShaders
import CoreImage

//
// Render RAW to MTLTexture snippet
//
//CMSampleBufferRef rawSampleBuffer; // from your AVCapturePhotoCaptureDelegate callback
//NSDictionary* rawImageAttachments = (__bridge_transfer NSDictionary *)CMCopyDictionaryOfAttachments(kCFAllocatorDefault, rawSampleBuffer, kCMAttachmentMode_ShouldPropagate);
//CIContext* context = [CIContext contextWithMTLDevice:[...your device...]];
//id<MTLTexture> texture = [... initialize your textue... ]
//CIFilter* rawFilter = [CIFilter filterWithCVPixelBuffer:CMSampleBufferGetImageBuffer(rawSampleBuffer) properties:rawImageAttachments options:[... your options ...]];
//[context render:rawFilter.outputImage toMTLTexture:texture commandBuffer:[...] bounds:[...] colorSpace:[...]]


protocol IMPCoreImageRegister {
    static func register(name:String)
}

class IMPCIFilterConstructor: NSObject, CIFilterConstructor {
    func filter(withName name: String) -> CIFilter? {
        return IMPCIFilter()
    }
}

class IMPCIFilter: CIFilter {
    var inputImage: CIImage?     
    override var attributes: [String : Any]
    {
        return [
            kCIAttributeFilterDisplayName: "IMP Processing Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
    
        ]
    }
    
    var input:MTLTexture? = nil
    var output:MTLTexture? = nil
    
    lazy var colorSpace:CGColorSpace = {
        if #available(iOS 10.0, *) {
            return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    var kernelIndex:Int? = 0
}


extension IMPCIFilter {
    
    override var outputImage: CIImage? {
        
        if let image = inputImage, let index = kernelIndex
        {
            let msize = fmax(image.extent.size.width, image.extent.size.height)
            
            if msize > IMPContext.maximumTextureSize.cgfloat {
                return processBigImage(image: image, index: index)
            }
            else {
                return processImage(image: image)
            }
        }
        return nil
    }
    
    func processBigImage(image:CIImage, index:Int) -> CIImage? {
        return nil
    }
    
    func processImage(image:CIImage) -> CIImage? {
        return nil
    }
    
    typealias CommandProcessor = ((
        _ commandBuffer:MTLCommandBuffer,
        _ threadgroups:MTLSize,
        _ threadsPerThreadgroup:MTLSize,
        _ input:MTLTexture?,
        _ output: MTLTexture?)->Void)
    
    func process(image:CIImage,
                 in context:IMPContext?,
                 threadsPerThreadgroup:MTLSize,
                 command:@escaping CommandProcessor
        ) -> CIImage? {
        
        context?.execute{ (commandBuffer) in
            
            let size  = image.extent.size
            
            let width = Int(size.width)
            let height = Int(size.height)
            
            let threadgroups = MTLSizeMake(
                (width ) / threadsPerThreadgroup.width ,
                (height ) / threadsPerThreadgroup.height,
                1);
            
            if self.input == nil {
                self.input = context?.device.make2DTexture(size: size,
                                                           pixelFormat: IMProcessing.colors.pixelFormat)
            }
            else {
                self.input = self.input?.reuse(size: size)
            }
            if self.output == nil {
                self.output = context?.device.make2DTexture(size: size,
                                                            pixelFormat: IMProcessing.colors.pixelFormat)
            }
            else{
                self.output = self.output?.reuse(size: size)
            }
            
            context?.coreImage?.render(image, to: self.input!,
                                      commandBuffer: commandBuffer,
                                      bounds: image.extent,
                                      colorSpace: self.colorSpace)
            
            command(commandBuffer, threadgroups, threadsPerThreadgroup, self.input, self.output)
            
            self.input?.setPurgeableState(.volatile)
        }
        
        if let result = output {
            let result = CIImage(mtlTexture: result, options: [kCIImageColorSpace: colorSpace])
            self.output?.setPurgeableState(.volatile)
            return result
        }
        
        return nil
    }
}
