//
//  IMPMetalView.swift
//  IMProcessingUI
//
//  Created by Denis Svinarchuk on 20/12/16.
//  Copyright © 2016 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
    let screenScale = UIScreen.main.scale
#else
    let screenScale = NSScreen.main()?.backingScaleFactor ?? 1
#endif

import MetalKit

#if os(iOS)
    
    import UIKit
    public typealias IMPViewBase = UIView
    
#else
    
    import AppKit
    public typealias IMPViewBase = NSView
    public typealias IMPDragOperationHandler = ((_ files:[String]) -> Bool)
      
    public extension NSView {
        public var backgroundColor:NSColor? {
            set{
                wantsLayer = true
                layer?.backgroundColor = newValue?.cgColor
            }
            get{
                if let c = layer?.backgroundColor {
                    return NSColor(cgColor: c)
                }
                return nil
            }
        }
    }
    
    
#endif


public class IMPView: MTKView {
    
    public static var scaleFactor:Float{
        get {
            #if os(iOS)
                return  Float(UIScreen.mainScreen().scale)
            #else
                let screen = NSScreen.main()
                let scaleFactor = screen?.backingScaleFactor ?? 1.0
                return Float(scaleFactor)
            #endif
        }
    }

    
    #if os(iOS)
        public var renderingEnabled = false
    #else
        public typealias MouseEventHandler = ((_ event:NSEvent, _ location:NSPoint, _ view:NSView)->Void)
        public let renderingEnabled = true
    #endif
    
    public var exactResolutionEnabled = false
    
    public var filter:IMPFilter? = nil {
        didSet {
            
            self.needProcessing = true
            
            filter?.addObserver(newSource: { (source) in
                self.updateDrawbleSize()
            })
            
            filter?.addObserver(dirty: { (filter, source, destintion) in
                self.needProcessing = true
            })
        }
    }
    
    private func updateDrawbleSize()  {
        if let size = self.filter?.source?.size {
            if exactResolutionEnabled {
                drawableSize = size
            }
            else {
                // down scale targetTexture
                let newSize = NSSize(width: self.bounds.size.width * screenScale,
                                     height: self.bounds.size.height * screenScale
                )
                let scale = fmax(fmin(fmin(newSize.width/size.width, newSize.height/size.height),1),0.01)
                drawableSize = NSSize(width: size.width * scale, height: size.height * scale)
            }
            needProcessing = true
        }
    }
    
    #if os(OSX)
    var invalidateSizeTimer:Timer?
    
    func invalidateSizeTimerHandler(timer:Timer?)  {
        updateDrawbleSize()
    }
    
    public override var frame: NSRect {
        didSet{
            invalidateSizeTimer?.invalidate()
            invalidateSizeTimer = Timer.scheduledTimer(timeInterval: 1/TimeInterval(preferredFramesPerSecond),
                                                       target: self, 
                                                       selector: #selector(invalidateSizeTimerHandler(timer:)),
                                                       userInfo: nil, repeats: false)
        }
    }
    #endif
    
    public var viewReadyHandler:(()->Void)?
    
    override public init(frame frameRect: CGRect, device: MTLDevice? = nil) {
        context = IMPContext(device:device, lazy: true)
        super.init(frame: frameRect, device: self.context.device)
        _init_()
    }
    
    required public init(coder: NSCoder) {
        context = IMPContext(lazy: true)
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
    
    lazy var frameImage:IMPImageProvider = IMPImage(context: self.context)
    
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
                
                filter.destinationSize = self.size
                view.frameImage = filter.destination
                
                if view.frameImage.texture != nil {
                    
                    //NSLog("   !!!!!  new frame = \(view.frameImage.texture)")
                    
                    //filter.apply(view.frameImage, with: self.size)
                    
                    view.needProcessing = false
                    view.setNeedsDisplay()
                }
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
    
    lazy var viewPort:MTLViewport = MTLViewport(originX: 0, originY: 0, width: Double(self.drawableSize.width), height: Double(self.drawableSize.height), znear: 0, zfar: 1)
    
    public override var drawableSize: CGSize {
        didSet{
            viewPort = MTLViewport(originX: 0, originY: 0, width: Double(self.drawableSize.width), height: Double(self.drawableSize.height), znear: 0, zfar: 1)
        }
    }
    
    func refresh(rect: CGRect){
        
        context.wait()
        
        guard let drawable = self.currentDrawable else {
            context.resume()
            return
        }
        
        guard let sourceTexture = frameImage.texture else {
            needProcessing = true
            context.resume()
            return
        }
        
        guard let commandBuffer = context.commandBuffer else {
            context.resume()
            return
        }
        
        if isFirstFrame  {
            commandBuffer.addCompletedHandler{ (commandBuffer) in
                self.frameCounter += 1
            }
        }
        
        let targetTexture = drawable.texture
        
        if renderingEnabled == false &&
            sourceTexture.cgsize == drawableSize  &&
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
            renderPassDescriptor.colorAttachments[0].texture     = targetTexture
            
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            if let pipeline = renderPipeline {
                
                encoder.setRenderPipelineState(pipeline)
                
                encoder.setVertexBuffer(vertexBuffer, offset:0, at:0)
                //encoder.setFragmentTexture(sourceTexture.makeTextureView(pixelFormat: self.colorPixelFormat), at:0)
                encoder.setFragmentTexture(sourceTexture, at:0)
                encoder.setViewport(viewPort)
                
                encoder.drawPrimitives(type: .triangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
                encoder.endEncoding()
            }
        }
        
        commandBuffer.present(drawable)
        
        commandBuffer.addCompletedHandler{ (commandBuffer) in
            self.context.resume()
        }
        
        commandBuffer.commit()

        //
        // https://forums.developer.apple.com/thread/64889
        //
        self.draw()

        if frameCounter > 0  && isFirstFrame {
            isFirstFrame = false
            if viewReadyHandler !=  nil {
                viewReadyHandler!()
            }
        }
    }
    
    fileprivate lazy var processingLink:IMPDisplayLink = IMPDisplayLink { (timev) in
        self.context.runOperation(.async){
            let go = self.needProcessing
            self.needProcessing = false
            if go {
                self.processing(size: self.drawableSize)
            }
        }
    }
    
    fileprivate var needUpdateDisplay = false
    #if os(iOS)
    public override func setNeedsDisplay() {
        needUpdateDisplay = true
        if isPaused {
            super.setNeedsDisplay()
        }
    }
    #else
    public func setNeedsDisplay() {
        needUpdateDisplay = true
        if isPaused {
            display()
        }
    }
    #endif
    
    private func _init_() {
        framebufferOnly = false
        autoResizeDrawable = false
        #if os(iOS)
            contentMode = .scaleAspectFit
        #elseif os(OSX)
            postsFrameChangedNotifications = true
            //addObserver(self, forKeyPath: NSViewFrameDidChange.name, options: [.new], context: nil)
        #endif
        enableSetNeedsDisplay = false
        isPaused = false
        colorPixelFormat = .bgra8Unorm
        delegate = self
        processingLink.isPaused = false
    }
    
    public override var isPaused: Bool {
        didSet{
            processingLink.isPaused = isPaused
        }
    }
    
    public override var preferredFramesPerSecond: Int {
        didSet{
            processingLink.preferredFramesPerSecond = preferredFramesPerSecond
        }
    }
    
    private var isFirstFrame = true
    
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
    
    #if os(OSX)

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        let sourceDragMask = sender.draggingSourceOperationMask()
        let pboard = sender.draggingPasteboard()
        
        if pboard.availableType(from: [NSFilenamesPboardType]) == NSFilenamesPboardType {
            if sourceDragMask.rawValue & NSDragOperation.generic.rawValue != 0 {
                return NSDragOperation.generic
            }
        }
        
        return []
    }
    
    public var dragOperation:IMPDragOperationHandler?
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let files  = sender.draggingPasteboard().propertyList(forType: NSFilenamesPboardType) {
            if let o = dragOperation {
                return o(files as! [String])
            }
        }
        return false
    }
    
    lazy var trackingArea:NSTrackingArea? = nil
    
    override public func updateTrackingAreas() {
        if mouseEventEnabled {
            super.updateTrackingAreas()
            if let t = trackingArea{
                removeTrackingArea(t)
            }
            trackingArea = NSTrackingArea(rect: frame,
                                          options: [.activeInKeyWindow,.mouseMoved,.mouseEnteredAndExited],
                                          owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
        }
    }
    
    override public func mouseEntered(with event:NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    override public func mouseExited(with event:NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    override public func mouseMoved(with event:NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    override public func mouseDown(with event:NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    override public func mouseUp(with event:NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    override public func mouseDragged(with event: NSEvent) {
        lounchMouseObservers(event: event)
    }
    
    var mouseEventHandlers = [MouseEventHandler]()
    
    var mouseEventEnabled = false
    public func addMouseEventObserver(observer:@escaping MouseEventHandler){
        mouseEventHandlers.append(observer)
        mouseEventEnabled = true
    }
    
    public func removeMouseEventObservers(){
        mouseEventEnabled = false
        if let t = trackingArea{
            removeTrackingArea(t)
        }
        mouseEventHandlers.removeAll()
    }
    
    func lounchMouseObservers(event:NSEvent){
        let location = event.locationInWindow
        let point  = self.convert(location,from:nil)
        for o in mouseEventHandlers {
            o(event, point, self)
        }
    }
    

    
    #endif
}


extension IMPView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        
        guard needUpdateDisplay else { return }
        needUpdateDisplay = false
        
        context.runOperation(.async) { [unowned self] in
            self.refresh(rect: view.bounds)
        }
    }
}
