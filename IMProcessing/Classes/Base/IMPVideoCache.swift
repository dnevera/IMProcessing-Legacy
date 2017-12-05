//
//  IMPVideoCache.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 04.03.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal
import AVFoundation
import CoreMedia

open class IMPVideoTextureCache {
    
    var reference:CVMetalTextureCache? {
        return videoTextureCache.pointee
    }
    
    init(context:IMPContext) {
        let textureCacheError = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, context.device, nil, videoTextureCache)
        if textureCacheError != kCVReturnSuccess {
            fatalError("IMPVideoTextureCache error: couldn't create a texture cache...");
        }
    }
    
    func flush(){
        if let cache =  videoTextureCache.pointee {
            CVMetalTextureCacheFlush(cache, 0);
        }
    }
    
    var videoTextureCache: UnsafeMutablePointer<CVMetalTextureCache?> = UnsafeMutablePointer.allocate(capacity: 1)
}


