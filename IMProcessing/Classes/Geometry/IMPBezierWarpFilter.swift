//
//  IMPBezierWarpFilter.swift
//  ImageMetalling-13
//
//  Created by denis svinarchuk on 20.06.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Foundation

open class IMPBezierWarpFilter: IMPTransformFilter {
    
    /// Контрольные точки сетки поверххности Bezier 4x4.
    /// Сдвиг точки относительно позиции (0,0) описывает сдвиг сетки
    open var points = IMPFloat2x4x4() {
        didSet{
            controlPoints = IMPBezierWarpFilter.baseControlPoints
            for i in 0..<4 {
                for j in 0..<4 {
                    controlPoints[i,j] += points[i,j]
                }
            }
            memcpy(buffer.contents(), &controlPoints, buffer.length)
            dirty = true
        }
    }
    
    /// Базовая сетка поверхности
    open static let baseControlPoints = IMPFloat2x4x4(vectors: (
        (float2(0,0),   float2(1/3,0),   float2(2/3,0),   float2(1, 0)),
        (float2(0,1/3), float2(1/3,1/3), float2(2/3,1/3), float2(1, 1/3)),
        (float2(0,2/3), float2(1/3,2/3), float2(2/3,2/3), float2(1, 2/3)),
        (float2(0,1),   float2(1/3,1),   float2(2/3,1),   float2(1, 1)))
    )
    
    /// Контрольные точки в координатах изображения
    var controlPoints:IMPFloat2x4x4 = IMPBezierWarpFilter.baseControlPoints
    
    override open var backgroundColor: IMPColor {
        didSet{
            var c = backgroundColor.rgba
            memcpy(bgColorBuffer.contents(), &c, bgColorBuffer.length)
            dirty = true
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        addGraphics(graphics)
    }
    
    fileprivate lazy var graphics:IMPGraphics = IMPGraphics(context: self.context, fragment: "fragment_bezierWarpTransformation")

    override open func configureGraphics(_ graphics: IMPGraphics, command: MTLRenderCommandEncoder) {
        if graphics == self.graphics {
            command.setFragmentBuffer(buffer, offset: 0, index: 0)
            command.setFragmentBuffer(bgColorBuffer, offset: 0, index: 1)
        }
    }

    lazy var bgColorBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<float4>.size,
                                                                         options: MTLResourceOptions())!

    lazy var buffer:MTLBuffer = self.context.device.makeBuffer(bytes: &self.controlPoints,
                                                                       length: MemoryLayout<IMPFloat2x4x4>.size,
                                                                       options: MTLResourceOptions())!
}


// MARK: - Итератор тензора
public extension IMPFloat2x4x4 {
    
    public subscript(i:Int,j:Int) -> float2 {
        get{
            var mem:[float2] = [float2](repeating: float2(0), count: 16)
            var v = vectors
            memcpy(&mem, &v, MemoryLayout.size(ofValue: vectors))
            return mem[(j%4)+4*(i%4)]
        }
        mutating set {
            var mem:[float2] = [float2](repeating: float2(0), count: 16)
            memcpy(&mem, &vectors, MemoryLayout.size(ofValue: vectors))
            mem[(j%4)+4*(i%4)] = newValue
            memcpy(&vectors, &mem, MemoryLayout.size(ofValue: vectors))
        }
    }
    
    public subscript(i:Int) -> float2 {
        get{
            var mem:[float2] = [float2](repeating: float2(0), count: 16)
            var v = vectors
            memcpy(&mem, &v, MemoryLayout.size(ofValue: vectors))
            return mem[i%16]
        }
        mutating set {
            var mem:[float2] = [float2](repeating: float2(0), count: 16)
            memcpy(&mem, &vectors, MemoryLayout.size(ofValue: vectors))
            mem[i%16] = newValue
            memcpy(&vectors, &mem, MemoryLayout.size(ofValue: vectors))
        }
    }
    
    public func lerp(final:IMPFloat2x4x4, t:Float) -> IMPFloat2x4x4 {
        var result = IMPFloat2x4x4()
        for i in 0..<4 {
            for j in 0..<4 {
                result[i,j] = self[i,j].lerp(final: final[i,j], t: t)
            }
        }
        return result
    }
}
