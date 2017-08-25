//
//  IMPLut1DTexture.swift
//  Pods
//
//  Created by Denis Svinarchuk on 28/06/2017.
//
//

import IMProcessing
import Surge

public class IMPLut1DTexture: IMPTextureProvider, IMPContextProvider {
    
    public static let identity:[Float] =  {
        return Surge.linspace(Float(0), Float(1), num: kIMPCurveCollectionResolution)
    }()
    
    public lazy var texture:MTLTexture? = self.context.device.texture1DArray(buffers: self.channels)
    public var context:IMPContext
    
    public var channels = [identity,identity,identity] {
        didSet{
            update(channels: channels)
        }
    }
    
    public init(context: IMPContext, channels:[[Float]]? = nil) {
        self.context = context
        defer {
            if let cs = channels {
                self.channels = cs
            }
        }
    }
    
    public func update(channels:[[Float]]){
        if texture == nil {
            texture = context.device.texture1DArray(buffers: channels)
        }
        else {
            texture?.update1DArray(channels)
        }
    }
}
