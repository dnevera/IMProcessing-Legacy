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
    
    
    @available(iOS 9.0, *)
    public class IMPView: MTKView {
        
        lazy var textureDelay:IMPTextureDelayLine = IMPTextureDelayLine()
        var textureCache:IMPTextureCache? = nil
        
        public var filter:IMPFilter? = nil {
            didSet {
            
                if let context = filter?.context {
                    textureCache = IMPTextureCache(context:context)
                }
                
                self.processing(size: self.drawableSize)
                
                filter?.addObserver(newSource: { (source) in
                    if let size = source.size {
                        //let scale   = UIScreen.main.scale
                        //let newsize = self.bounds.size
                        //self.filter?.downscaleSize = NSSize(width: newsize.width * scale, height: newsize.height * scale)
                        self.drawableSize = size
                        //self.processing(size: self.drawableSize)
                        self.needProcessing = true
                    }
                })
                
                filter?.addObserver(dirty: { (filter, source, destintion) in
                    //if self.isPaused {
                    //    self.processing(size: self.drawableSize)
                    //}
                    self.needProcessing = true
                })
            }
        }
        
        var needProcessing = true
        
        public var viewReadyHandler:(()->Void)?
        
        override init(frame frameRect: CGRect, device: MTLDevice? = nil) {
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
        
        var context:IMPContext
        
        lazy var ciContext: CIContext = { [unowned self] in
            return self.context.coreImage!
            }()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var frameCounter = 0
        var renderQueue = DispatchQueue(label: "rendering.improcessing.com")
        
        class ProcessingOperation: Operation {
            
            let size:NSSize
            let view:IMPView
            
            init(view: IMPView, size: NSSize) {
                self.view = view
                self.size = size
            }
            
            override func main() {
                processing(size: self.size)
            }
            
            func processing(size: NSSize)  {
                
                unowned let this = self.view
                
                guard let filter = this.filter else { return }
                
                //guard let image = filter.destination.image else { return }
                //
                
                //filter.context.async {
                    guard let texture = this.textureCache?.requestTexture(size:size, pixelFormat: this.colorPixelFormat) else { return }
                    
                filter.apply(to: texture)
                    
                    //                guard let texture = processedTexture else {
                    //                    return
                    //                }
                    
                    //                let bounds = CGRect(origin: CGPoint.zero, size: size)
                    
                    //                let commandBuffer = filter.context.commandBuffer
                    
                    //                let originX = image.extent.origin.x
                    //                let originY = image.extent.origin.y
                    //
                    //                let scaleX = size.width /  image.extent.width
                    //                let scaleY = size.height / image.extent.height
                    //                let scale = min(scaleX, scaleY)
                    //
                    //                let transform = CGAffineTransform.identity.translatedBy(x: -originX, y: -originY)
                    //                let scaledImage = image.applying(transform.scaledBy(x: scale, y: scale))
                    //
                    //                filter.context.coreImage?.render(scaledImage,
                    //                                                 to: texture,
                    //                                                 commandBuffer: commandBuffer,
                    //                                                 bounds: bounds,
                    //                                                 colorSpace: this.colorSpace
                    //                )
                    //                
                    //                commandBuffer?.commit()
                    
                    if let t = this.textureDelay.pushBack(texture: texture) {
                        this.textureCache?.returnTexure(t)
                    }
                    this.needProcessing = false
                    this.setNeedsDisplay()
               // }
            }
        }
        
        var processingOperation:ProcessingOperation? = nil
        
        lazy var processingOperationQueue:OperationQueue = {
            var o = OperationQueue()
            o.maxConcurrentOperationCount = 1
            return o
        }()

        func processing(size: NSSize)  {
            if needProcessing {
                needProcessing = false
                processingOperationQueue.cancelAllOperations()
                processingOperationQueue.addOperation(ProcessingOperation(view: self, size: size))
            }
        }
        
        func refresh(rect: CGRect){
            
            guard let drawble = self.currentDrawable else { return }
            let targetTexture = drawble.texture
            
            context.async {

                guard let sourceTexture = self.textureDelay.request() else {
                    DispatchQueue.main.async {
                        self.setNeedsDisplay()
                    }
                    return
                }
                
                
                if let commandBuffer = self.context.commandBuffer {
                    
                    if self.isFirstFrame  {
                        commandBuffer.addCompletedHandler{ (commandBuffer) in
                            self.frameCounter += 1
                        }
                    }

                    let blit = commandBuffer.makeBlitCommandEncoder()
                    
                    blit.copy(
                        from: sourceTexture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x:0,y:0,z:0),
                        sourceSize: targetTexture.size,
                        to: targetTexture,
                        destinationSlice: 0,
                        destinationLevel: 0,
                        destinationOrigin: MTLOrigin(x:0,y:0,z:0))
                    
                    blit.endEncoding()

                    commandBuffer.present(drawble)
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

                if let texture = self.textureDelay.pushFront(texture: sourceTexture) {
                    self.textureCache?.returnTexure(texture)
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
            preferredFramesPerSecond = 30
            //transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
        }
        
        private var isFirstFrame = true
    }
    
    
    extension IMPView: MTKViewDelegate {
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            context.async {
                self.processing(size: self.drawableSize)
            }
            guard needUpdateDisplay else { return }
            needUpdateDisplay = false
            refresh(rect: view.bounds)
        }
    }

#endif
