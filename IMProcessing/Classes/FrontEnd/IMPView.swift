//
//  IMPMetalView.swift
//  IMProcessingUI
//
//  Created by Denis Svinarchuk on 20/12/16.
//  Copyright © 2016 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
    import MetalKit
    
    let screenScale = UIScreen.main.scale

    @available(iOS 9.0, *)
    public class IMPView: MTKView {
        
        public var renderingEnabled = false
        
        public var exactResolutionEnabled = false
        
        public var filter:IMPFilter? = nil {
            didSet {
                
                self.needProcessing = true
                
                filter?.addObserver(newSource: { (source) in
                    if let size = source.size {
                        
                        if self.exactResolutionEnabled {
                            self.drawableSize = size
                        }
                        else {
                            // down scale targetTexture
                            let newSize = NSSize(width: self.bounds.size.width * screenScale,
                                                 height: self.bounds.size.height * screenScale
                                                )
                            let scale = fmin(fmax(newSize.width/size.width, newSize.height/size.height),1)
                            self.drawableSize = NSSize(width: size.width * scale, height: size.height * scale)
                        }
                        self.needProcessing = true
                    }
                })
                
                filter?.addObserver(dirty: { (filter, source, destintion) in
                    self.needProcessing = true
                })
            }
        }
        
        public var viewReadyHandler:(()->Void)?
        
        override public init(frame frameRect: CGRect, device: MTLDevice? = nil) {
            context = IMPContext(device:device)
            super.init(frame: frameRect, device: self.context.device)
            _init_()
        }
        
        required public init(coder: NSCoder) {
            context = IMPContext()
            super.init(coder: coder)
            device = self.context.device
            guard device != nil else {
                fatalError("The system does not support any MTL devices...")
            }
            _init_()
        }
        
        public let context:IMPContext
        
        var needProcessing = true {
            didSet{
                if needProcessing {
                    processingOperationQueue.cancelAllOperations()
                }
            }
        }
        
        var frameCounter = 0
        
        var currentTexture:MTLTexture? = nil
        
        class ProcessingOperation: Operation {
            
            let size:NSSize
            let view:IMPView
            
            init(view: IMPView, size: NSSize) {
                self.view = view
                self.size = size
            }
            
            override func main() {
                
                unowned let view = self.view
                
                guard let filter = view.filter else { return }
                
                view.context.runOperation(.async) {
                    //let t1 = Date()

                    filter.destinationSize = self.size
                    
                    view.currentTexture = filter.destination.texture
                    
                    view.needProcessing = false
                    view.setNeedsDisplay()
                    
                    //NSLog("procesingLinkHandler time = \(-t1.timeIntervalSinceNow)  drawableSize = \(view.drawableSize)")
                }
            }
        }
        
        var processingOperation:ProcessingOperation? = nil
        
        lazy var processingOperationQueue:OperationQueue = {
            var o = OperationQueue()
            o.maxConcurrentOperationCount = 1
            return o
        }()

        func processing(size: NSSize)  {
            self.processingOperationQueue.cancelAllOperations()
            self.processingOperationQueue.addOperation(ProcessingOperation(view: self, size: size))
        }
        
        func refresh(rect: CGRect){
            context.runOperation(.async) {
                //let t1 = Date()

                guard self.needUpdateDisplay else { return }
                self.needUpdateDisplay = false
                
                guard let drawable = self.currentDrawable else { return }
                let targetTexture = drawable.texture
                
                guard let sourceTexture = self.currentTexture else {
                    self.needProcessing = true
                    return
                }
                
                if let commandBuffer = self.context.commandBuffer {
                    
                    if self.isFirstFrame  {
                        commandBuffer.addCompletedHandler{ (commandBuffer) in
                            self.frameCounter += 1
                        }
                    }
                    
                    
                    if self.renderingEnabled == false &&
                        sourceTexture.cgsize == self.drawableSize  &&
                        sourceTexture.pixelFormat == targetTexture.pixelFormat{
                        let encoder = commandBuffer.makeBlitCommandEncoder()
                        encoder.copy(
                            from: sourceTexture,
                            sourceSlice: 0,
                            sourceLevel: 0,
                            sourceOrigin: MTLOrigin(x:0,y:0,z:0),
                            sourceSize: sourceTexture.size,
                            to: targetTexture,
                            destinationSlice: 0,
                            destinationLevel: 0,
                            destinationOrigin: MTLOrigin(x:0,y:0,z:0))
                        
                        
                        encoder.endEncoding()
                    }
                    else {
                        self.renderPassDescriptor.colorAttachments[0].texture     = targetTexture
                        
                        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: self.renderPassDescriptor)
                        
                        if let pipeline = self.renderPipeline {
                            
                            encoder.setRenderPipelineState(pipeline)
                            
                            encoder.setVertexBuffer(self.vertexBuffer, offset:0, at:0)
                            encoder.setFragmentTexture(sourceTexture, at:0)
                            
                            encoder.drawPrimitives(type: .triangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
                            encoder.endEncoding()
                        }
                    }
                    
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                    //
                    // https://forums.developer.apple.com/thread/64889
                    //
                    self.draw()
                    
                    if self.frameCounter > 0  && self.isFirstFrame {
                        self.isFirstFrame = false
                        if self.viewReadyHandler !=  nil {
                            self.viewReadyHandler!()
                        }
                    }
                }
                
                //NSLog("refresh time = \(-t1.timeIntervalSinceNow) size = \(self.currentTexture?.size) drawableSize = \(self.drawableSize)")
            }
        }
        
        @objc private func procesingLinkHandler() {
            context.runOperation(.async){
                let go = self.needProcessing
                self.needProcessing = false
                if go {
                    self.processing(size: self.drawableSize)
                }
            }
        }
        
        fileprivate var needUpdateDisplay = false
        public override func setNeedsDisplay() {
            needUpdateDisplay = true
            if isPaused {
                super.setNeedsDisplay()
            }
        }
        
        private func _init_() {
            framebufferOnly = false
            autoResizeDrawable = false
            contentMode = .scaleAspectFit
            enableSetNeedsDisplay = false
            isPaused = false
            colorPixelFormat = .bgra8Unorm
            delegate = self
            processingLink.add(to: .current, forMode: .commonModes)            
        }
        
        public override var preferredFramesPerSecond: Int {
            didSet{
                processingLink.preferredFramesPerSecond = preferredFramesPerSecond
            }
        }
        
        private var isFirstFrame = true
        
        private lazy var processingLink:CADisplayLink = CADisplayLink(target: self, selector: #selector(procesingLinkHandler))
        
        lazy var renderPassDescriptor:MTLRenderPassDescriptor =  {
            let d = MTLRenderPassDescriptor()
            d.colorAttachments[0].loadAction  = .clear
            d.colorAttachments[0].storeAction = .store
            d.colorAttachments[0].clearColor  =  self.clearColor
            return d
        }()
        
        lazy var vertexBuffer:MTLBuffer = {
            let v = self.context.device.makeBuffer(bytes: viewVertexData,
                                                   length:MemoryLayout<Float>.size*viewVertexData.count, 
                                                   options:[])
            v.label = "Vertices"
            return v
        }()
        
        lazy var fragmentfunction:MTLFunction? = self.context.defaultLibrary.makeFunction(name: "fragment_passview")
        
        lazy var renderPipeline:MTLRenderPipelineState? = {
            do {
                let descriptor = MTLRenderPipelineDescriptor()
                
                descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
                
                guard let vertex = self.context.defaultLibrary.makeFunction(name: "vertex_passview") else {
                    fatalError("IMPView error: vertex function 'vertex_passview' is not found in: \(self.context.defaultLibrary.functionNames)")
                }
                
                guard let fragment = self.context.defaultLibrary.makeFunction(name: "fragment_passview") else {
                    fatalError("IMPView error: vertex function 'fragment_passview' is not found in: \(self.context.defaultLibrary.functionNames)")
                }
                
                descriptor.vertexFunction   = vertex
                descriptor.fragmentFunction = fragment
                
                return try self.context.device.makeRenderPipelineState(descriptor: descriptor)
            }
            catch let error as NSError {
                NSLog("IMPView error: \(error)")
                return nil
            }
        }()
        
        static private let viewVertexData:[Float] = [
            -1.0,  -1.0,  0.0,  1.0,
            1.0,  -1.0,  1.0,  1.0,
            -1.0,   1.0,  0.0,  0.0,
            1.0,   1.0,  1.0,  0.0,
            ]
    }
    
    
    extension IMPView: MTKViewDelegate {
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            refresh(rect: view.bounds)
        }
    }

#endif
