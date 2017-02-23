//
//  IMPTextureCache.swift
//  Pods
//
//  Created by Denis Svinarchuk on 21/02/2017.
//
//

import Foundation
import Metal

typealias IMPTextureQueue = IMPDequeue<MTLTexture>

public class IMPTextureCache: IMPContextProvider {
    var cache = [Int64:IMPTextureQueue]()
    
    public var context:IMPContext
    
    public init(context:IMPContext) {
        self.context = context
    }
    
    public func requestTexture(size: NSSize, pixelFormat:MTLPixelFormat = IMProcessing.colors.pixelFormat) -> MTLTexture? {
        let hash = hashFor(size: size, pixelFormat: pixelFormat)
        if let t = cache[hash]?.dequeue() {
            print("requested[\(hash)] cached texture = \(t.size) count = \(cache[hash]?.count) ")
            return t
        }
        else {
            let t = context.device.make2DTexture(size: size, pixelFormat: pixelFormat)
            var q = IMPTextureQueue()
            q.enqueue(t)
            cache[hash] = q
            print("requested[\(hash)] new texture = \(t.size) count = \(cache[hash]?.count) ")
            return cache[hash]?.dequeue()
        }
    }
    
    public func returnTexure(_ texture:MTLTexture){
        context.sync {
            let hash = hashFor(texture: texture)
            if cache[hash] == nil {
                cache[hash] =  IMPTextureQueue()
            }
            print("returned[\(hash)] texture = \(texture.size)")
            cache[hash]?.enqueue(texture)
        }
    }
    
    func hashFor(size: NSSize, pixelFormat:MTLPixelFormat) -> Int64 {
        var result:Int64 = 1
        let prime:Int64 = 31
        result = prime * result + Int64(size.width)
        result = prime * result + Int64(size.height)
        result = prime * result + Int64(pixelFormat.rawValue)
        return result
        
    }
    
    func hashFor(texture: MTLTexture) -> Int64 {
        return hashFor(size: texture.cgsize, pixelFormat: texture.pixelFormat)
    }
    
}

