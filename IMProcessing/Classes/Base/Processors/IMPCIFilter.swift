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

public class IMPCIFilter: CIFilter {
    
    typealias CommandProcessor = ((
        _ commandBuffer:MTLCommandBuffer,
        _ threadgroups:MTLSize,
        _ threadsPerThreadgroup:MTLSize,
        _ input:MTLTexture?,
        _ output: MTLTexture?)->Void)
    

    var context:IMPContext? = nil
    
    public var input:MTLTexture? = nil {
        didSet{
            oldValue?.setPurgeableState(.empty)
        }
    }
    
    open var output:MTLTexture? {
        if let processor = processor {
            return process(command: processor)
        }
        return nil
    }
    
    fileprivate var _output:MTLTexture? = nil
    
    lazy var processor:CommandProcessor? = self.textureProcessor

    lazy var threadsPerThreadgroup:MTLSize = MTLSize(width: 16,height: 16,depth: 1)
    
    var inputImage: CIImage? {
        didSet{
            needUpdateInputTexture = true
        }
    }
    var needUpdateInputTexture = true
    
    override public var attributes: [String : Any]
    {
        return [
            kCIAttributeFilterDisplayName: "IMP Processing Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
    
        ]
    }
    
    lazy var colorSpace:CGColorSpace = {
        if #available(iOS 10.0, *) {
            return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    var kernelIndex:Int? = 0
 
    func textureProcessor(
    _ commandBuffer:MTLCommandBuffer,
    _ threadgroups:MTLSize,
    _ threadsPerThreadgroup:MTLSize,
    _ input: MTLTexture?,
    _ output: MTLTexture?) -> Void {
        
    }
    
}


extension IMPCIFilter {
    
    override public var outputImage: CIImage? {
        
        if let image = inputImage, let index = kernelIndex {
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
        guard let processor = self.processor else { return nil}
        return process(image: image, command: processor)
    }
    
    func processImage(image:CIImage) -> CIImage? {
        guard let processor = self.processor else { return nil}
        return process(image: image, command: processor)
    }
    
    func process(image:CIImage, command:@escaping CommandProcessor) -> CIImage? {
                
        if let result = process(command: command) {
            let result = CIImage(mtlTexture: result, options: [kCIImageColorSpace: colorSpace])
            self.input?.setPurgeableState(.volatile)
            return result
        }

        return nil
    }
    
    func process(command:@escaping CommandProcessor
        ) -> MTLTexture? {

        var size:NSSize
        var width:Int
        var height:Int
        //var image:CIImage? = self.inputImage
        let context = self.context

        if let image = self.inputImage {
            
            size  = image.extent.size
            width = Int(size.width)
            height = Int(size.height)
            
            if self.input == nil {
                self.input = context?.device.make2DTexture(size: size,
                                                           pixelFormat: IMProcessing.colors.pixelFormat)
            }
            else {
                self.input = self.input?.reuse(size: size)
            }
        }
        else if let inputTexture = self.input {
            size  = inputTexture.cgsize
            width = Int(size.width)
            height = Int(size.height)
            needUpdateInputTexture = false
        }
        else {
            return nil
        }
        
        
        context?.execute { (commandBuffer) in
            
            let threadgroups = MTLSizeMake(
                (width ) / self.threadsPerThreadgroup.width ,
                (height ) / self.threadsPerThreadgroup.height,
                1);
            
            if self._output == nil {
                self._output = context?.device.make2DTexture(size: size,
                                                            pixelFormat: IMProcessing.colors.pixelFormat)
            }
            else{
                self._output = self._output?.reuse(size: size)
            }
            
            if self.needUpdateInputTexture {
                if let image = self.inputImage {
                    context?.coreImage?.render(image, to: self.input!,
                                               commandBuffer: commandBuffer,
                                               bounds: image.extent,
                                               colorSpace: self.colorSpace)
                    self.needUpdateInputTexture = false
                }
            }
            
            command(commandBuffer, threadgroups, self.threadsPerThreadgroup, self.input, self._output)
            
            self.input?.setPurgeableState(.volatile)
        }
        
        return self._output
    }
}
