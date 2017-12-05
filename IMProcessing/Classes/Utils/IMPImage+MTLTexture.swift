//
//  IMPImage+Metal.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
    import ImageIO
#else
    import Cocoa
#endif

import Metal
import Accelerate

public extension IMPImage{
    
    #if os(iOS)
    
    public convenience init(image: IMPImage, size:IMPSize){
        let scale = min(size.width/image.size.width, size.height/image.size.height)
        self.init(cgImage: image.cgImage!, scale:1.0/scale, orientation:image.imageOrientation)
    }
    
    public convenience init(CGImage image: CGImage, size:IMPSize){
        let width  = image.width
        let height = image.height
        let scale = min(size.width.float/width.float, size.height.float/height.float)
        self.init(cgImage: image, scale:1.0/scale.cgfloat, orientation:.up)
    }

    #else
    
    public convenience init(image: IMPImage, size:IMPSize){
        self.init(CGImage: image.CGImage!, size:size)
    }
    
    #endif
    
    func newTexture(_ context:IMPContext, maxSize:Float = 0) -> MTLTexture? {
        
        let imageRef  = self.cgImage
        let imageSize = self.size
        
        var imageAdjustedSize = IMPContext.sizeAdjustTo(size: imageSize)
        
        //
        // downscale acording to GPU hardware limit size
        //
        var width  = Float(floor(imageAdjustedSize.width))
        var height = Float(floor(imageAdjustedSize.height))
        
        var scale = Float(1.0)
        
        if (maxSize > 0 && (maxSize < width || maxSize < height)) {
            scale = fmin(maxSize/width,maxSize/height)
            width  *= scale
            height *= scale
            imageAdjustedSize = CGSize(width: width, height: height)
        }
        
        let image = IMPImage(image: self, size:imageAdjustedSize)
        
        width  = Float(floor(image.size.width))
        height = Float(floor(image.size.height))
        
        let resultWidth  = Int(width)
        let resultHeight = Int(height)
        
        var rawData = [UInt8](repeating: 0, count: resultHeight * resultWidth * 4)
        let componentsPerPixel = 4
        let componentsPerRow   = componentsPerPixel * resultWidth
        let bitsPerComponent   = 8
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        
        let bitmapContext = CGContext(data: &rawData, width: resultWidth, height: resultHeight,
            bitsPerComponent: bitsPerComponent, bytesPerRow: componentsPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        bitmapContext?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: CGFloat(resultWidth), height: CGFloat(resultHeight)))
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: IMProcessing.colors.pixelFormat,
            width:resultWidth,
            height:resultHeight,
            mipmapped:false)
        
        let texture = context.device?.makeTexture(descriptor: textureDescriptor)
        
        if let t = texture {
            let region = MTLRegionMake2D(0, 0, resultWidth, resultHeight)
            
            if IMProcessing.colors.pixelFormat == .rgba16Unorm {
                var u16:[UInt16] = [UInt16](repeating: 0, count: componentsPerRow*resultHeight)
                for i in 0 ..< componentsPerRow*resultHeight {
                    var pixel = UInt16()
                    let address = UnsafePointer<UInt8>(rawData)+i
                    memcpy(&pixel, address, MemoryLayout<UInt8>.size)
                    u16[i] = pixel<<8
                }
                t.replace(region: region, mipmapLevel:0, withBytes:u16, bytesPerRow:componentsPerRow*MemoryLayout<UInt16>.size/MemoryLayout<UInt8>.size)
            }
            else {
                t.replace(region: region, mipmapLevel:0, withBytes:rawData, bytesPerRow:componentsPerRow)
            }
        }
        return texture
    }
}

public extension IMPImage{
    
    public convenience init? (provider: IMPImageProvider){
        #if os(OSX)
            var imageRef:CGImageRef?
            var width  = 0
            var height = 0
            
            if let texture = provider.texture {
                
                width  = texture.width
                height = texture.height
                
                let components       = 4
                let bitsPerComponent = 8
                
                var bytesPerRow      = width * components
                if texture.pixelFormat == .RGBA16Unorm {
                    bytesPerRow *= 2
                }
                
                let imageByteCount  = bytesPerRow * height
                
                let imageBuffer = provider.context.device.newBufferWithLength( imageByteCount, options: MTLResourceOptions.CPUCacheModeDefaultCache)
                
                //
                // Use blit encoder to copy data from device memory, then convert to 8bits presentation if it needs
                //
                provider.context.execute(closure: { (commandBuffer) in
                    
                    let blitEncoder = commandBuffer.blitCommandEncoder()
                    
                    blitEncoder.copyFromTexture(texture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: width, height: height, depth: 1),
                        toBuffer: imageBuffer,
                        destinationOffset: 0,
                        destinationBytesPerRow: bytesPerRow,
                        destinationBytesPerImage: 0)
                    
                    blitEncoder.endEncoding()
                    
                })
                
                var rawData   = [UInt8](count: width*height*components, repeatedValue: 0)
                if texture.pixelFormat == .RGBA16Unorm {
                    for i in 0 ..< rawData.count {
                        var pixel = UInt16()
                        let address =  UnsafePointer<UInt16>(imageBuffer.contents())+i
                        memcpy(&pixel, address, sizeof(UInt16))
                        rawData[i] = UInt8(pixel>>8)
                    }
                }
                else{
                    memcpy(&rawData, imageBuffer.contents(), imageBuffer.length)
                }
                
                let cgprovider = CGDataProviderCreateWithData(nil, &rawData, imageByteCount, nil)
                
                if texture.pixelFormat == .RGBA16Unorm {
                    bytesPerRow /= 2
                }
                
                let bitsPerPixel     = bitsPerComponent * 4
                
                let colorSpaceRef  = CGColorSpaceCreateDeviceRGB();
                
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrder32Big.rawValue)
                
                if let imageRef = CGImageCreate(
                    width,
                    height,
                    bitsPerComponent,
                    bitsPerPixel,
                    bytesPerRow,
                    colorSpaceRef,
                    bitmapInfo,
                    cgprovider,
                    nil,
                    false,
                    .RenderingIntentDefault){
                
                    self.init(CGImage: imageRef, size: IMPSize(width: width, height: height))
                }
                else{
                    return nil
                }

            }
            else{
                return nil
            }
            
        #else
            if let texture = provider.texture {
                
                let bytesPerPixel  = 4
                let imageByteCount = texture.width * texture.height * bytesPerPixel
                let bytesPerRow    = texture.width * bytesPerPixel
                
                var rawData = [UInt8](repeating: 0, count: Int(imageByteCount))
                
                texture.getBytes(&rawData,
                                 bytesPerRow: bytesPerRow,
                                 from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                                 mipmapLevel: 0)
                
                let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
                
                let colorSpaceRef = CGColorSpaceCreateDeviceRGB()
                
                let context = CGContext(data: &rawData, width: texture.width, height: texture.height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpaceRef, bitmapInfo: bitmapInfo.rawValue);
                
                if let image = context?.makeImage(){
                    self.init(cgImage: image, scale: 0.0, orientation: .up)
                }
                else{
                    return nil
                }
            }
            else{
                return nil
            }
        #endif
    }
    
    #if os(OSX)
    
    public func writeJpegToFile(path:String, compression compressionQ:Float) {
        
        let dr:CGImageDestination! = CGImageDestinationCreateWithURL(
            NSURL(fileURLWithPath: path), "public.jpeg" as CFStringRef , 1, nil)
        
        CGImageDestinationAddImage(dr, self.CGImage!,
            [kCGImageDestinationLossyCompressionQuality as String: 0.9])
        
        CGImageDestinationFinalize(dr);
    }
    
    #endif
    
}
