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
        lazy var textureCache:IMPTextureCache = IMPTextureCache(context:self.context)
        
        public var filter:IMPFilter? = nil {
            didSet {
                self.processing(size: self.drawableSize)
                
                filter?.addObserver(newSource: { (source) in
                    if let size = source.image?.extent.size {
                        let scale   = UIScreen.main.scale
                        let newsize = self.bounds.size
                        self.filter?.downscaleSize = NSSize(width: newsize.width * scale, height: newsize.height * scale)
                        self.drawableSize = size
                        self.processing(size: self.drawableSize)
                    }
                })
                
                filter?.addObserver(dirty: { (filter, source, destintion) in
                    self.processing(size: self.drawableSize)
                })
            }
        }
        
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
        
        var isProcessing = false
        
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
                let t1 = Date.timeIntervalSinceReferenceDate
                
                unowned var this = self.view
                
                guard let filter = this.filter else { return }
                
                this.isProcessing = true
                
                guard let image = filter.destination.image else { return }
                
                let t2 = Date.timeIntervalSinceReferenceDate

                guard let texture = this.textureCache.requestTexture(size:size, pixelFormat: this.colorPixelFormat) else { return }
                
                //NSLog("requested texture.size = \(texture.size), size = \(size) image = \(image) isProcessing = \(this.isProcessing)")
                
                let bounds = CGRect(origin: CGPoint.zero, size: size)
                
                let commandBuffer = filter.context.commandBuffer
                
                let originX = image.extent.origin.x
                let originY = image.extent.origin.y
                
                let scaleX = size.width /  image.extent.width
                let scaleY = size.height / image.extent.height
                let scale = min(scaleX, scaleY)
                
                var transform = CGAffineTransform.identity.translatedBy(x: -originX, y: -originY)
                let scaledImage = image.applying(transform.scaledBy(x: scale, y: scale))
                
                filter.context.coreImage?.render(scaledImage,
                                                 to: texture,
                                                 commandBuffer: commandBuffer,
                                                 bounds: bounds,
                                                 colorSpace: this.colorSpace
                )
                
                let t3 = Date.timeIntervalSinceReferenceDate

                commandBuffer?.commit()
                this.textureDelay.pushBack(texture: texture)
                
                DispatchQueue.main.async {
                    this.setNeedsDisplay()
                }
                
                let t4 = Date.timeIntervalSinceReferenceDate
                
                //print(" cameraFrame update time: processing = \(t2-t1) render image = \(t3-t2) buffering = \(t4-t3) sum = \(t4-t1)")

                this.isProcessing = false
            }
        }
        
        var processingOperation:ProcessingOperation? = nil
        
        lazy var processingOperationQueue:OperationQueue = {
            var o = OperationQueue()
            o.maxConcurrentOperationCount = 1
            return o
        }()

        func processing(size: NSSize)  {
            processingOperationQueue.cancelAllOperations()
            processingOperationQueue.addOperation(ProcessingOperation(view: self, size: size))
        }
        
        func refresh(rect: CGRect){
            
            guard let drawble = self.currentDrawable else { return }
            let targetTexture = drawble.texture
            
            context.dispatchQueue.async {

                guard let sourceTexture = self.textureDelay.request() else {
                    DispatchQueue.main.async {
                        self.setNeedsDisplay()
                    }
                    return
                }
                
                let t1 = Date.timeIntervalSinceReferenceDate
                
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
                    //commandBuffer.waitUntilCompleted()

                    //
                    // https://forums.developer.apple.com/thread/64889
                    //
                    self.draw()

                    let t2 = Date.timeIntervalSinceReferenceDate

                    //print(" cameraFrame update time: rendering = \(t2-t1)")

                    if self.frameCounter > 0  && self.isFirstFrame {
                        self.isFirstFrame = false
                        if self.viewReadyHandler !=  nil {
                            self.viewReadyHandler!()
                        }
                    }
                }

                if let texture = self.textureDelay.pushFront(texture: sourceTexture) {
                    self.textureCache.returnTexure(texture)
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
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        }
        
        public func draw(in view: MTKView) {
            guard needUpdateDisplay else { return }
            needUpdateDisplay = false
            refresh(rect: view.bounds)
        }
    }

#endif
