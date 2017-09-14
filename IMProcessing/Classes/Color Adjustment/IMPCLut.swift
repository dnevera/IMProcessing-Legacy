//
//  IMPCLut.swift
//  Pods
//
//  Created by denis svinarchuk on 26.08.17.
//
//

import Foundation
import Metal
import simd


/// Common Color LUT (Look Up Table) provider
open class IMPCLut: IMPImage {
    public typealias UpdateHandler   = ((_ lut:IMPCLut) -> Void)

    
    /// Lute export generator version
    public static let version = "1.0"
    
    public var generatorComment = "# Generated by IMPCLut v." + IMPCLut.version
    
    /// Lute precision presentation
    ///
    /// - float: float
    /// - integer: integer
    public enum Format{
        case float
        case integer
    }
    
    /// Lute error handling
    ///
    /// - notFound: data not found
    /// - wrangFormat: wrang format of loaded data
    /// - wrangRange: wrang range
    /// - outOfRange: out of range
    public struct FormatError: Error {
        public enum Kind {
            case notFound
            case notCreated
            case wrangFormat
            case wrangType
            case wrangRange
            case outOfRange
            case empty
        }
        
        public let file:String
        public let line:Int
        public let kind:Kind
        public let source:String
        public let sourceLine:Int
        
        public init(file: String, line: Int, kind:Kind, source:String = #file, sourceLine:Int=#line){
            self.file = file
            self.line = line
            self.kind = kind
            self.source = source
            self.sourceLine = sourceLine
        }
    }
    
    
    /// Lute data type
    ///
    /// - lut_1d: 1D
    /// - lut_3d: 3D
    public enum LutType {
        case lut_1d
        case lut_2d
        case lut_3d
    }
    
    
    /// Lute type
    public var type:LutType { return _type }
    
    /// Lute title
    public var title:String { return _title }
    
    /// Current cube precision presentation
    public var format:Format {return _format }
        
    /// Lut level
    public var level:Int { return Int(sqrt(Float(_lutSize))) }
    
    internal var _format:Format = .float
    internal var _type:LutType = .lut_3d
    internal var _title:String = ""
    internal var _domainMin = float3(0)
    internal var _domainMax = float3(1)
    internal var _lutSize = Int(0)
    
    fileprivate var observers:[UpdateHandler] = [UpdateHandler]()
}


// MARK: - Create identity Cube LUT
public extension IMPCLut {
    

    /// Create identity Cube Lut
    ///
    /// - Parameters:
    ///   - context: context
    ///   - lutSize: lut size
    ///   - lutType: cube type: LutType.lut_3d or .lut_1d
    ///   - format: cube number format: Format.integer or .float
    ///   - title: cube file title
    public convenience init(context: IMPContext, lutType:LutType, lutSize:Int, format:Format = .integer, title:String? = nil) throws {
        self.init(context: context, storageMode:nil)
        _title    = title ?? "IMPCLut \(lutSize):\(lutType):\(format)"
        _lutSize  = lutSize
        _type     = lutType
        _format = format
        
        let level = Int(sqrt(Double(_lutSize)))

        if _type == .lut_2d {
            texture = makeTexture(size: level*level*level, type: _type, format: _format)
        }
        else {
            texture = makeTexture(size: _lutSize, type: _type, format: _format)
        }
        
        guard let text = texture else { throw FormatError(file: "", line: 0, kind: .empty) }
        
        let kernel = IMPFunction(context: context, kernelName:
            _type == .lut_1d ? "kernel_make1DLut" :  _type == .lut_2d ?  "kernel_make2DLut" :  "kernel_make3DLut")

        let threadsPerThreadgroup = MTLSizeMake(4, 4, 4)
        let threadgroups  = MTLSizeMake(text.width/4, text.height == 1 ? 1 : text.height/4, text.depth == 1 ? 1 : text.depth/4)
        
        context.execute(.sync, wait: true){ (commandBuffer) in
            let commandEncoder =  kernel.commandEncoder(from: commandBuffer)
            commandEncoder.setTexture(text, at:0)
            if self._type == .lut_2d {
                var l = uint(level)
                commandEncoder.setBytes(&l,  length:MemoryLayout.stride(ofValue: l),  at:0)
            }
            commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup:threadsPerThreadgroup)
            commandEncoder.endEncoding()
        }
    }
    
    public func update(from image: IMPImageProvider) throws {
        
        guard let txt = image.texture else { 
             throw FormatError(file: "", line: 0, kind: .empty) 
        }
        
        guard let oldtxt = texture else { 
            throw FormatError(file: "", line: 0, kind: .empty) 
        }
        guard txt.textureType == oldtxt.textureType else {
            throw FormatError(file: "", line: 0, kind: .wrangType)
        }
        
        guard txt.pixelFormat == oldtxt.pixelFormat else {
            throw FormatError(file: "", line: 0, kind: .wrangFormat)
        }
        
        guard txt.size.width == oldtxt.size.width else {
            throw FormatError(file: "", line: 0, kind: .wrangRange)
        }
        
        context.execute(.sync, wait: true, complete: {
            
            for o in self.observers {
                o(self)
            }
            
        }){ (commandBuffer) in            
            let blt = commandBuffer.makeBlitCommandEncoder()
            blt.copy(from: txt, 
                     sourceSlice: 0, 
                     sourceLevel: 0, 
                     sourceOrigin: MTLOrigin(x:0,y:0,z:0), 
                     sourceSize: txt.size, 
                     to: oldtxt, 
                     destinationSlice: 0, 
                     destinationLevel: 0, 
                     destinationOrigin:  MTLOrigin(x:0,y:0,z:0))
            blt.endEncoding()
        }                 
    }
    
    public func removeAllObservers() {
        observers.removeAll()
    }
    
    public func addObserver(updated observer:@escaping UpdateHandler){
        observers.append(observer)
    }
    
    public var identity:IMPCLut {
        return try! IMPCLut(context: context, lutType: _type, lutSize: _lutSize, format:_format, title:_title)
    }        
}

// MARK: - Internal extension
public extension IMPCLut {
    internal func makeTexture(size nSize:Int, type nType:LutType, format nFormat:Format) -> MTLTexture {
        
        let textureDescriptor = MTLTextureDescriptor()
        
        var width  = nSize
        var height = nType == .lut_1d ? 1 : nSize
        let depth  = nType == .lut_1d ? 1 : nType == .lut_2d ? 1 :nSize
        
        
        textureDescriptor.textureType = nType == .lut_1d ? .type1D : nType == .lut_2d ? .type2D : .type3D
        textureDescriptor.width  = width
        textureDescriptor.height = height
        textureDescriptor.depth  = depth
        
        if (nFormat != .float) {
            textureDescriptor.pixelFormat = .rgba8Unorm
        }
        else{
            textureDescriptor.pixelFormat = .rgba32Float
        }
        
        textureDescriptor.arrayLength = 1;
        textureDescriptor.mipmapLevelCount = 1;
        
        return context.device.makeTexture(descriptor: textureDescriptor)
    }
}
