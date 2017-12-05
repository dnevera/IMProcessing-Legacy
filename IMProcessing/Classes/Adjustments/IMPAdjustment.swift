//
//  IMPAdjustment.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Foundation
import Metal

public protocol IMPAdjustmentProtocol{
    
    var adjustmentBuffer:MTLBuffer? {get set}
    var kernel:IMPFunction! {get set}
    
}

public extension IMPAdjustmentProtocol{
    public func updateBuffer(_ buffer:inout MTLBuffer?, context:IMPContext, adjustment:UnsafeRawPointer, size:Int){
        buffer = buffer ?? context.device.makeBuffer(length: size, options: MTLResourceOptions())
        if let b = buffer {
            memcpy(b.contents(), adjustment, b.length)
        }
    }
}
