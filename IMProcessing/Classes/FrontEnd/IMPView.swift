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
                        let scale = fmin(fmin(newSize.width/size.width, newSize.height/size.height),1)
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
    
    lazy var frameImage:IMPImage = IMPImage(context: self.context)
    
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
                
                filter.apply(view.frameImage, with: self.size)
                
                view.needProcessing = false
                view.setNeedsDisplay()
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
                encoder.setFragmentTexture(sourceTexture, at:0)
                
                encoder.drawPrimitives(type: .triangleStrip, vertexStart:0, vertexCount:4, instanceCount:1)
                encoder.endEncoding()
            }
        }
        
        commandBuffer.present(drawable)
        
        commandBuffer.addCompletedHandler{ (commandBuffer) in
            self.context.resume()
        }
        
        commandBuffer.commit()
        
        if frameCounter > 0  && isFirstFrame {
            isFirstFrame = false
            if viewReadyHandler !=  nil {
                viewReadyHandler!()
            }
        }
    }
    
    @objc fileprivate func procesingLinkHandler() {
        context.runOperation(.async){
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
        #endif
        enableSetNeedsDisplay = false
        isPaused = false
        colorPixelFormat = .bgra8Unorm
        delegate = self
        #if os(iOS)
            processingLink.add(to: .current, forMode: .commonModes)
        #else
            processingLink.addView(view: self)
            processingLink.isPaused = false
        #endif
    }
    
    public override var preferredFramesPerSecond: Int {
        didSet{
            #if os(iOS)
            processingLink.preferredFramesPerSecond = preferredFramesPerSecond
            #endif
        }
    }
    
    private var isFirstFrame = true
    
    #if os(iOS)
    private lazy var processingLink:CADisplayLink = CADisplayLink(target: self, selector: #selector(procesingLinkHandler))
    #else
    private lazy var processingLink:IMPDisplayLink = IMPDisplayLink()
    #endif
    
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
        
        guard needUpdateDisplay else { return }
        needUpdateDisplay = false
        
        context.runOperation(.async) { [unowned self] in
            self.refresh(rect: view.bounds)
            //
            // https://forums.developer.apple.com/thread/64889
            //
            self.draw()
        }
    }
}


#if os(OSX)
    
    //
    // 
    // http://stackoverflow.com/questions/25981553/cvdisplaylink-with-swift
    //
    //
    private class IMPDisplayLink {
        
        static let sharedInstance = IMPDisplayLink()
        
        private lazy var displayLink:CVDisplayLink? = {
            var link:CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            return link
        } ()
        
        var isPaused:Bool = false {
            didSet(oldValue){
                guard let link = displayLink else { return }
                if  isPaused {
                    if CVDisplayLinkIsRunning(link) {
                        CVDisplayLinkStop(link)
                    }
                }
                else{
                    if !CVDisplayLinkIsRunning(link) {
                        CVDisplayLinkStart(link)
                    }
                }
            }
        }
        
        private var viewList = [IMPView]()
        
        func addView(view:IMPView){
            if viewList.contains(view) == false {
                viewList.append(view)
            }
        }
        
        func removeView(view:IMPView){
            if let index = viewList.index(of: view) {
                viewList.remove(at: index)
            }
        }
        
        required init(){
            guard let link = displayLink else { return }
            CVDisplayLinkSetOutputCallback(link, displayLinkOutputCallback, nil)
        }
        
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = {
            (displayLink: CVDisplayLink,
            inNow: UnsafePointer<CVTimeStamp>,
            inOutputTime: UnsafePointer<CVTimeStamp>,
            flagsIn: CVOptionFlags,
            flagsOut: UnsafeMutablePointer<CVOptionFlags>,
            displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
            
            /*  It's prudent to also have a brief discussion about the CVTimeStamp.
             CVTimeStamp has five properties.  Three of the five are very useful
             for keeping track of the current time, calculating delta time, the
             frame number, and the number of frames per second.  The utility of
             each property is not terribly obvious from just reading the names
             or the descriptions in the Developer dcumentation and has been a
             mystery to many a developer.  Thankfully, CaptainRedmuff on
             StackOverflow asked a question that provided the equation that
             calculates frames per second.  From that equation, we can
             extrapolate the value of each field.
             
             @hostTime = current time in Units of the "root".  Yeah, I don't know.
             The key to this field is to understand that it is in nanoseconds
             (e.g. 1/1_000_000_000 of a second) not units.  To convert it to
             seconds divide by 1_000_000_000.  Dividing by videoRefreshPeriod
             and videoTimeScale in a calculation for frames per second yields
             the appropriate number of frames.  This works as a result of
             proportionality--dividing seconds by seconds.  Note that dividing
             by videoTimeScale to get the time in seconds does not work like it
             does for videoTime.
             
             framesPerSecond:
             (videoTime / videoRefreshPeriod) / (videoTime / videoTimeScale) = 59
             and
             (hostTime / videoRefreshPeriod) / (hostTime / videoTimeScale) = 59
             but
             hostTime * videoTimeScale ≠ seconds, but Units = seconds * (Units / seconds) = Units
             
             @rateScalar = ratio of "rate of device in CVTimeStamp/unitOfTime" to
             the "Nominal Rate".  I think the "Nominal Rate" is
             videoRefreshPeriod, but unfortunately, the documentation doesn't
             just say videoRefreshPeriod is the Nominal rate and then define
             what that means.  Regardless, because this is a ratio, and the fact
             that we know the value of one of the parts (e.g. Units/frame), we
             then know that the "rate of the device" is frame/Units (the units of
             measure need to cancel out for the ratio to be a ratio).  This
             makes sense in that rateScalar's definition tells us the rate is
             "measured by timeStamps".  Since there is a frame for every
             timeStamp, the rate of the device equals CVTimeStamp/Unit or
             frame/Unit.  Thus,
             
             rateScalar = frame/Units : Units/frame
             
             @videoTime = the time the frame was created since computer started up.
             If you turn your computer off and then turn it back on, this timer
             returns to zero.  The timer is paused when you put your computer to
             sleep.  This value is in Units not seconds.  To get the number of
             seconds this value represents, you have to apply videoTimeScale.
             
             @videoRefreshPeriod = the number of Units per frame (i.e. Units/frame)
             This is useful in calculating the frame number or frames per second.
             The documentation calls this the "nominal update period" and I am
             pretty sure that is quivalent to the aforementioned "nominal rate".
             Unfortunately, the documetation mixes naming conventions and this
             inconsistency creates confusion.
             
             frame = videoTime / videoRefreshPeriod
             
             @videoTimeScale = Units/second, used to convert videoTime into seconds
             and may also be used with videoRefreshPeriod to calculate the expected
             framesPerSecond.  I say expected, because videoTimeScale and
             videoRefreshPeriod don't change while videoTime does change.  Thus,
             to calculate fps in the case of system slow down, one would need to
             use videoTime with videoTimeScale to calculate the actual fps value.
             
             seconds = videoTime / videoTimeScale
             
             framesPerSecondConstant = videoTimeScale / videoRefreshPeriod (this value does not change if their is system slowdown)
             
             USE CASE 1: Time in DD:HH:mm:ss using hostTime
             let rootTotalSeconds = inNow.pointee.hostTime
             let rootDays = inNow.pointee.hostTime / (1_000_000_000 * 60 * 60 * 24) % 365
             let rootHours = inNow.pointee.hostTime / (1_000_000_000 * 60 * 60) % 24
             let rootMinutes = inNow.pointee.hostTime / (1_000_000_000 * 60) % 60
             let rootSeconds = inNow.pointee.hostTime / 1_000_000_000 % 60
             Swift.print("rootTotalSeconds: \(rootTotalSeconds) rootDays: \(rootDays) rootHours: \(rootHours) rootMinutes: \(rootMinutes) rootSeconds: \(rootSeconds)")
             
             USE CASE 2: Time in DD:HH:mm:ss using videoTime
             let totalSeconds = inNow.pointee.videoTime / Int64(inNow.pointee.videoTimeScale)
             let days = (totalSeconds / (60 * 60 * 24)) % 365
             let hours = (totalSeconds / (60 * 60)) % 24
             let minutes = (totalSeconds / 60) % 60
             let seconds = totalSeconds % 60
             Swift.print("totalSeconds: \(totalSeconds) Days: \(days) Hours: \(hours) Minutes: \(minutes) Seconds: \(seconds)")
             
             Swift.print("fps: \(Double(inNow.pointee.videoTimeScale) / Double(inNow.pointee.videoRefreshPeriod)) seconds: \(Double(inNow.pointee.videoTime) / Double(inNow.pointee.videoTimeScale))")
             */
            
            /*  The displayLinkContext in CVDisplayLinkOutputCallback's parameter list is the
             view being driven by the CVDisplayLink.  In order to use the context as an
             instance of SwiftOpenGLView (which has our drawView() method) we need to use
             unsafeBitCast() to cast this context to a SwiftOpenGLView.
             */
            

            NSLog(" ---- \(inNow)")
            
            //  We are going to assume that everything went well, and success as the CVReturn
            return kCVReturnSuccess
        }

        
        deinit{
            self.isPaused = true
        }
        
    }
#endif

