//
//  IMProcessingView.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 03.12.2017.
//

//
//  IMPMetalView.swift
//  Dehancer mLut Maker
//
//  Created by denis svinarchuk on 02.12.2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import IMProcessing
import MetalKit

open class IMProcessingView: MTKView {
        
    public var source:IMPImageProvider? {
        didSet{
            syncQueue.async(flags: [.barrier]) { [weak self] in
                _ = self?.mutex.wait(timeout: DispatchTime.distantFuture)
                self?.__source = self?.source
                if self?.isPaused ?? true {
                    DispatchQueue.main.async {
                        self?.needsDisplay = true
                    }
                }
            }
        }
    }
    
    private var __source:IMPImageProvider? 
    
    public override init(frame frameRect: CGRect, device: MTLDevice?=nil) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        configure()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        configure()
    }
    
    deinit {
        //isPaused = true
    }
    
    open func configure() {
        delegate = self
        isPaused = true
        enableSetNeedsDisplay = true
    }
    
    //private static var __commandQueue = __device.makeCommandQueue(maxCommandBufferCount: IMProcessingView.maxFrames)!
    
    private lazy var commandQueue:MTLCommandQueue = self.device!.makeCommandQueue(maxCommandBufferCount: IMProcessingView.maxFrames)!
    //{    return IMProcessingView.__commandQueue
   // }
    
    private static let maxFrames = 3  
    
    private let mutex = DispatchSemaphore(value: IMProcessingView.maxFrames)
    
    
    private var framesCount = 0
    
    private func framesUpdated(){
        if framesCount > IMProcessingView.maxFrames {
            isPaused = true
            framesCount = 0
        }
        else {
            framesCount += 1
        }
    }
    
    
    fileprivate func refresh(){

        guard
            let pipeline = self.pipeline, 
            let texture =  self.source?.texture, //self.source?.makeCopy(), 
            let commandBuffer = commandQueue.makeCommandBuffer() else {
                framesUpdated()
                mutex.signal()
                return             
        }
        
        self.render(commandBuffer: commandBuffer, texture: texture, with: pipeline){ [weak self] in
            self?.framesUpdated()
            self?.mutex.signal()
        }
    }
    
    fileprivate func render(commandBuffer:MTLCommandBuffer, texture:MTLTexture?, with pipeline: MTLRenderPipelineState,
                            complete: @escaping () -> Void) {        
        
                
        commandBuffer.label = "Frame command buffer"
        
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in            
            complete()            
            return
        }
        
        if  let renderPassDescriptor = currentRenderPassDescriptor,               
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor){
            
            renderEncoder.label = "render encoder"
            
            renderEncoder.pushDebugGroup("draw image")
            renderEncoder.setRenderPipelineState(pipeline)
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset:0, index:0)
            renderEncoder.setFragmentTexture(texture, index:0)            
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
            
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
            
            commandBuffer.present(currentDrawable!)
            commandBuffer.commit()
        }
        else {
            complete()            
        }
    }
    
    //private lazy var library = self.device!.makeDefaultLibrary()
    
    private static var library = MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()!    
    
    private lazy var fragment = IMProcessingView.library.makeFunction(name: "fragment_passview")
    private lazy var vertex   = IMProcessingView.library.makeFunction(name: "vertex_passview")    
    
    private lazy var pipeline:MTLRenderPipelineState? = {
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            
            descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
            
            descriptor.vertexFunction   = self.vertex
            descriptor.fragmentFunction = self.fragment
            
            return try self.device!.makeRenderPipelineState(descriptor: descriptor)
        }
        catch let error as NSError {
            NSLog("IMPView error: \(error)")
            return nil
        }
    }()
    
    private static let viewVertexData:[Float] = [
        -1.0,  -1.0,  0.0,  1.0,
        1.0,  -1.0,  1.0,  1.0,
        -1.0,   1.0,  0.0,  0.0,
        1.0,   1.0,  1.0,  0.0,
        ]
    
    private lazy var vertexBuffer:MTLBuffer? = {
        let v = self.device?.makeBuffer(bytes: IMProcessingView.viewVertexData, length: MemoryLayout<Float>.size*IMProcessingView.viewVertexData.count, options: [])
        v?.label = "Vertices"
        return v
    }()
    
    public var syncQueue = DispatchQueue(label:  String(format: "com.dehancer.metal.view.sync-%08x%08x", arc4random(), arc4random()))
    public var refreshQueue = DispatchQueue(label:  String(format: "com.dehancer.metal.view.refresh-%08x%08x", arc4random(), arc4random()))
}

extension IMProcessingView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        refreshQueue.async(flags: [.barrier]) { [weak self] in
            self?.refresh()            
        }
    }    
    
}
