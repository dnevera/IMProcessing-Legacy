//
//  IMPGLView.swift
//  IMPCoreImageMTLKernel
//
//  Created by Denis Svinarchuk on 16/02/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import GLKit
import UIKit
import MetalKit
import QuartzCore

public class IMPGLView: GLKView{
    
    public var filter:IMPFilter? = nil {
        didSet {
            setNeedsDisplay()
            
            var anotherPassed = false
            
            filter?.addObserver(newSource: { (source) in
                
                self.updateBackgound(width: self.width, height: self.height)
                
                if let _ = source.image?.extent.size {
                    anotherPassed = true
                    self.currentImage = nil
                    self.setNeedsDisplay()
                }
            })
            
            filter?.addObserver(destinationUpdated: { (destination) in
                if !anotherPassed{
                    self.currentImage = nil
                    self.setNeedsDisplay()
                }
                anotherPassed = false
            })
            
            filter?.addObserver(enabling: { (filter, source, destintion) in
                anotherPassed = true
                self.currentImage = nil
                self.setNeedsDisplay()
            })
            
            filter?.addObserver(dirty: { (filter, source, destintion) in
                anotherPassed = true
                self.currentImage = nil
                self.setNeedsDisplay()
            })
        }
    }
    
    public override init(frame frameRect: CGRect) {
        guard eaglContext != nil else {
            fatalError("init(frame:, context:) OpenGL ES could not be initialized")
        }
        super.init(frame: frameRect, context: eaglContext!)
        _init_()
    }

    
    public required init?(coder aDecoder: NSCoder){
        guard eaglContext != nil else {
            fatalError("init(frame:, context:) OpenGL ES could not be initialized")
        }
        super.init(coder: aDecoder)
        _init_()
    }
    
    func _init_()  {
        context = eaglContext!
        backgroundColor = NSColor.clear
        enableSetNeedsDisplay = true
        isOpaque = false
        delegate = self
        isPaused = false
    }
    
    public var isPaused:Bool {
        set{
            timer.isPaused = isPaused
        }
        get {
            return timer.isPaused
        }
    }
    
    private var needUpdateDisplay = false
    public override func setNeedsDisplay() {
        needUpdateDisplay = true
        if isPaused {
            super.setNeedsDisplay()
        }
    }

    var currentImage:CIImage? = nil
    
    let eaglContext = EAGLContext(api: .openGLES2)
    
    lazy var ciContext: CIContext = { [unowned self] in
        return CIContext(eaglContext: self.eaglContext!,
                         options: [kCIContextWorkingColorSpace: self.colorSpace])
        }()
    
    public override var backgroundColor: UIColor? {
        didSet{
            ciBackgroundColor = CIColor( color: backgroundColor ?? NSColor.clear)
        }
    }
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    lazy var ciBackgroundColor:CIColor = CIColor( color: self.backgroundColor ?? NSColor.clear)
    
    func updateBackgound(width:Int, height:Int) {
        
        glClearColor(0,0,0,0)
        
        self.isOpaque = false
        self.layer.isOpaque = false
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT)|GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        ciContext.draw(CIImage(color: self.ciBackgroundColor),
                       in: CGRect(x: 0,
                                  y: 0,
                                  width: width,
                                  height: height),
                       from: CGRect(x: 0,
                                    y: 0,
                                    width: width,
                                    height: height))
    }
    
    var width:Int {
        return Int(self.frame.size.width * UIScreen.main.scale)
    }
    
    var height:Int {
        return Int(self.frame.size.height * UIScreen.main.scale)
    }
    
    #if os(iOS)
    private lazy var timer:CADisplayLink = {
        var t = CADisplayLink(target: self, selector: #selector(self.refresh))
        t.add(to: RunLoop.current, forMode:.commonModes)
        return t
    }()
    #endif
    
    
    func refresh()  {
        guard needUpdateDisplay else { return }
        needUpdateDisplay = false
        super.setNeedsDisplay()
    }
}

//
// https://github.com/FlexMonkey/CoreImageHelpers/blob/master/CoreImageHelpers/coreImageHelpers/ImageView.swift
//
extension IMPGLView: GLKViewDelegate {
    
    public func glkView(_ view: GLKView, drawIn rect: CGRect) {
        
        guard let image = (currentImage ?? filter?.destination.image) else { return }

        currentImage = image
//        currentImage = CIImage(imageProvider: image,
//                               size: Int(image.extent.width),
//                               Int(image.extent.height),
//                               format: kCIFormatARGB8,
//                               colorSpace: colorSpace, options: nil)
        
        let targetRect = image.extent.aspectFitInRect(
            target: NSRect(origin: NSPoint.zero,
                           size: NSSize(width: drawableWidth,
                                        height: drawableHeight)))
        
        self.updateBackgound(width: self.width, height: self.height)

        NSLog("glkView image: \(image.extent)")
        
        ciContext.draw(image,
                       in: targetRect,
                       from: image.extent)
    }
}

extension CGRect {
    
    func aspectFitInRect(target: CGRect) -> CGRect {
    
        let scale: CGFloat = {
                let scale = target.width / self.width
                
                return self.height * scale <= target.height ?
                    scale :
                    target.height / self.height
        }()
        
        let width = self.width * scale
        let height = self.height * scale
        let x = target.midX - width / 2
        let y = target.midY - height / 2
        
        return CGRect(x: x,
                      y: y,
                      width: width,
                      height: height)
    }
}
