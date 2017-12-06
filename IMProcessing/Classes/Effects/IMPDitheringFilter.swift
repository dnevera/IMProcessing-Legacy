//
//  IMPRandomDither.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 27.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

open class IMPDitheringFilter:IMPFilter,IMPAdjustmentProtocol{
    
    open var ditheringLut:[[UInt8]] {
        get {
            fatalError("IMPDitheringFilter: ditheringLut must be implemented...")
        }
    }
    
    open static let defaultAdjustment = IMPAdjustment(
        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    open var adjustment:IMPAdjustment!{
        didSet{
            updateDitheringLut(&ditherLut)
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:MemoryLayout.size(ofValue: adjustment))
            self.dirty = true
        }
    }
    
    open var adjustmentBuffer:MTLBuffer?
    open var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_dithering")
        self.addFunction(kernel)
        timerBuffer = context.device.makeBuffer(length: MemoryLayout<Float>.size, options: MTLResourceOptions())
        defer{
            self.adjustment = IMPDitheringFilter.defaultAdjustment
        }
    }
    
    var timerBuffer:MTLBuffer!
    
    open override func configure(_ function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(ditherLut, index: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, index: 0)
        }
    }
    
    
    var ditherLut:MTLTexture?
    func updateDitheringLut(_ lut:inout MTLTexture?){
        
        if ditheringLut.count > 256 {
            fatalError("IMPDitheringFilter.ditheringLut length must be less then 256...")
        }
        
        if let dl = lut {
            dl.update(ditheringLut)
        }
        else {
            lut = context.device.texture2D(ditheringLut)
        }
    }
}

open class IMPBayerDitheringFilter:IMPDitheringFilter{
    override open var ditheringLut:[[UInt8]] {
        get {
            //
            // https://en.wikipedia.org/wiki/Ordered_dithering
            // http://www.efg2.com/Lab/Library/ImageProcessing/DHALF.TXT
            //
            return [
                [0,  32,  8, 40,  2, 34, 10, 42],  /* 8x8 Bayer ordered dithering  */
                [48, 16, 56, 24, 50, 18, 58, 26],  /* pattern.  Each input pixel   */
                [12, 44,  4, 36, 14, 46,  6, 38],  /* is scaled to the 0..63 range */
                [60, 28, 52, 20, 62, 30, 54, 22],  /* before looking in this table */
                [3,  35, 11, 43,  1, 33,  9, 41],  /* to determine the action.     */
                [51, 19, 59, 27, 49, 17, 57, 25],
                [15, 47,  7, 39, 13, 45,  5, 37],
                [63, 31, 55, 23, 61, 29, 53, 21]
            ]
        }
    }
}

open class IMPRandomDitheringFilter:IMPDitheringFilter{
    override open var ditheringLut:[[UInt8]] {
        get {
            var data = [[UInt8]](repeating: [UInt8](repeating: 0, count: 8), count: 8)
            for i in 0 ..< data.count {
                SecRandomCopyBytes(kSecRandomDefault, data[i].count, UnsafeMutablePointer<UInt8>(mutating: data[i]))
                for j in 0 ..< data[i].count {
                    data[i][j] = data[i][j]/4
                }
            }
            return data
        }
    }
}
