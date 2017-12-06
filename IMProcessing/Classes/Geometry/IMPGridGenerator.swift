//
//  IMPGridGenerator.swift
//  ImageMetalling-12
//
//  Created by denis svinarchuk on 16.06.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation

open class IMPGridGenerator: IMPTransformFilter {
    
    public enum SpotAreaType: Int {
        case grid  = 0
        case solid = 1
    }
    
    public struct Adjustment{
        public var step              = uint(50)           // step point
        public var color             = float4(1)          // color
        public var subDivisionStep   = uint(4)            // sub division grid
        public var subDivisionColor  = float4(0,0,0,1)    // sub division color
        public var spotAreaColor     = float4(1,1,1,0.8)  // light spot area color
        public var spotArea          = IMPRegion.null     // light spot area
        public var spotAreaType      = SpotAreaType.grid  // light spot area type
    }
    
    open var adjustment = Adjustment() {
        didSet{
            memcpy(bufferStep.contents(), &adjustment.step, bufferStep.length)
            memcpy(bufferSDiv.contents(), &adjustment.subDivisionStep, bufferStep.length)
            memcpy(bufferColor.contents(), &adjustment.color, bufferColor.length)
            memcpy(bufferSDivColor.contents(), &adjustment.subDivisionColor, bufferSDivColor.length)
            memcpy(bufferSpotAreaColor.contents(), &adjustment.spotAreaColor, bufferSpotAreaColor.length)
            memcpy(bufferSpotArea.contents(), &adjustment.spotArea, bufferSpotArea.length)
            var t = adjustment.spotAreaType.rawValue
            memcpy(bufferSpotAreaType.contents(), &t, bufferSpotAreaType.length)
            dirty = true
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        addGraphics(graphics)
    }
    
    fileprivate lazy var graphics:IMPGraphics = IMPGraphics(context: self.context, fragment: "fragment_gridGenerator")
    
    override open func configureGraphics(_ graphics: IMPGraphics, command: MTLRenderCommandEncoder) {
        if graphics == self.graphics {
            command.setFragmentBuffers(buffers, offsets: bufferOffset, range: 0..<buffers.count)
        }
    }
    
    lazy var buffers:[MTLBuffer?] = {
        var array = [MTLBuffer?]()
        array.append(self.bufferStep)
        array.append(self.bufferSDiv)
        array.append(self.bufferColor)
        array.append(self.bufferSDivColor)
        array.append(self.bufferSpotAreaColor)
        array.append(self.bufferSpotArea)
        array.append(self.bufferSpotAreaType)
        return array
    }()
    
    lazy var bufferOffset:[Int] = [Int](repeating: 0, count: self.buffers.count)
    
    lazy var bufferStep:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.step,
                                                                           length: MemoryLayout<uint>.size,
                                                                           options: MTLResourceOptions())!
    
    lazy var bufferSDiv:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.subDivisionStep,
                                                                           length: MemoryLayout<uint>.size,
                                                                           options: MTLResourceOptions())!
    
    lazy var bufferColor:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.color,
                                                                            length: MemoryLayout<float4>.size,
                                                                            options: MTLResourceOptions())!
    
    lazy var bufferSDivColor:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.subDivisionColor,
                                                                                length: MemoryLayout<float4>.size,
                                                                                options: MTLResourceOptions())!
    
    lazy var bufferSpotAreaColor:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.spotAreaColor,
                                                                               length: MemoryLayout<float4>.size,
                                                                               options: MTLResourceOptions())!
    
    lazy var bufferSpotArea:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.spotArea,
                                                                               length: MemoryLayout<IMPRegion>.size,
                                                                               options: MTLResourceOptions())!
    
    lazy var bufferSpotAreaType:MTLBuffer = self.context.device.makeBuffer(bytes: &self.adjustment.spotAreaType,
                                                                           length: MemoryLayout<uint>.size,
                                                                           options: MTLResourceOptions())!
    
}
