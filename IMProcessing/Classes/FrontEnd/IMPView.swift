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
let screenScale = NSScreen.main?.backingScaleFactor ?? 1
#endif

import MetalKit

#if os(iOS)
    
    import UIKit
    public typealias IMPViewBase = UIView
    
#else
    
    import AppKit
    public typealias IMPViewBase = NSView
    public typealias IMPDragOperationHandler = ((_ files:[String]) -> Bool)
    
#endif


open class IMPView: MTKView {
    
    public var viewReadyHandler:(()->Void)?
    public var viewBufferCompleteHandler:((_ image:IMPImageProvider)->Void)?
    public var viewUpdateDrawbleHandler:((_ size:NSSize)->Void)?

    open func configure(){}
    
    public static var scaleFactor:Float{
        get {
            #if os(iOS)
                return  Float(UIScreen.mainScreen().scale)
            #else
                let screen = NSScreen.main
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
    
    open weak var filter:IMPFilter? = nil {
        willSet{
            operation.cancelAllOperations()
            filter?.removeObserver(newSource: sourceObserver)
            filter?.removeObserver(destinationUpdated: destinationObserver)
            filter?.removeObserver(dirty: dirtyObserver)
        }
        didSet {         
            device = filter?.context.device 
            filter?.addObserver(newSource: sourceObserver)            
            filter?.addObserver(destinationUpdated: destinationObserver)            
            filter?.addObserver(dirty: dirtyObserver)
            needProcessing = true            
        }
    }        

    private lazy var sourceObserver:IMPFilter.SourceUpdateHandler = {
        let handler:IMPFilter.SourceUpdateHandler = { (source) in
            if source == nil { 
                self.operation.cancelAllOperations()
                self.needProcessing = true
            }
        }
        return handler
    }()
    
    private var currentDestination:IMPImageProvider?
    private lazy var destinationObserver:IMPFilter.UpdateHandler = {
        let handler:IMPFilter.UpdateHandler = { (destination) in
            self.currentDestination = destination
            DispatchQueue.main.async {
                self.updateDrawble(size: destination.size)
            }
        }
        return handler
    }()
    
    private lazy var dirtyObserver:IMPFilter.FilterHandler = {
        let handler:IMPFilter.FilterHandler = { (filter, source, destintion) in
            //if !self.needProcessing{
                self.needProcessing = true
           // }
        } 
        return handler
    }()
    
    
    private func updateDrawble(size: NSSize?, need processing:Bool = true)  {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let size = size {
            
            if exactResolutionEnabled || self.bounds.size == NSZeroSize {
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
           
            viewUpdateDrawbleHandler?(size)
        }
        else if filter?.source == nil {
            let newSize = NSSize(width: self.bounds.size.width * screenScale,
                                 height: self.bounds.size.height * screenScale)

            drawableSize = NSSize(width: newSize.width, height: newSize.height)

            viewUpdateDrawbleHandler?(newSize)
        }
        CATransaction.commit()
    }
            
    public init(frame frameRect: CGRect) {
        super.init(frame: frameRect, device: nil)
        defer {
            _init_()            
        }
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        guard device != nil else {
            fatalError("The system does not support any MTL devices...")
        }
        defer {
            _init_()
        }
    }
    
    public var context:IMPContext? {
        return filter?.context
    }
    
    var needProcessing = true {
        didSet{
            if needProcessing {
                if isPaused{
                    processing(size: drawableSize)
                }
                else {
                    operation.cancelAllOperations()                    
                }
            }
        }
    }
    
    var frameCounter = 0
    
    var frameImage:IMPImageProvider? // = IMPImage(context: self.context)
    
    private let __operation:OperationQueue = {
        let o = OperationQueue()
        o.qualityOfService = .utility
        o.maxConcurrentOperationCount = 1
        o.name = "com.improcessing.IMPView"
        return o
    }()
    
    public var operation:OperationQueue { return  self.__operation }
    
    func processing(size: NSSize)  {
        operation.cancelAllOperations()
        operation.addOperation {

            self.needProcessing = false

            guard let filter = self.filter else { return }
            
            filter.destinationSize = size
            self.frameImage = filter.destination
                        
            self.needUpdateDisplay = true

//            DispatchQueue.main.async {
//                self.setNeedsDisplay()                
//            }
        }
    }

    lazy var viewPort:MTLViewport = MTLViewport(originX: 0, originY: 0, width: Double(self.drawableSize.width), height: Double(self.drawableSize.height), znear: 0, zfar: 1)
    
    open override var drawableSize: CGSize {
        didSet{
            viewPort = MTLViewport(originX: 0, originY: 0, width: Double(self.drawableSize.width), height: Double(self.drawableSize.height), znear: 0, zfar: 1)
        }
    }
    
    func refresh(rect: CGRect){

        guard let context = self.context else { return }
        
        context.wait()

        guard 
            let commandBuffer = context.commandBuffer,
            let sourceTexture = frameImage?.texture,
            let targetTexture = currentDrawable?.texture else {
                context.resume()
                return                 
        }
                                   
        commandBuffer.addCompletedHandler{ (commandBuffer) in
            if self.isFirstFrame  {
                self.frameCounter += 1
            }
            context.resume()
            self.viewBufferCompleteHandler?(self.frameImage!)
        }        
        
        if renderingEnabled == false &&
            sourceTexture.cgsize == drawableSize  &&
            sourceTexture.pixelFormat == targetTexture.pixelFormat{
            guard let encoder = commandBuffer.makeBlitCommandEncoder() else {return }
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
            
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            
            if let pipeline = renderPipeline {
                
                encoder.setRenderPipelineState(pipeline)
                
                encoder.setVertexBuffer(vertexBuffer, offset:0, index:0)
                encoder.setFragmentTexture(sourceTexture, index:0)
                encoder.setViewport(viewPort)
                
                encoder.drawPrimitives(type: .triangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
                encoder.endEncoding()
            }
        }
                
        commandBuffer.present(currentDrawable!)        
        commandBuffer.commit()
        
        //
        // https://forums.developer.apple.com/thread/64889
        //        
        //DispatchQueue.main.sync {
        // self.draw()
        //}
        
        if self.frameCounter > 0  && self.isFirstFrame {
            self.isFirstFrame = false
            if self.viewReadyHandler !=  nil {
                self.viewReadyHandler!()
            }
        }
    }

    fileprivate let processingLink:IMPDisplayLink = IMPDisplayLink()    
    fileprivate var needUpdateDisplay:Bool = false 
    
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
        clearColor = MTLClearColorMake(1, 1, 1, 0)
        framebufferOnly = false
        autoResizeDrawable = false
        #if os(iOS)
            contentMode = .scaleAspectFit
        #elseif os(OSX)
            postsFrameChangedNotifications = true
        #endif
        enableSetNeedsDisplay = false
        colorPixelFormat = .bgra8Unorm
        delegate = self
        processingLink.addObserver { (timev) in
            //let go = self.needProcessing
            //self.needProcessing = false
            if self.needProcessing {
                //self.context?.runOperation(.async){
                self.processing(size: self.drawableSize)
                //}            
            }
        }
        isPaused = false   
        configure()
    }
    
    open override var isPaused: Bool {
        didSet{
            processingLink.isPaused = isPaused
        }
    }
    
    open override var preferredFramesPerSecond: Int {
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
    
    lazy var vertexBuffer:MTLBuffer? = {
        let v = self.context?.device.makeBuffer(bytes: IMPView.viewVertexData, length: MemoryLayout<Float>.size*IMPView.viewVertexData.count, options: [])
        v?.label = "Vertices"
        return v
    }()
    
    lazy var fragmentfunction:MTLFunction? = self.context?.defaultLibrary.makeFunction(name: "fragment_passview")
    
    lazy var renderPipeline:MTLRenderPipelineState? = {
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            
            descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat
            
            guard let vertex = self.context?.defaultLibrary.makeFunction(name: "vertex_passview") else {
                fatalError("IMPView error: vertex function 'vertex_passview' is not found in: \(self.context?.defaultLibrary.functionNames)")
            }
            
            guard let fragment = self.context?.defaultLibrary.makeFunction(name: "fragment_passview") else {
                fatalError("IMPView error: vertex function 'fragment_passview' is not found in: \(self.context?.defaultLibrary.functionNames)")
            }
            
            descriptor.vertexFunction   = vertex
            descriptor.fragmentFunction = fragment
            
            return try self.context?.device.makeRenderPipelineState(descriptor: descriptor)
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

    open override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        
        let sourceDragMask = sender.draggingSourceOperationMask()
        let pboard = sender.draggingPasteboard()
        
        let draggedType = NSPasteboard.PasteboardType(kUTTypeURL as String)
        
        if pboard.availableType(from: [draggedType]) == draggedType {
            if sourceDragMask.rawValue & NSDragOperation.generic.rawValue != 0 {
                return NSDragOperation.generic
            }
        }
        
        return []
    }
    
    public var dragOperation:IMPDragOperationHandler?
    
    open override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let draggedType = NSPasteboard.PasteboardType(kUTTypeURL as String)
        if let files  = sender.draggingPasteboard().propertyList(forType: draggedType) {
            if let o = dragOperation {
                return o(files as! [String])
            }
        }
        return false
    }
    
    lazy var trackingArea:NSTrackingArea? = nil
    
    override open func updateTrackingAreas() {
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
    
    override open func mouseEntered(with event:NSEvent) {        
        lounchMouseObservers(event: event)
        super.mouseEntered(with:event)
    }
    
    override open func mouseExited(with event:NSEvent) {
        lounchMouseObservers(event: event)
        super.mouseExited(with:event)
    }
    
    override open func mouseMoved(with event:NSEvent) {
        lounchMouseObservers(event: event)
        super.mouseMoved(with:event)
    }
    
    override open func mouseDown(with event:NSEvent) {
        lounchMouseObservers(event: event)
        super.mouseDown(with:event)
    }
    
    override open func mouseUp(with event:NSEvent) {
        lounchMouseObservers(event: event)
        super.mouseUp(with:event)
    }
    
    override open func mouseDragged(with event: NSEvent) {
        lounchMouseObservers(event: event)
        super.mouseDragged(with:event)

    }
    
    var mouseEventHandlers = [IMPObserverHash<MouseEventHandler>]()
    
    var mouseEventEnabled = false
    public func addMouseEventObserver(observer:@escaping MouseEventHandler){
        let key = IMPObserverHash<MouseEventHandler>.observerKey(observer)
        if let index = mouseEventHandlers.index(where: { return $0.key == key }) {
            mouseEventHandlers.remove(at: index)
        }    
        mouseEventHandlers.append(IMPObserverHash<MouseEventHandler>(key:key,observer: observer))
        mouseEventEnabled = true
    }
    
    public func removeObserver(observer:@escaping MouseEventHandler) {
        let key = IMPObserverHash<MouseEventHandler>.observerKey(observer)
        if let index = mouseEventHandlers.index(where: { return $0.key == key }) {
            mouseEventHandlers.remove(at: index)
        }    
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
        for hash in mouseEventHandlers {
            hash.observer(event, point, self)
        }
    }
    
    #endif
    
    //fileprivate var lastUpdatesTimes = 1
    //fileprivate var lastUpdatesTimesCounter = 0
}


extension IMPView: MTKViewDelegate {
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        
        guard let impview = (view as? IMPView) else { return }
        
        if !impview.needUpdateDisplay {
            return
        }
        
        //if impview.lastUpdatesTimesCounter > impview.lastUpdatesTimes {
        //    impview.lastUpdatesTimesCounter = 0
            impview.needUpdateDisplay = false
       // }
        
        //impview.lastUpdatesTimesCounter += 1
        
        impview.refresh(rect: view.bounds)
    }
}

