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

        lazy var commandQueue:MTLCommandQueue   = self.device!.makeCommandQueue(maxCommandBufferCount:3)
    
        lazy var ciContext: CIContext = { [unowned self] in
            return CIContext(mtlDevice: self.device!)
        }()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var frameCounter = 0
        
        func refresh(rect: CGRect)
        {
            guard let destination = (currentDestination ?? filter?.destination) else { return }
            
            currentDestination = destination
            
            guard let targetTexture = currentDrawable?.texture,
                let image = destination.image
                else {
                return
            }

            let commandBuffer = commandQueue.makeCommandBufferWithUnretainedReferences()

            if self.isFirstFrame  {
                commandBuffer.addCompletedHandler{ (commandBuffer) in
                    self.frameCounter += 1
                }
            }
            
            //
            // https://github.com/FlexMonkey/CoreImageHelpers/blob/master/CoreImageHelpers/coreImageHelpers/ImageView.swift
            //
            let bounds = CGRect(origin: CGPoint.zero, size: drawableSize)
            
            let originX = image.extent.origin.x
            let originY = image.extent.origin.y
            
            let scaleX = drawableSize.width /  image.extent.width
            let scaleY = drawableSize.height / image.extent.height
            let scale = min(scaleX, scaleY)
            
            let scaledImage = image
                .applying(CGAffineTransform(translationX: -originX, y: -originY))
                .applying(CGAffineTransform(scaleX: scale, y: scale))
            
            ciContext.render(scaledImage,
                             to: targetTexture,
                             commandBuffer: commandBuffer,
                             bounds: bounds,
                             colorSpace: colorSpace)
            
            commandBuffer.present(currentDrawable!)
            commandBuffer.commit()

            if frameCounter > 0  && isFirstFrame {
                isFirstFrame = false
                if viewReadyHandler !=  nil {
                    viewReadyHandler!()
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
            enableSetNeedsDisplay = true
            isPaused = false
            colorPixelFormat = .bgra8Unorm
            delegate = self
        }
        
        private var isFirstFrame = true
        var currentDestination:IMPImageProvider? = nil
    }
    
    
    extension IMPView: MTKViewDelegate {
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        public func draw(in view: MTKView) {
            
            guard needUpdateDisplay else { return }
            needUpdateDisplay = false
            refresh(rect: view.bounds)
        }
    }
    
#endif
