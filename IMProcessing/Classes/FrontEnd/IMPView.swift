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
    
    typealias TextureQueue = IMPQueue<MTLTexture>
    
    public class TextureCache {
        var cache = [Int64:TextureQueue]()
        public var device:MTLDevice
        
        public init(device:MTLDevice) {
            self.device = device
        }
     
        public func requestTexture(size: NSSize, pixelFormat:MTLPixelFormat = IMProcessing.colors.pixelFormat) -> MTLTexture? {
            let hash = hashFor(size: size, pixelFormat: pixelFormat)
            if let t = cache[hash]?.dequeue() {
                return t
            }
            else {
                let t = device.make2DTexture(size: size, pixelFormat: pixelFormat)
                var q = TextureQueue()
                q.enqueue(t)
                cache[hash] = q
                return cache[hash]?.dequeue()
            }
        }
        
        public func returnTexure(_ texture:MTLTexture){
            let hash = hashFor(texture: texture)
            if cache[hash] == nil {
                cache[hash] =  TextureQueue()
            }
            cache[hash]?.enqueue(texture)
        }
        
        func hashFor(size: NSSize, pixelFormat:MTLPixelFormat) -> Int64 {
            var result:Int64 = 1
            let prime:Int64 = 31
            result = prime * result + Int64(size.width)
            result = prime * result + Int64(size.height)
            result = prime * result + Int64(pixelFormat.rawValue)
            return result

        }
        
        func hashFor(texture: MTLTexture) -> Int64 {
            return hashFor(size: texture.cgsize, pixelFormat: texture.pixelFormat)
        }
        
    }
    
    
    @available(iOS 9.0, *)
    public class IMPView: MTKView {
        
        lazy var textureCache:TextureCache = TextureCache(device: self.device!)
        
        public var filter:IMPFilter? = nil {
            didSet {
                setNeedsDisplay()
                
                var anotherPassed = false
                
                filter?.addObserver(newSource: { (source) in
                    if let size = source.image?.extent.size {
                        self.drawableSize = size
                        anotherPassed = true
                        self.currentDestination = nil
                        self.setNeedsDisplay()
                    }
                })
                
                filter?.addObserver(destinationUpdated: { (destination) in
                    
                    self.currentDestination = destination
                    if !anotherPassed{
                        self.setNeedsDisplay()
                    }
                    anotherPassed = false
                })
                
                filter?.addObserver(enabling: { (filter, source, destintion) in
                    anotherPassed = true
                    self.currentDestination = nil
                    self.setNeedsDisplay()
                })
                
                filter?.addObserver(dirty: { (filter, source, destintion) in
                    anotherPassed = true
                    self.currentDestination = nil
                    self.setNeedsDisplay()
                })
            }
        }
        
        public var viewReadyHandler:(()->Void)?
        
        override init(frame frameRect: CGRect, device: MTLDevice? = nil) {
            super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
            guard self.device != nil else {
                fatalError("The system does not support any MTL devices...")
            }
            _init_()
        }
        
        required public init(coder: NSCoder) {
            super.init(coder: coder)
            device = MTLCreateSystemDefaultDevice()
            guard device != nil else {
                fatalError("The system does not support any MTL devices...")
            }
            _init_()
        }
        
        lazy var commandQueue:MTLCommandQueue   = self.device!.makeCommandQueue()
        
        lazy var ciContext: CIContext = { [unowned self] in
            return CIContext(mtlDevice: self.device!)
            }()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var frameCounter = 0
        var renderQueue = DispatchQueue(label: "rendering.improcessing.com")
        
        func refresh(rect: CGRect)
        {
            let t1 = Date.timeIntervalSinceReferenceDate
            guard let destination = (currentDestination ?? filter?.destination) else { return }
            let t2 = Date.timeIntervalSinceReferenceDate
            
            let texture = textureCache.requestTexture(size: drawableSize)
            
            DispatchQueue.main.async {
                
                self.currentDestination = destination
                
                guard
                    let drawble = self.currentDrawable,
                    let image = destination.image
                    else {
                        return
                }
                
                let targetTexture = drawble.texture
                let commandBuffer = self.commandQueue.makeCommandBufferWithUnretainedReferences()
                
                NSLog(" request texture = \(texture?.cgsize) drawble.texture = \(drawble.texture.cgsize)")

                
                commandBuffer.addScheduledHandler({ (commandBuffer) in
                })
                
                if self.isFirstFrame  {
                    commandBuffer.addCompletedHandler{ (commandBuffer) in
                        self.frameCounter += 1
                    }
                }
                
                //
                // https://github.com/FlexMonkey/CoreImageHelpers/blob/master/CoreImageHelpers/coreImageHelpers/ImageView.swift
                //
                let bounds = CGRect(origin: CGPoint.zero, size: self.drawableSize)
                
                let originX = image.extent.origin.x
                let originY = image.extent.origin.y
                
                let scaleX = self.drawableSize.width /  image.extent.width
                let scaleY = self.drawableSize.height / image.extent.height
                let scale = min(scaleX, scaleY)
                
                let scaledImage = image
                    .applying(CGAffineTransform(translationX: -originX, y: -originY))
                    .applying(CGAffineTransform(scaleX: scale, y: scale))
                
                self.ciContext.render(scaledImage,
                                      to: targetTexture,
                                      commandBuffer: commandBuffer,
                                      bounds: bounds,
                                      colorSpace: self.colorSpace
                )
                
                let t3 = Date.timeIntervalSinceReferenceDate
                
                NSLog("Current frame time:  rendering = \(t3-t2) filtering = \(t2-t1)")
                
                commandBuffer.present(drawble)
                commandBuffer.commit()
                
                self.textureCache.returnTexure(texture!)
                
                if self.frameCounter > 0  && self.isFirstFrame {
                    self.isFirstFrame = false
                    if self.viewReadyHandler !=  nil {
                        self.viewReadyHandler!()
                    }
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
        }
        
        private var isFirstFrame = true
        var currentDestination:IMPImageProvider? = nil
    }
    
    
    extension IMPView: MTKViewDelegate {
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        public func draw(in view: MTKView) {
            
            guard needUpdateDisplay else { return }
            needUpdateDisplay = false
            
            renderQueue.async{
                self.refresh(rect: view.bounds)
            }
        }
    }
    
#endif
