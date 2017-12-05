//
//  IMPTexturePovider.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public protocol IMPTextureProvider{
    var texture:MTLTexture?{ get set }
}

public extension IMPTextureProvider {
    public var size:MTLSize? {return texture?.size }
    public var cgsize:CGSize? {return texture?.cgsize}
    public var width:Int? { return texture?.width }
    public var height:Int? { return texture?.height }
    public var depth:Int? { return texture?.depth }
}

public extension IMPTextureProvider {
    public var label:String? {
        set { texture?.label = newValue }
        get { return texture?.label}
    }
}

public extension MTLDevice {
    
    public func texture1D(_ buffer:[Float]) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .type1D
        weightsDescription.pixelFormat = .r32Float
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.makeTexture(descriptor: weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture1D(_ buffer:[UInt8]) -> MTLTexture {
        let weightsDescription = MTLTextureDescriptor()
        
        weightsDescription.textureType = .type1D
        weightsDescription.pixelFormat = .r8Uint
        weightsDescription.width       = buffer.count
        weightsDescription.height      = 1
        weightsDescription.depth       = 1
        
        let texture = self.makeTexture(descriptor: weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture2D(_ buffer:[[UInt8]]) -> MTLTexture {
        let width = buffer[0].count
        let weightsDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: buffer.count, mipmapped: false)
        let texture = self.makeTexture(descriptor: weightsDescription)
        texture.update(buffer)
        return texture
    }

    public func texture1DArray(_ buffers:[[UInt8]]) -> MTLTexture {
        
        let width = buffers[0].count
        
        for i in 1 ..< buffers.count {
            if (width != buffers[i].count) {
                fatalError("texture buffers must have identical size...")
            }
        }

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type1DArray
        textureDescriptor.width       = width
        textureDescriptor.height      = 1
        textureDescriptor.depth       = 1
        textureDescriptor.pixelFormat = .r8Unorm
        
        textureDescriptor.arrayLength = buffers.count
        textureDescriptor.mipmapLevelCount = 1
        
        let texture = self.makeTexture(descriptor: textureDescriptor)
                
        texture.update1DArray(buffers)
        
        return texture
    }
    
    public func texture1DArray(_ buffers:[[Float]]) -> MTLTexture {
        
        let width = buffers[0].count
        
        for i in 1 ..< buffers.count {
            if (width != buffers[i].count) {
                fatalError("texture buffers must have identical size...")
            }
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type1DArray
        textureDescriptor.width       = width
        textureDescriptor.height      = 1
        textureDescriptor.depth       = 1
        textureDescriptor.pixelFormat = .r32Float
        
        textureDescriptor.arrayLength = buffers.count
        textureDescriptor.mipmapLevelCount = 1
        
        let texture = self.makeTexture(descriptor: textureDescriptor)
        
        texture.update(buffers)
        
        return texture
    }

}

public extension MTLTexture {
    
    public func update(_ buffer:[Float]){
        if pixelFormat != .r32Float {
            fatalError("MTLTexture.update(buffer:[Float]) has wrong pixel format...")
        }
        if width != buffer.count {
            fatalError("MTLTexture.update(buffer:[Float]) is not equal texture size...")
        }
        self.replace(region: MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: MemoryLayout<Float32>.size*buffer.count)
    }

    public func update(_ buffer:[UInt8]){
        if pixelFormat != .r8Uint {
            fatalError("MTLTexture.update(buffer:[UInt8]) has wrong pixel format...")
        }
        if width != buffer.count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        self.replace(region: MTLRegionMake1D(0, buffer.count), mipmapLevel: 0, withBytes: buffer, bytesPerRow: MemoryLayout<UInt8>.size*buffer.count)
    }

    public func update(_ buffer:[[UInt8]]){
        if pixelFormat != .r8Unorm {
            fatalError("MTLTexture.update(buffer:[UInt8]) has wrong pixel format...")
        }
        if width != buffer[0].count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        if height != buffer.count {
            fatalError("MTLTexture.update(buffer:[UInt8]) is not equal texture size...")
        }
        for i in 0 ..< height {
            self.replace(region: MTLRegionMake2D(0, i, width, 1), mipmapLevel: 0, withBytes: buffer[i], bytesPerRow: width)
        }
    }
    
    public func update1DArray(_ buffers:[[UInt8]]){
        if pixelFormat != .r8Unorm {
            fatalError("MTLTexture.update(buffer:[[UInt8]]) has wrong pixel format...")
        }
        
        let region = MTLRegionMake2D(0, 0, width, 1)
        let bytesPerRow = region.size.width * MemoryLayout<UInt8>.size
        
        for index in 0 ..< buffers.count {
            let curve = buffers[index]
            if width != curve.count {
                fatalError("MTLTexture.update(buffer:[[UInt8]]) is not equal texture size...")
            }
            self.replace(region: region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
        }
    }

    public func update1DArray(_ buffers:[[Float]]){
        update(buffers)
    }
    
    public func update(_ buffers:[[Float]]){
        if pixelFormat != .r32Float {
            fatalError("MTLTexture.update(buffer:[[Float]]) has wrong pixel format...")
        }
        
        let region = MTLRegionMake2D(0, 0, width, 1)
        let bytesPerRow = region.size.width * MemoryLayout<Float32>.size
        
        for index in 0 ..< buffers.count {
            let curve = buffers[index]
            if width != curve.count {
                fatalError("MTLTexture.update(buffer:[[Float]]) is not equal texture size...")
            }
            self.replace(region: region, mipmapLevel:0, slice:index, withBytes:curve, bytesPerRow:bytesPerRow, bytesPerImage:0)
        }
    }
}
