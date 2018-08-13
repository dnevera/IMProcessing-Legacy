//
//  IMPTpsFilter.swift
//  IMProcessing
//
//  Created by denn on 12.08.2018.
//  Copyright © 2018 Dehancer. All rights reserved.
//

import Foundation
import simd

private func convert<T>(count: Int, data: UnsafePointer<T>) -> [T] {
    let buffer = UnsafeBufferPointer(start: data, count: count);
    return Array(buffer)
}

public class IMPTpsPlaneTransform: IMPCLutTransform {
    
    public typealias Vector = float3
    public typealias Controls=IMPControlPoints<Vector>
    
    public var lambda:Float = 1 {
        didSet{
            dirty = true
        }
    }
    
    public var controls:Controls = Controls(p: [], q: []){
        didSet{
            
            var cp = controls.p
            var cq = controls.q
            let count = Int32(cp.count)
            let length = MemoryLayout<Vector>.size * cp.count

            let tps = IMPTpsSolverBridge(&cp, destination: &cq, count: count, lambda:lambda)
            
            let wcount = tps.weightsCount
            let wsize = wcount * MemoryLayout<Vector>.size
            let weights:[float3] = convert(count: wcount, data: tps.weights)
            
            if self.weightBuffer.length == length {
                memcpy(self.weightBuffer.contents(), weights, wsize)
                memcpy(self.qBuffer.contents(), self.controls.q, length)
            }
            else {
                
                self.weightBuffer = self.context.device.makeBuffer(
                    bytes: weights,
                    length: wsize,
                    options: [])!
                
                self.qBuffer = self.context.device.makeBuffer(
                    bytes: self.controls.q,
                    length: length,
                    options: [])!
            }
            
            dirty = true
        }
    }
    
    public var kernelName:String {
        return "kernel_tpsPlaneTransform"
    }
    
    override public func configure(complete: IMPFilter.CompleteHandler?) {
        
        super.extendName(suffix: "TPS Plane Transform")
        super.configure(complete: nil)
        
        let ci = NSImage(color:NSColor.darkGray, size:NSSize(width: 16, height: 16))
        source = IMPImage(context: context, image: ci)
        
        let kernel = IMPFunction(context: self.context, kernelName: kernelName)
        
        kernel.optionsHandler = {(shader, commandEncoder, input, output) in
            
            commandEncoder.setBytes(&self.reference,
                                    length: MemoryLayout.size(ofValue: self.reference),
                                    index: 0)
            
            var index = self.space.index
            commandEncoder.setBytes(&index,
                                    length: MemoryLayout.size(ofValue: index),
                                    index: 1)
            
            var pIndices = uint2(UInt32(self.spaceChannels.0),UInt32(self.spaceChannels.1))
            commandEncoder.setBytes(&pIndices,
                                    length: MemoryLayout.size(ofValue: pIndices),
                                    index: 2)
            
            commandEncoder.setBuffer(self.weightBuffer,
                                     offset: 0,
                                     index: 3)
            
            commandEncoder.setBuffer(self.qBuffer,
                                     offset: 0,
                                     index: 4)
            
            var count = self.controls.p.count
            commandEncoder.setBytes(&count,
                                    length: MemoryLayout.stride(ofValue: count),
                                    index: 5)
            
        }
        
        add(function: kernel) { (image) in
            complete?(image)
        }
    }
    
    private lazy var weightBuffer:MTLBuffer = self
        .context
        .device
        .makeBuffer(length: 4*MemoryLayout<Vector>.size, options:[])!
    
    private lazy var qBuffer:MTLBuffer = self
        .context
        .device
        .makeBuffer(length: 4*MemoryLayout<Vector>.size, options:[])!
}


public class IMPTpsLutTransform: IMPTpsPlaneTransform {
    
    public override var kernelName:String {
        return "kernel_tpsLutTransform"
    }
    
    public var cLut:IMPCLut!
    
    override public func configure(complete: IMPFilter.CompleteHandler?) {
        
        super.extendName(suffix: "TPS Lut Transform")
        super.configure(complete: nil)
        source = identityLut
        cLut =  try! IMPCLut(context: context, lutType: .lut_2d, lutSize: 64, format: .float)
        
        addObserver(destinationUpdated: { image in
            do {
                try self.cLut.update(from: image)
            }
            catch let error {
                Swift.print("IMPTpsLutTransform error: \(error)")
            }
        })
    }
    
    private lazy var identityLut:IMPCLut =
        try! IMPCLut(context: context, lutType: .lut_2d, lutSize: 64, format: .float)
}
