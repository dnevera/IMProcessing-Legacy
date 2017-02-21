//
//  IMPContext.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
    import OpenGL.GL
#endif

import Metal

///
///  @brief Context provider protocol.
///  All filter classes should conform to the protocol to get access current filter context.
///
public protocol IMPContextProvider{
    var context:IMPContext {get}
}

extension String{
    static func uniqString() -> String{
        return CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
    }
}


///
/// The IMProcessing framework supports GPU-accelerated advanced data-parallel computation workloads.
/// IMPContext instance is created to connect curren GPU device and resources are allocated in order to
/// do computation.
///
/// IMPContext is a container bring together GPU-device, current command queue and default kernel functions library
/// which export functions to the context.
///
open class IMPContext {
    
    /// Context execution closure
    public typealias Execution = ((_ commandBuffer:MTLCommandBuffer) -> Void)
    
    /// Current device is used in the current context
    open var device:MTLDevice {
        return _device!
    }
    
    open var coreImage:CIContext? {
        if #available(iOS 9.0, *) {
            return _ciContext
        } else {
            return nil
        }
    }
    
    open let uid = String.uniqString()
    
    /// Current command queue uses the current device
    open let commandQueue:MTLCommandQueue?
    
    /// Default library associated with current context
    open let defaultLibrary:MTLLibrary
    
    
    /// How context execution is processed
    open let isLazy:Bool
    
    /// check whether the MTL device is supported
    open static var supportsSystemDevice:Bool{
        get{
            let device = MTLCreateSystemDefaultDevice()
            if device == nil {
                return false
            }
            return true
        }
    }
    
    open func makeLibrary(source:String) throws -> MTLLibrary {
        let options = MTLCompileOptions()
        options.fastMathEnabled = true
        return try device.makeLibrary(source: source, options: options)
    }
    
    fileprivate let semaphore = DispatchSemaphore(value: 3)
    
    open func wait() {
        semaphore.wait()
    }
    open func resume(){
        semaphore.signal()
    }
    
    open var dispatchQueue = DispatchQueue(label: "com.improcessing.context")
    
    ///  Initialize current context
    ///
    ///  - parameter lazy: true if you need to process without waiting finishing computation in the context.
    ///
    ///  - returns: context instanc
    ///
    required public init(device: MTLDevice? = nil,  lazy:Bool = false) {
        if device != nil {
            self._device = device
        }
        else {
            _device = MTLCreateSystemDefaultDevice()
        }
        
        if self._device == nil {
            fatalError("The system does not support any MTL devices...")
        }
        
        isLazy = lazy
        
        if let commandQ = _device?.makeCommandQueue() {
            commandQueue = commandQ
        }
        else {
            fatalError("Default Metal command queue could not be created...")
        }
        #if DEBUG
            commandQueue?.insertDebugCaptureBoundary()
        #endif
        
        if let library = _device?.newDefaultLibrary(){
            defaultLibrary = library
        }
        else{
            fatalError("Default Metal library could not be found...")
        }
    }
    
    var _device:MTLDevice?
    
    @available(iOS 9.0, *)
    lazy var _ciContext:CIContext = CIContext(mtlDevice: self.device)
    
    open lazy var supportsGPUv2:Bool = {
        #if os(iOS)
            return self.device.supportsFeatureSet(.iOS_GPUFamily2_v1)
        #else
            return true
        #endif
    }()
    
    var commandBuffer:MTLCommandBuffer?  {
        return self.commandQueue?.makeCommandBuffer() 
    }
    
    ///  The main idea context execution: all filters should put commands in context queue within the one execution.
    ///
    ///  - parameter closure: execution context
    ///
    public final func async_execute(wait:     Bool = false,
                                    complete: Execution? = nil,
                                    fail:     (() -> Void)? = nil,
                                    action:   @escaping Execution) {
        
        dispatchQueue.async(group: nil, qos: .background, flags: .noQoS) {
            
            if let commandBuffer = self.commandBuffer {
                
                action(commandBuffer)
                
                commandBuffer.commit()
                
                if !self.isLazy || wait {
                    commandBuffer.waitUntilCompleted()
                }
                complete?(commandBuffer)
            }
            else {
                fail?()
            }
        }
    }
    
    public final func execute(wait:    Bool = false,
                              fail:    (()->Void)? = nil,
                              action:  @escaping Execution) {
        
        if let commandBuffer = self.commandBuffer {
            
            action(commandBuffer)
            
            commandBuffer.commit()
            
            if !self.isLazy || wait {
                commandBuffer.waitUntilCompleted()
            }
        }
        else {
            fail?()
        }
    }
    
    
    /// Get the maximum supported devices texture size.
    open static var maximumTextureSize:Int{
        
        set(newMaximumTextureSize){
            IMPContext.sharedContainer.currentMaximumTextureSize = 0
            var size = IMPContext.sharedContainer.currentMaximumTextureSize
            if newMaximumTextureSize <= size {
                size = newMaximumTextureSize
            }
            IMPContext.sharedContainer.currentMaximumTextureSize = size
        }
        
        get {
            return IMPContext.sharedContainer.currentMaximumTextureSize
        }
    }
    
    ///  Get texture size alligned to maximum size which is suported by the current device
    ///
    ///  - parameter inputSize: real size of texture
    ///  - parameter maxSize:   size of a texture which can be placed to the context
    ///
    ///  - returns: maximum size
    ///
    open static func sizeAdjustTo(size inputSize:CGSize, maxSize:Float = Float(IMPContext.maximumTextureSize)) -> CGSize
    {
        if (inputSize.width < CGFloat(maxSize)) && (inputSize.height < CGFloat(maxSize))  {
            return inputSize
        }
        
        var adjustedSize = inputSize
        
        if inputSize.width > inputSize.height {
            adjustedSize = CGSize(width: CGFloat(maxSize), height: ( CGFloat(maxSize) / inputSize.width) * inputSize.height)
        }
        else{
            adjustedSize = CGSize(width: ( CGFloat(maxSize) / inputSize.height) * inputSize.width, height:CGFloat(maxSize))
        }
        
        return adjustedSize;
    }
    
    // Singleton Class
    fileprivate class sharedContainerType: NSObject {
        
        fileprivate static var maxTextureSize:GLint = 0
        var currentMaximumTextureSize:Int
        
        static let sharedInstance:sharedContainerType = {
            let instance = sharedContainerType ()
            return instance
        } ()
        
        override init() {
            #if os(iOS)
                let glContext =  EAGLContext(api: .openGLES2)
                EAGLContext.setCurrent(glContext)
                glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &sharedContainerType.maxTextureSize)
                currentMaximumTextureSize = Int(sharedContainerType.maxTextureSize)
            #else
                var pixelAttributes:[NSOpenGLPixelFormatAttribute] = [UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated), 0]
                let pixelFormat = NSOpenGLPixelFormat(attributes: &pixelAttributes)
                let context = NSOpenGLContext(format: pixelFormat!, shareContext: nil)
                context?.makeCurrentContext()
                glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &sharedContainerType.maxTextureSize)
                currentMaximumTextureSize = Int(sharedContainerType.maxTextureSize)
            #endif
        }
    }
    
    fileprivate static var sharedContainer = sharedContainerType()
}
