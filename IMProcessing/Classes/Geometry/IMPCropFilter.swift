//
//  IMPCropFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 27.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// Crop filter
public class IMPCropFilter: IMPFilter {
    
    /// Cropping region 
    public var region = IMPRegion() {
        didSet{
            dirty = true
        }
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider? {
        
        if region.left == 0 && region.right == 0 && region.bottom == 0 && region.top == 0 {
            provider.texture = source.texture
            return provider
        }
        
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                let blit = commandBuffer.blitCommandEncoder()
                
                let w = texture.width
                let h = texture.height
                let d = texture.depth
                
                let oroginSource = MTLOrigin(x: (floor(self.region.left * w.float + 0.5)).int, y: (floor(self.region.top * h.float + 0.5)).int, z: 0)
                
                let destinationSize = MTLSize(
                    width: (floor(self.region.width * w.float + 0.5)).int,
                    height: (floor(self.region.height * h.float) + 0.5).int, depth: d)
                
                if destinationSize.width != provider.texture?.width || destinationSize.height != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        texture.pixelFormat,
                        width: destinationSize.width, height: destinationSize.height,
                        mipmapped: false)
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                                
                blit.copyFromTexture(
                    texture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: oroginSource,
                    sourceSize: destinationSize,
                    toTexture: provider.texture!,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: MTLOrigin(x:0,y:0,z:0))
                                
                blit.endEncoding()                
            }
        }
        return provider 
    }
}