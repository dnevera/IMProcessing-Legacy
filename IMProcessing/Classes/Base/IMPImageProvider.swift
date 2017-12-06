//
//  IMPImageProvider.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
        
    public typealias IMPImageOrientation = UIImageOrientation
    
#else
    import Cocoa
    
    public enum IMPImageOrientation : Int {
        case up             // 0,  default orientation
        case down           // 1, -> Up    (0), UIImage, 180 deg rotation
        case left           // 2, -> Right (3), UIImage, 90 deg CCW
        case right          // 3, -> Down  (1), UIImage, 90 deg CW
        case upMirrored     // 4, -> Right (3), UIImage, as above but image mirrored along other axis. horizontal flip
        case downMirrored   // 5, -> Right (3), UIImage, horizontal flip
        case leftMirrored   // 6, -> Right (3), UIImage, vertical flip
        case rightMirrored  // 7, -> Right (3), UIImage, vertical flip
    }

    public typealias UIImageOrientation = IMPImageOrientation

#endif
import Metal

public extension IMPImageOrientation {
    //
    // Exif codes, F is example
    //
    // 1        2       3      4         5            6           7          8
    //
    // 888888  888888      88  88      8888888888  88                  88  8888888888
    // 88          88      88  88      88  88      88  88          88  88      88  88
    // 8888      8888    8888  8888    88          8888888888  8888888888          88
    // 88          88      88  88
    // 88          88  888888  888888

    //                                  EXIF orientation
    //    case Up             // 0, < - (1), default orientation
    //    case Down           // 1, < - (3), UIImage, 180 deg rotation
    //    case Left           // 2, < - (8), UIImage, 90 deg CCW
    //    case Right          // 3, < - (6), UIImage, 90 deg CW
    //    case UpMirrored     // 4, < - (2), UIImage, as above but image mirrored along other axis. horizontal flip
    //    case DownMirrored   // 5, < - (4), UIImage, horizontal flip
    //    case LeftMirrored   // 6, < - (5), UIImage, vertical flip
    //    case RightMirrored  // 7, < - (7), UIImage, vertical flip
    
    init?(exifValue: IMPImageOrientation.RawValue) {
        switch exifValue {
        case 1:
            self.init(rawValue: IMPImageOrientation.up.rawValue)            // IMPExifOrientationUp
        case 2:
            self.init(rawValue: IMPImageOrientation.upMirrored.rawValue)    // IMPExifOrientationHorizontalFlipped
        case 3:
            self.init(rawValue: IMPImageOrientation.down.rawValue)          // IMPExifOrientationLeft180
        case 4:
            self.init(rawValue: IMPImageOrientation.downMirrored.rawValue)  // IMPExifOrientationVerticalFlipped
        case 5:
            self.init(rawValue: IMPImageOrientation.leftMirrored.rawValue)  // IMPExifOrientationLeft90VertcalFlipped
        case 6:
            self.init(rawValue: IMPImageOrientation.right.rawValue)         // IMPExifOrientationLeft90
        case 7:
            self.init(rawValue: IMPImageOrientation.rightMirrored.rawValue) // IMPExifOrientationLeft90HorizontalFlipped
        case 8:
            self.init(rawValue: IMPImageOrientation.left.rawValue)          // IMPExifOrientationRight90
        default:
            self.init(rawValue: IMPImageOrientation.up.rawValue)
        }
    }
}

public extension IMPExifOrientation {
    init?(imageOrientationValue: IMPImageOrientation) {
        switch imageOrientationValue {
        case .up:
            self.init(rawValue: IMPExifOrientationUp.rawValue)
        case .upMirrored:
            self.init(rawValue: IMPExifOrientationHorizontalFlipped.rawValue)
        case .down:
            self.init(rawValue: IMPExifOrientationLeft180.rawValue)
        case .downMirrored:
            self.init(rawValue: IMPExifOrientationVerticalFlipped.rawValue)
        case .leftMirrored:
            self.init(rawValue: IMPExifOrientationLeft90VertcalFlipped.rawValue)
        case .right:
            self.init(rawValue: IMPExifOrientationLeft90.rawValue)
        case .rightMirrored:
            self.init(rawValue: IMPExifOrientationLeft90HorizontalFlipped.rawValue)
        case .left:
            self.init(rawValue: IMPExifOrientationRight90.rawValue)
        default:
            self.init(rawValue: IMPExifOrientationUp.rawValue)
        }
    }
}

open class IMPImageProvider: IMPTextureProvider,IMPContextProvider {

    open var orientation = IMPImageOrientation.up
    
    open var context:IMPContext!
    open var texture:MTLTexture?
    
    open var width:Float {
        get {
            guard texture != nil else { return 0 }
            return texture!.width.float
        }
    }
   
    open var height:Float {
        get {
            guard texture != nil else { return 0 }
            return texture!.height.float
        }
    }
    
    open lazy var videoCache:IMPVideoTextureCache = {
        return IMPVideoTextureCache(context: self.context)
    }()
    
    public required init(context: IMPContext) {
        self.context = context
    }

    public required init(context: IMPContext, orientation:IMPImageOrientation) {
        self.context = context
        self.orientation = orientation
    }

    public convenience init(context: IMPContext, texture:MTLTexture, orientation:IMPImageOrientation = .up){
        self.init(context: context)
        self.texture = texture
        self.orientation = orientation
    }
    
    open weak var filter:IMPFilter?
    
    open func completeUpdate(){
        filter?.executeNewSourceObservers(self)
        filter?.dirty = true
    }
    
    open func rotate(degrees:float3){
        
        if degrees == float3(0) {
            return
        }
        
        if let source = copyTexture() {
            
            var w = source.width
            var h = source.height
            
            if fabs(fabs(degrees.z) - M_PI_2.float) < FLT_EPSILON
                ||
                fabs(fabs(degrees.z) - 3 * M_PI_2.float) < FLT_EPSILON
            {
                w = h
                h = source.width
            }
            
            transformation(source, width: w, height: h,
                           angle: degrees,
                           reflectMode: (horizontal: .none, vertical: .none)
            )
        }
    }
    
    open func rotateLeft() {
        rotate(degrees: IMPTransfromModel.left)
    }

    open func rotateRight() {
        rotate(degrees: IMPTransfromModel.right)
    }

    open func rotate180() {
        rotate(degrees: IMPTransfromModel.degrees180)
    }

    open func reflectHorizontal() {
        if let source = copyTexture() {
            transformation(source, width: source.width, height: source.height,
                           angle: IMPTransfromModel.flat,
                           reflectMode: (horizontal: .mirroring, vertical: .none)
            )
        }
    }

    open func reflectVertical() {
        if let source = copyTexture() {
            transformation(source, width: source.width, height: source.height,
                           angle: IMPTransfromModel.flat,
                           reflectMode: (horizontal: .none, vertical: .mirroring)
            )
        }
    }

    open var scale:Float = 1 {
        didSet{
            if let source = copyTexture() {
                
                guard let pipeline = graphics.pipeline else {return}
                
                newTexture(source, width: Int(source.width.float*scale), height: Int(source.height.float*scale))
                
                guard let newTexure = texture else {return}
                
                context.execute(complete: true) { (commandBuffer) in
                    self.transformer.render(commandBuffer, pipelineState: pipeline, source: source, destination: newTexure)
                }
                
                completeUpdate()
            }
        }
    }
    
    func transformation(_ source:MTLTexture, width:Int, height:Int, angle:float3, reflectMode: (horizontal:IMPRenderNode.ReflectMode, vertical:IMPRenderNode.ReflectMode)) {

        guard let pipeline = graphics.pipeline else {return}

        newTexture(source, width: width, height: height)
        
        transformer.angle = angle
        transformer.reflectMode = reflectMode
        
        guard let newTexure = texture else {return}
        
        context.execute(complete: true) { (commandBuffer) in
            self.transformer.render(commandBuffer, pipelineState: pipeline, source: source, destination: newTexure)
        }
        
        completeUpdate()
    }
    
    func newTexture(_ source:MTLTexture, width:Int, height:Int){
        
        if texture != nil {
            texture?.setPurgeableState(.volatile)
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: source.pixelFormat,
            width: width, height: height,
            mipmapped: false)
        
        texture = self.context.device.makeTexture(descriptor: descriptor)
    }
    
    deinit {
        if texture != nil {
            texture?.setPurgeableState(.volatile)
        }
        texture = nil
        videoCache.flush()
    }
    
    func copyTexture() -> MTLTexture? {
        
        var source:MTLTexture? = nil
        
        if let texture = self.texture {
            
            context.execute(complete: true) { (commandBuffer) in
                
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
                
                
                let w = texture.width
                let h = texture.height
                let d = texture.depth
                
                let originSource = MTLOrigin(x: 0, y: 0, z: 0)
                
                let destinationSize = MTLSize(width:  w, height: h, depth: d)
                
                
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: texture.pixelFormat,
                    width: destinationSize.width, height: destinationSize.height,
                    mipmapped: false)
                
                source = self.context.device.makeTexture(descriptor: descriptor)
                
                
                #if os(OSX)
                    blitEncoder.synchronize(resource: texture)
                #endif

                blitEncoder.copy(
                    from: texture,
                    sourceSlice:      0,
                    sourceLevel:      0,
                    sourceOrigin:     originSource,
                    sourceSize:       destinationSize,
                    to:        source!,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: MTLOrigin(x:0,y:0,z:0))
                
                #if os(OSX)
                    blitEncoder.synchronize(resource: source!)
                #endif

                blitEncoder.endEncoding()
                
            }
        }
        
        return source
    }
    
    internal func transform(_ source:MTLTexture, orientation:IMPExifOrientation) -> MTLTexture? {
        
        guard let pipeline = graphics.pipeline else {return nil}
        
        var width  = source.width
        var height = source.height
        
        
        func swapSize() {
            width  = source.height
            height = source.width
        }
        
        switch orientation {
            
        case IMPExifOrientationHorizontalFlipped:
            transformer.reflectMode = (horizontal:.mirroring, vertical:.none)
            
        case IMPExifOrientationLeft180:
            transformer.angle = IMPTransfromModel.degrees180
            
        case IMPExifOrientationVerticalFlipped:
            transformer.reflectMode = (horizontal:.none, vertical:.mirroring)
            
        case IMPExifOrientationLeft90VertcalFlipped:
            swapSize()
            transformer.angle = IMPTransfromModel.left
            transformer.reflectMode = (horizontal:.mirroring, vertical:.none)
            
        case IMPExifOrientationLeft90:
            swapSize()
            transformer.angle = IMPTransfromModel.right
            
        case IMPExifOrientationLeft90HorizontalFlipped:
            swapSize()
            transformer.angle = IMPTransfromModel.right
            transformer.reflectMode = (horizontal:.mirroring, vertical:.none)
            
        case IMPExifOrientationRight90:
            swapSize()
            transformer.angle = IMPTransfromModel.left
            
        default:
            return source
        }
        
        
        if width != texture?.width || height != texture?.height{
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: source.pixelFormat,
                width: width, height: height,
                mipmapped: false)
            
            if texture != nil {
                texture?.setPurgeableState(.volatile)
            }
            
            texture = self.context.device.makeTexture(descriptor: descriptor)
        }
        
        guard let destination = texture else { return nil}
        
        context.execute(complete: true) { (commandBuffer) in
            self.transformer.render(commandBuffer, pipelineState: pipeline, source: source, destination: destination)
        }
        
        return texture
    }
    
    internal func transform(_ source:MTLTexture, orientation:IMPImageOrientation) -> MTLTexture? {
        
        guard let pipeline = graphics.pipeline else {return nil}
        
        var width  = source.width
        var height = source.height
        
        
        func swapSize() {
            width  = source.height
            height = source.width
        }
        
        switch orientation {
            
        case .upMirrored:
            transformer.reflectMode = (horizontal:.none, vertical:.mirroring)
            
        case .down:
            transformer.angle = IMPTransfromModel.degrees180

        case .downMirrored:
            transformer.angle = IMPTransfromModel.degrees180
            transformer.reflectMode = (horizontal:.mirroring, vertical:.none)

        case .left:
            transformer.angle = IMPTransfromModel.left

        case .leftMirrored:
            transformer.angle = IMPTransfromModel.left
            transformer.reflectMode = (horizontal:.none, vertical:.mirroring)

        case .right:
            transformer.angle = IMPTransfromModel.right

        case .rightMirrored:
            transformer.angle = IMPTransfromModel.right
            transformer.reflectMode = (horizontal:.none, vertical:.mirroring)
            
        default:
            return source
        }
        
        
        if width != texture?.width || height != texture?.height{
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: source.pixelFormat,
                width: width, height: height,
                mipmapped: false)
            
            if texture != nil {
                texture?.setPurgeableState(.volatile)
            }
            
            texture = self.context.device.makeTexture(descriptor: descriptor)
        }
        
        guard let destination = texture else { return nil}
        
        context.execute(complete: true) { (commandBuffer) in
            self.transformer.render(commandBuffer, pipelineState: pipeline, source: source, destination: destination)
        }
        
        return texture

    }
    
    internal lazy var graphics:IMPGraphics = {
        return IMPGraphics(context:self.context, vertex: "vertex_transformation", fragment: "fragment_transformation")
    }()
    
    internal lazy var transformer:Transfromer = {
        return Transfromer(context: self.context, aspectRatio:1)
    }()
    
    
    // Plate is a cube with virtual depth == 0
    internal class Transfromer: IMPPhotoPlateNode {}
}
