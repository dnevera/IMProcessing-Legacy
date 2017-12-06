//
//  IMPIIRFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 15.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Accelerate
import simd

open class IMPIIRGaussianBlurFilter: IMPFilter {
    
    open var radius:Int!{
        didSet{
            update()
            dirty = true
        }
    }
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel_iirFilterHorizontal = IMPFunction(context: context, name: "kernel_iirFilterHorizontal")
        kernel_iirFilterVertical   = IMPFunction(context: context, name: "kernel_iirFilterVertical")
        defer{
            radius = 0
        }
    }
    
    override open func apply() -> IMPImageProvider {
        
        if radius <= 1 {
            return super.apply()
        }
        
        if dirty {
            if let t = source?.texture{
                
                executeSourceObservers(source)
                
                let inputTexture:MTLTexture! = self.source!.texture
                
                let width  = inputTexture.width
                let height = inputTexture.height
                
                let threadgroupCounts = MTLSizeMake(1, 1, 1);
                let threadgroupsX = MTLSizeMake(1, t.height,1);
                let threadgroupsY = MTLSizeMake(t.width,1,1);

                if self._destination.texture?.width != width || self._destination.texture?.height != height {
                    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                        pixelFormat: inputTexture.pixelFormat,
                        width: width, height: height, mipmapped: false)
                    
                    self._destination.texture = self.context.device.makeTexture(descriptor: descriptor)
                }

                let forwardWidth  = width+radius*3
                let forwardHeight = height+radius*3
                let length = forwardWidth * forwardHeight * 4 * MemoryLayout<Float>.size

                if self.inoutBuffer?.length != length {
                    self.inoutBuffer = context.device.makeBuffer(length: length, options: MTLResourceOptions())
                }

                if self.inoutBuffer2?.length != length {
                    self.inoutBuffer2 = context.device.makeBuffer(length: length, options: MTLResourceOptions())
                }

                self.bsizeBuffer = self.bsizeBuffer ?? self.context.device.makeBuffer(length: MemoryLayout<int2>.size, options: MTLResourceOptions())
                var bsize:int2 = int2(Int32(forwardWidth),Int32(forwardHeight))
                memcpy(self.bsizeBuffer!.contents(), &bsize, self.bsizeBuffer!.length)

                context.execute{ (commandBuffer) -> Void in
                    
                    //
                    // horizontal stage
                    //
                    var blitEncoder = commandBuffer.makeBlitCommandEncoder()
                    blitEncoder?.__fill(self.inoutBuffer!, range: NSRange(location: 0, length: self.inoutBuffer!.length), value: 0)
                    blitEncoder?.__fill(self.inoutBuffer2!,range: NSRange(location: 0, length:self.inoutBuffer2!.length), value: 0)
                    blitEncoder?.endEncoding()

                    var commandEncoder = commandBuffer.makeComputeCommandEncoder()
                    
                    commandEncoder?.setComputePipelineState(self.kernel_iirFilterHorizontal.pipeline!)
                    
                    commandEncoder?.setTexture(inputTexture,    index: 0)
                    commandEncoder?.setTexture(self._destination.texture,    index: 1)
                    commandEncoder?.setTexture(self.bTexture,   index: 2)
                    commandEncoder?.setTexture(self.aTexture,   index: 3)
                    commandEncoder?.setBuffer(self.inoutBuffer,  offset: 0, index: 0)
                    commandEncoder?.setBuffer(self.inoutBuffer2, offset: 0, index: 1)
                    commandEncoder?.setBuffer(self.bsizeBuffer,  offset: 0, index: 2)
                    commandEncoder?.setBuffer(self.radiusBuffer, offset: 0, index: 3)

                    commandEncoder?.dispatchThreadgroups(threadgroupsX, threadsPerThreadgroup:threadgroupCounts)
                    commandEncoder?.endEncoding()

                
                    //
                    // vertical stage
                    //
                    blitEncoder = commandBuffer.makeBlitCommandEncoder()
                    blitEncoder?.__fill(self.inoutBuffer!, range: NSRange(location: 0, length: self.inoutBuffer!.length), value: 0)
                    blitEncoder?.__fill(self.inoutBuffer2!,range: NSRange(location: 0, length:self.inoutBuffer2!.length), value: 0)
                    blitEncoder?.endEncoding()
                    
                    commandEncoder = commandBuffer.makeComputeCommandEncoder()
                    
                    commandEncoder?.setComputePipelineState(self.kernel_iirFilterVertical.pipeline!)
                    
                    commandEncoder?.setTexture(self._destination.texture,    index: 0)
                    commandEncoder?.setTexture(self._destination.texture,    index: 1)
                    commandEncoder?.setTexture(self.bTexture,   index: 2)
                    commandEncoder?.setTexture(self.aTexture,   index: 3)
                    commandEncoder?.setBuffer(self.inoutBuffer,  offset: 0, index: 0)
                    commandEncoder?.setBuffer(self.inoutBuffer2, offset: 0, index: 1)
                    commandEncoder?.setBuffer(self.bsizeBuffer,  offset: 0, index: 2)
                    commandEncoder?.setBuffer(self.radiusBuffer, offset: 0, index: 3)
                    
                    commandEncoder?.dispatchThreadgroups(threadgroupsY, threadsPerThreadgroup:threadgroupCounts)
                    commandEncoder?.endEncoding()
                }
                
                executeDestinationObservers(_destination)
            }
        }
        dirty = false
        return _destination
    }
    
    lazy var _destination:IMPImageProvider = {
        return IMPImageProvider(context: self.context)
    }()
    
    
//    private var destinationContainer:IMPImageProvider?
//    
//    internal func getDestination() -> IMPImageProvider? {
//        if !enabled{
//            return source
//        }
//        if let t = self.texture{
//            if let d = destinationContainer{
//                d.texture=t
//            }
//            else{
//                destinationContainer = IMPImageProvider(context: self.context, texture: t)
//            }
//        }
//        return destinationContainer
//    }
    
    func update(){
        if radius>1{
            radiusBuffer = radiusBuffer ?? context.device.makeBuffer(length: MemoryLayout.size(ofValue: radius), options: MTLResourceOptions())
            memcpy(radiusBuffer.contents(), &radius, radiusBuffer.length)
            let (b,a) = radius.float.iirGaussianCoefficients
            bTexture = context.device.texture1D(b)
            aTexture = context.device.texture1D(a)
        }
    }
    
    fileprivate var kernel_iirFilterHorizontal:IMPFunction!
    fileprivate var kernel_iirFilterVertical:IMPFunction!
    
    fileprivate var radiusBuffer:MTLBuffer!
    fileprivate var inoutBuffer :MTLBuffer?
    fileprivate var inoutBuffer2:MTLBuffer?
    //private var texture     :MTLTexture?
    fileprivate var bsizeBuffer:MTLBuffer?
    

    var bTexture:MTLTexture!
    var aTexture:MTLTexture!
}


public extension Float {

    public var iirGaussianCoefficients: (b:[Float],a:[Float]) {
        get {
            //
            // https://www.researchgate.net/publication/222453003_Recursive_implementation_of_the_Gaussian_filter
            //
            
            var q = self
            
            if Float(0.5) <= self && self <= Float(2.5) {
                q = 3.97156 - 4.14554 * sqrt(1.0 - 0.26891*self)
            }
            else if self > 2.5 {
                q = 0.98711 * self - 0.96330
            }
            
            let q2   = pow(q, 2)
            let q3   = pow(q, 3)
            let a0   = 1.57825 + (2.44413 * q) + (1.4281  * q2) + (0.422205 * q3)
            let a1   =           (2.44413 * q) + (2.85619 * q2) + (1.26661  * q3)
            let a2   =                           (-1.4281 * q2) + (-1.26661 * q3)
            let a3   =                                            (0.422205 * q3)
            let b    = [1 - ((a1 + a2 + a3) / a0)]
            let a    = [a0, a1, a2, a3] / a0
            
            return (b,a)
        }
    }

    public var iirGaussianCoefficients2: (b:[Float],a:[Float]) {
        
        //
        // http://habrahabr.ru/post/151157/
        //
        
        let q = self
        var q4 = pow(self,2); q4 = 1.0/pow(q4,2)
        
        let coef_A = q4*(q*(q*(q*1.1442707+0.0130625)-0.7500910)+0.2546730)
        let coef_W = q4*(q*(q*(q*1.3642870+0.0088755)-0.3255340)+0.3016210)
        let coef_B = q4*(q*(q*(q*1.2397166-0.0001644)-0.6363580)-0.0536068)
        
        let z0       = exp(coef_A)
        let z0_real  = z0 * cos(coef_W)
        let z2       = exp(coef_B)
        
        let z02      = pow(z0, 2)
        
        let a2 =  1.0 / (z2 * z02)
        let a0 =  (z02 + 2*z0_real * z2) * a2
        let a1 = -(2.float*z0_real + z2) * a2
        
        let b0 = 1.0 - (a0 + a1 + a2)
        
        return ([b0],[1, a0,a1,a2])
    };
}

public func / (left:[Float],right:Float) -> [Float] {
    var ret   = [Float](repeating: 0, count: left.count)
    var denom = right
    vDSP_vsdiv(left, 1, &denom, &ret, 1, vDSP_Length(ret.count))
    return ret
}

public func * (left:[Float],right:Float) -> [Float] {
    var ret   = [Float](repeating: 0, count: left.count)
    var denom = right
    vDSP_vsmul(left, 1, &denom, &ret, 1, vDSP_Length(ret.count))
    return ret
}

