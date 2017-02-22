//
//  IMPTextureDelayLine.swift
//  Pods
//
//  Created by Denis Svinarchuk on 21/02/2017.
//
//

import Metal

public class IMPTextureDelayLine{
    
    public func request() -> MTLTexture? {
        let t = texture
        texture = nil
        return t
    }
    
    public func pushBack(texture:MTLTexture) -> MTLTexture? {
        let t = texture
        self.texture = texture
        return t
    }
    
    public func pushFront(texture:MTLTexture) -> MTLTexture? {
        if self.texture == nil {
            self.texture = texture
            return nil
        }
        return texture
    }

    var texture:MTLTexture? = nil    
}

