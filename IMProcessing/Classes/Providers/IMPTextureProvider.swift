//
//  IMPTextureProvider.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import Metal

public extension MTLTexture{
    public var cgsize:NSSize{
        get{
            return NSSize(width: width, height: height)
        }
    }
    public var size:MTLSize {
        return MTLSize(width: width, height: height, depth: depth)
    }
}

public extension Array where Element : Equatable {
    public mutating func removeObject(object : Element) {
        if let index = self.index(of: object) {
            self.remove(at: index)
        }
    }
}

public protocol IMPTextureProvider{
    var texture:MTLTexture?{ get set }
}

public extension IMPTextureProvider {
    public var size:MTLSize?   { return texture?.size }
    public var cgsize:NSSize? { return  texture?.cgsize}
    public var width:Int?      { return texture?.width }
    public var height:Int?     { return texture?.height }
    public var depth:Int?      { return texture?.depth }
}

public extension IMPTextureProvider {
    public var label:String? {
        set { texture?.label = newValue }
        get { return texture?.label}
    }
}

public extension MTLDevice {
    
    public func texture1D(buffer:[Float]) -> MTLTexture {
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
    
    public func texture1D(buffer:[UInt8]) -> MTLTexture {
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
    
    public func texture2D(buffer:[[UInt8]]) -> MTLTexture {
        let width = buffer[0].count
        let weightsDescription = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: buffer.count, mipmapped: false)
        let texture = self.makeTexture(descriptor: weightsDescription)
        texture.update(buffer)
        return texture
    }
    
    public func texture1DArray(buffers:[[UInt8]]) -> MTLTexture {
        
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
    
    public func texture1DArray(buffers:[[Float]]) -> MTLTexture {
        
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
    
    public func make2DTexture(width:Int, height:Int, pixelFormat:MTLPixelFormat = .r8Unorm) -> MTLTexture {
        return makeTexture(descriptor:
            MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                     width: width,
                                                     height: height,
                                                     mipmapped: false))
    }
    
    public func make2DTexture(size: NSSize, pixelFormat:MTLPixelFormat = .r8Unorm) -> MTLTexture {
        return makeTexture(descriptor:
            MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                     width: Int(size.width),
                                                     height: Int(size.height),
                                                     mipmapped: false))
    }
}

public func == (left:MTLSize, right:MTLSize) -> Bool{
    return left.width==right.width && left.height==right.height && left.depth==left.depth
}

public func != (left:MTLSize, right:MTLSize) -> Bool{
    return !(left==right)
}

public extension MTLTexture {
 
    public func validateSize(of texture:MTLTexture) -> Bool {
        return texture.size == self.size
    }

    public static func reuseFor(_ device:MTLDevice, texture:MTLTexture?, width:Int, height:Int, depth:Int = 1,
                             pixelFormat: MTLPixelFormat = .r8Unorm) -> MTLTexture? {
        
        guard let texture = texture else {
            return device.make2DTexture(width: width, height: height, pixelFormat: pixelFormat)
        }
        if MTLSize(width: width, height: height,depth: depth) == texture.size {
            return texture
        }
        return device.make2DTexture(width: width, height: height, pixelFormat: pixelFormat)
    }

    public static func reuseFor(_ device:MTLDevice, texture:MTLTexture?, size:NSSize, depth:Int = 1,
                             pixelFormat: MTLPixelFormat = .r8Unorm) -> MTLTexture? {
        return reuseFor(device,
                     texture: texture,
                     width: Int(size.width), height: Int(size.height),
                     depth: depth, pixelFormat: pixelFormat)
    }
    
    public func reuse(width:Int, height:Int, depth:Int = 1) -> MTLTexture {
        if MTLSize(width: width, height: height,depth: depth) == self.size {
            return self
        }
        return device.make2DTexture(width: width, height: height, pixelFormat: pixelFormat)
    }
    
    public func reuse(size:NSSize, depth:Int = 1) -> MTLTexture {
        return reuse(width: Int(size.width), height: Int(size.height), depth: depth)
    }

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
