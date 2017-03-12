//
//  IMPLinesGenerator.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 12.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal


class IMPDrawLinesCoreMTLShader: IMPCoreImageMTLShader {
    override public func textureProcessor(_ commandBuffer: MTLCommandBuffer,
                                          _ threadgroups: MTLSize,
                                          _ threadsPerThreadgroup: MTLSize,
                                          _ source: IMPImageProvider,
                                          _ destination: IMPImageProvider) {
        
        if let sourceTexture = source.texture,
            let shader   = self.shader as? IMPDrawPointsShader,
            let destinationTexture = destination.texture
        {
            let points = shader.points
            
            let renderEncoder = shader.commandEncoder(from: commandBuffer, width: destinationTexture)
            
            renderEncoder.setVertexBuffer(shader.pointsBuffer, offset: 0, at: 0)
            renderEncoder.setFragmentTexture(sourceTexture, at:0)
            
            if let handler = shader.optionsHandler {
                handler(shader, renderEncoder, sourceTexture, destinationTexture)
            }
            
            renderEncoder.drawPrimitives(type: .line,
                                         vertexStart: 0,
                                         vertexCount: points.count,
                                         instanceCount: 1)
            renderEncoder.endEncoding()
        }
    }
}


public class IMPLinesGenerator: IMPFilter {
    
    public static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            adjustmentBuffer = adjustmentBuffer ?? context.device.makeBuffer(length: MemoryLayout.size(ofValue: adjustment), options: [])
            memcpy(adjustmentBuffer.contents(), &adjustment, adjustmentBuffer.length)
        }
    }
    
    public override var source: IMPImageProvider? {
        didSet{
            updateLines()
        }
    }
    
    var adjustmentBuffer:MTLBuffer!
    
    public var lines:[IMPLineSegment] {
        set{
            _lines = newValue
            updateLines()
            dirty = true
        }
        get{
            return _lines
        }
    }
    private var _lines = [IMPLineSegment]()
    
    func updateLines()  {
        pointsShader.points = [float2]()
        for p in _lines {
            pointsShader.points.append(p.p0)
            pointsShader.points.append(p.p1)
        }
    }
    
    static var defaultWidth:Float = 40
    static var defaultColor:float4 = float4(1,1,0.3,1)
    
    public var width:Float = IMPCrosshairsGenerator.defaultWidth {
        didSet{
            memcpy(widthBuffer.contents(), &width, widthBuffer.length)
            dirty = true
        }
    }
    
    public var color:float4 = IMPCrosshairsGenerator.defaultColor {
        didSet{
            memcpy(colorBuffer.contents(), &color, colorBuffer.length)
            dirty = true
        }
    }
    
    public override func configure() {
        extendName(suffix: "CrosshairGenerator")
        shader.processor = shader.textureProcessor
        add(filter: shader)
        add(shader: blendShader)
        width = IMPCrosshairsGenerator.defaultWidth
        color = IMPCrosshairsGenerator.defaultColor
        adjustment = IMPCrosshairsGenerator.defaultAdjustment
    }
    
    private lazy var pointsShader:IMPDrawPointsShader =  {
        let s = IMPDrawPointsShader(context: self.context,
                                    vertexName: "vertex_crosshair",
                                    fragmentName: "fragment_line")
        s.optionsHandler = { (shader, commandEncoder, input, output) in
            commandEncoder.setVertexBuffer(self.widthBuffer, offset: 0, at: 1)
            commandEncoder.setFragmentBuffer(self.colorBuffer, offset: 0, at: 0)
        }
        return s
    }()
    
    lazy var blendShader:IMPShader   = {
        let s = IMPShader(context: self.context,
                          fragmentName: "fragment_blendTextureSource")
        s.optionsHandler = { (shader,commandEncoder, input, output) in
            commandEncoder.setFragmentBuffer(self.adjustmentBuffer, offset: 0, at: 0)
            commandEncoder.setFragmentTexture((self.source?.texture)!, at:1)
        }
        return s
    }()
    
    private lazy var shader:IMPCIFilter = {
        return IMPDrawLinesCoreMTLShader.register(shader: self.pointsShader, filter: IMPDrawLinesCoreMTLShader())
    }()
    
    private lazy var widthBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.width), options: [])
    private lazy var colorBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout.size(ofValue: self.color), options: [])
    
}
