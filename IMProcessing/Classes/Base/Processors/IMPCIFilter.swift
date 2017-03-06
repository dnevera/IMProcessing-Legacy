//
//  IMProcessorKernel.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 12.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Metal
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

public class IMPCIFilter: CIFilter, IMPDestinationSizeProvider {
    
   public typealias CommandProcessor = ((
        _ commandBuffer:MTLCommandBuffer,
        _ threadgroups:MTLSize,
        _ threadsPerThreadgroup:MTLSize,
        _ source:IMPImageProvider,
        _ destinationTexture:IMPImageProvider)->Void)
    
    var context:IMPContext? = nil
    
    var source:IMPImageProvider?
    var destination:IMPImageProvider?
    
    public var destinationSize: NSSize? = nil

    var inputImage: CIImage? {
        set{
            if source == nil {
                if let context = context, let image = newValue {
                    source = IMPImage(context: context)
                    source?.image = image
                }
            }
            else {
                source?.image = newValue
            }
        }
        get{
            return source?.image
        }
    }
    
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
    
    lazy public var colorSpace:CGColorSpace = {
        if #available(iOS 10.0, *) {
            return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    lazy public var processor:CommandProcessor? = self.textureProcessor
    
    lazy public var threadsPerThreadgroup:MTLSize = MTLSize(width: 16,height: 16,depth: 1)
    
    var kernelIndex:Int? = 0
 
    public func textureProcessor(
    _ commandBuffer:MTLCommandBuffer,
    _ threadgroups:MTLSize,
    _ threadsPerThreadgroup:MTLSize,
    _ source:IMPImageProvider,
    _ destination:IMPImageProvider) -> Void {
        
    }
}

extension IMPCIFilter {
    
    override public var outputImage: CIImage? {
        
        if let size = source?.size,
            let index = kernelIndex {
            let msize = fmax(size.width, size.height)
            if msize > IMPContext.maximumTextureSize.cgfloat {
                return processBigImage(index: index)
            }
            else {
                return processImage()
            }
        }
        return nil
    }
    
    public func flush() {
        source?.image = nil
        source = nil
        destination?.image = nil
        destination = nil
    }
    
    func processBigImage(index:Int) -> CIImage? {
        guard let processor = self.processor else { return nil}
        return processCIImage(command: processor)
    }
    
    func processImage() -> CIImage? {
        guard let processor = self.processor else { return nil}
        return processCIImage(command: processor)
    }
    
    func processCIImage(command:@escaping CommandProcessor) -> CIImage? {
        return process(command: command)?.image
    }
    

    var mtlSize:MTLSize? {
        if let size = source?.size {
            return MTLSize(width: Int(size.width), height: Int(size.height), depth: 1)
        }
        return nil
    }
    
    func process(command:@escaping CommandProcessor) -> IMPImageProvider? {

        guard let context = self.context else { return nil }
        
        destination = destination ?? IMPImage(context: context)

        process(to: destination!, command: command)
        
        return destination
    }
    
    
    func process(to destinationImage: IMPImageProvider, commandBuffer buffer: MTLCommandBuffer? = nil, command: CommandProcessor? = nil){
       
        guard let size =  destinationSize ?? source?.size else { return }
        
        guard let context = self.context else { return  }
        
        var destinationImage = destinationImage
        
        if let texture = destinationImage.texture {
            destinationImage.texture = texture.reuse(size: size)
        }
        else{
            destinationImage.texture = context.device.make2DTexture(size: size,
                                                                    pixelFormat: (source?.texture?.pixelFormat)!)
        }
                
        let threadgroups = MTLSizeMake(
            (Int(size.width) + self.threadsPerThreadgroup.width) / self.threadsPerThreadgroup.width ,
            (Int(size.height) + self.threadsPerThreadgroup.height) / self.threadsPerThreadgroup.height,
            1);
        
        if let commandBuffer = buffer {
            if let command = command{
                command(commandBuffer, threadgroups, self.threadsPerThreadgroup, self.source!, destinationImage)
            }
            else {
                self.processor?(commandBuffer, threadgroups, self.threadsPerThreadgroup, self.source!, destinationImage)
            }
        }
        else {
            context.execute { (commandBuffer) in
                if let command = command{
                    command(commandBuffer, threadgroups, self.threadsPerThreadgroup, self.source!, destinationImage)
                }
                else {
                    self.processor?(commandBuffer, threadgroups, self.threadsPerThreadgroup, self.source!, destinationImage)
                }
            }
        }
    }
}
