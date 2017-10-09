//
//  IMPImageProvider.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
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

import CoreImage
import simd
import Metal
import AVFoundation
import ImageIO


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
    
    var exifValue:Int {
        return Int(IMPExifOrientation(imageOrientation: self)!.rawValue)
    }
}

public extension IMPExifOrientation {
    init?(imageOrientation: IMPImageOrientation) {
        switch imageOrientation {
        case .up:
            self.init(rawValue: IMPExifOrientation.up.rawValue)
        case .upMirrored:
            self.init(rawValue: IMPExifOrientation.horizontalFlipped.rawValue)
        case .down:
            self.init(rawValue: IMPExifOrientation.left180.rawValue)
        case .downMirrored:
            self.init(rawValue: IMPExifOrientation.verticalFlipped.rawValue)
        case .leftMirrored:
            self.init(rawValue: IMPExifOrientation.left90VertcalFlipped.rawValue)
        case .right:
            self.init(rawValue: IMPExifOrientation.left90.rawValue)
        case .rightMirrored:
            self.init(rawValue: IMPExifOrientation.left90HorizontalFlipped.rawValue)
        case .left:
            self.init(rawValue: IMPExifOrientation.right90.rawValue)
        }
    }
    
    var imageOrientation:IMPImageOrientation {
        return IMPImageOrientation(exifValue: Int(self.rawValue))!
    }
}

public enum IMPImageStorageMode {
    case shared
    case local
}


/// Image provider base protocol
public protocol IMPImageProvider: IMPTextureProvider, IMPContextProvider{    
    var image:CIImage?{ get set }
    var size:NSSize? {get}
    var colorSpace:CGColorSpace {get set}
    var orientation:IMPImageOrientation {get set}
    var videoCache:IMPVideoTextureCache {get}
    var storageMode:IMPImageStorageMode {get}
    init(context:IMPContext, storageMode:IMPImageStorageMode?)
    func addObserver(optionsChanged observer: @escaping ((IMPImageProvider) -> Void))
}

// MARK: - construcutors
public extension IMPImageProvider {
    
    public init(context: IMPContext,
                url: URL,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        #if os(iOS)
            self.init(context:context, storageMode: storageMode)
            self.image = prepareImage(image: CIImage(contentsOf: url, options: [kCIImageColorSpace: colorSpace]),
                                      maxSize: maxSize, orientation: orientation)
        #elseif os(OSX)
            let image = NSImage(byReferencing: url)
            self.init(context: context,
                      image: image,
                      storageMode:storageMode,
                      maxSize:maxSize,
                      orientation:orientation)
        #endif
    }
    
    public init(context: IMPContext,
                path: String,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context: context, url: URL(fileURLWithPath:path),
                  storageMode:storageMode,
                  maxSize:maxSize,
                  orientation:orientation)
    }

    public init(context: IMPContext,
                provider: IMPImageProvider,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: provider.image?.copy() as? CIImage,
                                  maxSize: maxSize, orientation: orientation)
    }

    public init(context: IMPContext,
                image: CIImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: image.copy() as? CIImage,
                                  maxSize: maxSize, orientation: orientation)
    }
    
    
    public init(context: IMPContext,
                image: NSImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        #if os(OSX)
            guard let data = image.tiffRepresentation else {
                return
            }
            let ciimage = CIImage(data: data, options: [kCIImageColorSpace: colorSpace])
            let imageOrientation = IMPImageOrientation.up
        #else
            let ciimage = CIImage(cgImage: image.cgImage!, options: [kCIImageColorSpace: colorSpace])
            let imageOrientation = image.imageOrientation
        #endif
        
        self.image = prepareImage(image: ciimage,
                                  maxSize: maxSize, orientation: orientation ?? imageOrientation)
    }
    
    public init(context: IMPContext,
                image: CGImage,
                storageMode:IMPImageStorageMode? = nil,
                maxSize: CGFloat = 0,
                orientation:IMPImageOrientation? = nil){
        self.init(context:context, storageMode: storageMode)
        self.image = prepareImage(image: CIImage(cgImage: image, options: [kCIImageColorSpace: colorSpace]),
                                  maxSize: maxSize, orientation: orientation)
    }
    
    public init(context: IMPContext, image: CMSampleBuffer, storageMode:IMPImageStorageMode? = .local, maxSize: CGFloat = 0){
        self.init(context:context, storageMode: storageMode)
        self.update(image)
    }
    
    public init(context: IMPContext, image: CVImageBuffer, storageMode:IMPImageStorageMode? = .local, maxSize: CGFloat = 0){
        self.init(context:context, storageMode: storageMode)
        self.update(image)
    }
    
    public init(context: IMPContext, texture: MTLTexture){
        var mode = IMPImageStorageMode.shared
        if texture.storageMode == .private {
            mode = .local
        }
        self.init(context:context, storageMode:mode)
        self.texture = texture
    }
    
    
    public mutating func update(_ inputImage:CIImage){
        image = inputImage
    }
    
    public mutating func update(_ inputImage:CGImage){
        image = CIImage(cgImage: inputImage)
    }
    
    public mutating func update(_ inputImage:NSImage){
        #if os(OSX)
            guard let data = inputImage.tiffRepresentation else { return }
            image = CIImage(data: data, options: [kCIImageColorSpace: colorSpace])
        #else
            image = CIImage(image: inputImage)
        #endif
    }
    
    public mutating func update(_ buffer:CMSampleBuffer){
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
            update(pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        }
    }
    
    public mutating func update(_ buffer: CVImageBuffer) {
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var textureRef:CVMetalTexture?
        
        guard let vcache = videoCache.videoTextureCache else {
            fatalError("IMPImageProvider error: couldn't create video cache... )")
        }
        
        let error = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              vcache,
                                                              buffer, nil,
                                                              .bgra8Unorm,
                                                              width,
                                                              height,
                                                              0,
                                                              &textureRef)
        
        if error != kCVReturnSuccess {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
        
        if let ref = textureRef,
            let texture = CVMetalTextureGetTexture(ref) {
            self.texture = texture // texture.makeTextureView(pixelFormat: IMProcessing.colors.pixelFormat)
        }
        else {
            fatalError("IMPImageProvider error: couldn't create texture from pixelBuffer: \(error)")
        }
    }
    
    mutating private func prepareImage(image originImage: CIImage?, maxSize: CGFloat, orientation:IMPImageOrientation? = nil)  -> CIImage? {
        
        guard let image = originImage else { return originImage }
        
        let size       = image.extent
        let imagesize  = max(size.width, size.height)
        let scale      = maxSize > 0 ? min(maxSize/imagesize,1) : 1
        
        var transform  = scale == 1 ? CGAffineTransform.identity : CGAffineTransform(scaleX: scale, y: scale)
        
        var reflectHorisontalMode = false
        var reflectVerticalMode = false
        var angle:CGFloat = 0
        
        
        if let orientation = orientation {
            
            self.orientation = orientation
            
            //
            // CIImage render to verticaly mirrored texture
            //
            
            switch orientation {
                
            case .up:
                angle = CGFloat.pi
                reflectHorisontalMode = true // 0
                
            case .upMirrored:
                reflectHorisontalMode = true
                reflectVerticalMode   = true // 4
                
            case .down:
                reflectHorisontalMode = true // 1
                
            case .downMirrored: break        // 5
                
            case .left:
                angle = -CGFloat.pi/2
                reflectHorisontalMode = true // 2
                
            case .leftMirrored:
                angle = -CGFloat.pi/2
                reflectVerticalMode   = true
                reflectHorisontalMode = true // 6
                
            case .right:
                angle = CGFloat.pi/2
                reflectHorisontalMode = true // 3
                
            case .rightMirrored:
                angle = CGFloat.pi/2
                reflectVerticalMode   = true
                reflectHorisontalMode = true // 7
            }
        }
        
        if reflectHorisontalMode {
            transform = transform.scaledBy(x: -1, y: 1).translatedBy(x: size.width, y: 0)
        }
        
        if reflectVerticalMode {
            transform = transform.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: size.height)
        }
        
        //
        // fix orientation
        //
        transform = transform.rotated(by: CGFloat(angle))
        
        return image.transformed(by: transform)
    }
}


public extension IMPImageProvider {
    
    public func read(commandBuffer:MTLCommandBuffer?=nil) ->  (buffer:MTLBuffer,bytesPerRow:Int,imageBytes:Int)? {
        
        if let size = self.size,
            let texture = texture?.pixelFormat != .rgba8Uint ?
                texture?.makeTextureView(pixelFormat: .rgba8Uint) :
            texture
        {

            let width       = Int(size.width)
            let height      = Int(size.height)
            
            let bytesPerRow   = width * 4
            let imageBytes = height * bytesPerRow
            
            let buffer = self.context.device.makeBuffer(length: imageBytes, options: [])

            
            func readblit(commandBuffer:MTLCommandBuffer){
                let blit = commandBuffer.makeBlitCommandEncoder()
                
                blit?.copy(from:          texture,
                          sourceSlice:  0,
                          sourceLevel:  0,
                          sourceOrigin: MTLOrigin(x:0,y:0,z:0),
                          sourceSize:   texture.size,
                          to:           buffer!,
                          destinationOffset: 0,
                          destinationBytesPerRow: bytesPerRow,
                          destinationBytesPerImage: imageBytes)
                
                blit?.endEncoding()
            }
            
            
            if let command = commandBuffer {
                readblit(commandBuffer: command)
            }
            else {
                context.execute(wait: true) { (commandBuffer) in
                    
                    readblit(commandBuffer: commandBuffer)
                    
                    //                let blit = commandBuffer.makeBlitCommandEncoder()
                    //
                    //                blit.copy(from:          texture,
                    //                          sourceSlice:  0,
                    //                          sourceLevel:  0,
                    //                          sourceOrigin: MTLOrigin(x:0,y:0,z:0),
                    //                          sourceSize:   texture.size,
                    //                          to:           buffer,
                    //                          destinationOffset: 0,
                    //                          destinationBytesPerRow: bytesPerRow,
                    //                          destinationBytesPerImage: imageBytes)
                    //                
                    //                blit.endEncoding()
                }
            }
            return (buffer,bytesPerRow,imageBytes) as! (buffer: MTLBuffer, bytesPerRow: Int, imageBytes: Int)
        }
        
        
//        if let size = self.size,
//            let texture = texture?.pixelFormat != .rgba8Uint ?
//                texture?.makeTextureView(pixelFormat: .rgba8Uint) :
//                texture
//        {
//            
//            let width       = Int(size.width)
//            let height      = Int(size.height)
//            
//            bytesPerRow   = width * 4
//            let newSize = height * bytesPerRow
//            
//            if bytes == nil {
//                bytes = UnsafeMutablePointer<UInt8>.allocate(capacity:newSize)
//            }
//            else if imageByteSize != newSize {
//                if imageByteSize > 0 {
//                    bytes?.deallocate(capacity: imageByteSize)
//                }
//                bytes = UnsafeMutablePointer<UInt8>.allocate(capacity:newSize)
//            }
//
//            if bytes == nil {
//                context.resume()
//                return  nil
//            }
//            
//            imageByteSize = newSize
//            
//            #if os(OSX)
//                guard let command = context.commandBuffer else { return nil }
//                let blit = command.makeBlitCommandEncoder()
//                blit.synchronize(resource: texture)
//                blit.endEncoding()
//                command.commit()
//                command.waitUntilCompleted()
//            #endif
//                        
//            texture.getBytes(bytes!,
//                             bytesPerRow: bytesPerRow,
//                             from: MTLRegionMake2D(0, 0, texture.width, texture.height),
//                             mipmapLevel: 0)
//            
//            context.resume()
//            return bytes
//        }
        
        //context.resume()
        return nil
    }
}


// MARK: - render
public extension IMPImageProvider {
    
    public func render(to texture: inout MTLTexture?, comlete:((_ texture:MTLTexture?, _ command:MTLCommandBuffer?)->Void)?=nil) {
        
        guard  let image = image else {
            comlete?(nil,nil)            
            return             
        }
        
        texture = checkTexture(texture: texture)
        
        if let t = texture {
            context.execute(wait: true) { (commandBuffer) in
                
                self.context.coreImage?.render(image,
                                               to: t,
                                               commandBuffer: commandBuffer,
                                               bounds: image.extent,
                                               colorSpace: self.colorSpace)
                comlete?(t,commandBuffer)
            }
        }
        else {
            comlete?(nil,nil)            
        }
    }
    
    public func render(to texture: inout MTLTexture?,
                       with commandBuffer: MTLCommandBuffer,
                       comlete:((_ texture:MTLTexture?, _ command:MTLCommandBuffer?)->Void)? = nil) {
        
        guard  let image = image else {
            comlete?(nil,nil)
            return             
        }
        
        texture = checkTexture(texture: texture)
        
        if let t = texture {
            self.context.coreImage?.render(image,
                                           to: t,
                                           commandBuffer: commandBuffer,
                                           bounds: image.extent,
                                           colorSpace: self.colorSpace)
            comlete?(t,commandBuffer)
        }
        else {
            comlete?(nil,nil)
        }
    }
    
    
    private func checkTexture(texture:MTLTexture?) -> MTLTexture? {
        
        guard  let image = image else {  return nil }
        
        let width = Int(image.extent.size.width)
        let height = Int(image.extent.size.height)
        
        if texture?.width != width  || texture?.height != height
        {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: IMProcessing.colors.pixelFormat,
                width: width, height: height, mipmapped: false)
            
            
            if storageMode == .shared {
                #if os(iOS)
                    descriptor.storageMode = .shared
                    descriptor.usage = [.shaderRead, .shaderWrite,.pixelFormatView,.renderTarget]
                #elseif os(OSX)
                    descriptor.storageMode = .managed
                    descriptor.usage = [.shaderRead, .shaderWrite,.pixelFormatView,.renderTarget]
                #endif
            }
            else {
                descriptor.storageMode = .private
                descriptor.usage = [.shaderRead,.pixelFormatView,.renderTarget]
            }
            
            if texture != nil {
                texture?.setPurgeableState(.volatile)
            }

            return self.context.device.makeTexture(descriptor: descriptor)
        }
        
        if texture != nil {
            texture?.setPurgeableState(.keepCurrent)
        }

        return texture
    }
    
    public var cgiImage:CGImage? {
        get {
            guard let image = image else { return nil }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var t = CGAffineTransform.identity
            t = t.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: image.extent.size.height)
            let im = image.transformed(by: t)
            return context.coreImage?.createCGImage(im, from: image.extent,
                                                    format: kCIFormatARGB8,
                                                    colorSpace: colorSpace,
                                                    deferred:true)            
        }
        set {
            if let im = newValue {
                image = CIImage(cgImage: im, options: [kCIImageColorSpace: colorSpace])
            }
        }
    }
    
    #if os(iOS)
    public var nsImage:NSImage? {
        get{
            guard (image != nil) else { return nil}
            return NSImage(cgImage: cgiImage!)
        }
        set {
            cgiImage = newValue?.cgImage
        }
    }
    #else
    public var nsImage:NSImage? {
        get {
            if let image = self.image {

                var t = CGAffineTransform.identity
                t = t.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: image.extent.size.height)
                let im = image.transformed(by: t)
                
                let rep: NSCIImageRep = NSCIImageRep(ciImage: im)
                
                let nsImage: NSImage = NSImage(size: rep.size)                
                nsImage.addRepresentation(rep)
                return nsImage
            }
            return nil
        }
        set{
            guard let data = newValue?.tiffRepresentation else { return }
            image = CIImage(data: data, options: [kCIImageColorSpace: colorSpace])
        }
    }
    #endif
}



#if os(OSX)

    public typealias IMPImageFileType = NSBitmapImageRep.FileType
    
    extension NSImage {
                      
        func representation(using type: IMPImageFileType, compression factor:Float? = nil) -> Data? {
                                    
            guard let tiffRepresentation = tiffRepresentation(using: .none, factor: factor ?? 1.0), 
                let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) 
                else { return nil }
            
            var properties:[NSBitmapImageRep.PropertyKey : Any] = [:]
            
            if type == .jpeg {
                properties = [NSBitmapImageRep.PropertyKey.compressionFactor: factor ?? 1.0]
            }
            
            return bitmapImage.representation(using: type, properties: properties)            
        }
                
        convenience init?(ciimage:CIImage?){
            
            guard var image = ciimage else {
                return nil
            }
            
            //
            // convert back to MTL texture coordinates system
            //
            let transform = CGAffineTransform.identity.scaledBy(x: 1, y: -1).translatedBy(x: 0, y: image.extent.height)
            image = image.transformed(by: transform)
            
            self.init(size: image.extent.size)
            let rep = NSCIImageRep(ciImage: image)
            addRepresentation(rep)
        }
        
    }
    
    // MARK: - export to files
    public extension IMPImageProvider{
        
        
        /// Image provider representaion as Data?
        ///
        /// - Parameters:
        ///   - type: representation type: `IMPImageFileType`
        ///   - factor: compression factor (.JPEG only)
        /// - Returns: representation Data?
        public func representation(using type: IMPImageFileType, compression factor:Float? = nil) -> Data?{
            return NSImage(ciimage:image)?.representation(using: type, compression: factor)
        }
        
        
        /// Write image to URL
        ///
        /// - Parameters:
        ///   - url: url
        ///   - type: image type
        ///   - factor: compression factor (.JPEG only)
        /// - Throws: `Error`
        public func write(to url: URL, using type: IMPImageFileType, compression factor:Float? = nil) throws {
            try representation(using: type, compression: factor)?.write(to: url, options: .atomic)
        }
        
        public func write(to path: String, using type: IMPImageFileType, compression factor:Float? = nil) throws {
            try representation(using: type, compression: factor)?.write(to: URL(fileURLWithPath: path), options: .atomic)
        }        
    }
    
#endif
