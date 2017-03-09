//
//  IMPHarrisCornerDetector.swift
//  IMPCameraManager
//
//  Created by Denis Svinarchuk on 09/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal
import Accelerate


/* Harris corner detector
 
 First pass: reduce to luminance and take the derivative of the luminance texture (GPUImageXYDerivativeFilter)
 
 Second pass: blur the derivative (GaussianBlur)
 
 Third pass: apply the Harris corner detection calculation
 
 This is the Harris corner detector, as described in
 C. Harris and M. Stephens. A Combined Corner and Edge Detector. Proc. Alvey Vision Conf., Univ. Manchester, pp. 147-151, 1988.
 
 Sources:  https://github.com/BradLarson/GPUImage2
 
 */
public class IMPHarrisCornerDetector: IMPFilter{
    
    public typealias PointsListObserver = ((_ corners: [float3]) -> Void)
    
    public static let defaultBlurRadius:Float = 2.0
    
    public var blurRadius:Float {
        set{
            blurFilter.radius = newValue
            dirty = true
        }
        get { return blurFilter.radius }
    }
    
    public var sensitivity:Float {
        set{
            harrisCorner.sensitivity = newValue
        }
        get{ return harrisCorner.sensitivity }
    }
    
    
    public var threshold:Float {
        set {
            nonMaximumSuppression.threshold = newValue
        }
        get{ return nonMaximumSuppression.threshold }
    }
    
    public override func configure() {
        extendName(suffix: "HarrisCornerDetector")
        
        super.configure()
        
        resampler.destinationSize = NSSize(width: 400, height: 400)

        add(filter: resampler)
        
        add(filter: xyDerivative)
        add(filter: blurFilter)
        add(filter: harrisCorner)
        
        add(filter: nonMaximumSuppression) { [unowned self] (destination) in
            self.readCorners(destination)
        }
        
        blurRadius = IMPHarrisCornerDetector.defaultBlurRadius
        sensitivity = IMPHarrisCorner.defaultSensitivity
        threshold = IMPNonMaximumSuppression.defaultThreshold
    }
    
    private lazy var xyDerivative:IMPXYDerivative = IMPXYDerivative(context: self.context, name: "HarrisCornerDetector:XYDerivative")
    private lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context, name: "HarrisCornerDetector:Blur")
    private lazy var harrisCorner:IMPHarrisCorner = IMPHarrisCorner(context: self.context, name: "HarrisCornerDetector:Corner")
    private lazy var nonMaximumSuppression:IMPNonMaximumSuppression = IMPNonMaximumSuppression(context: self.context, name: "HarrisCornerDetector:NonMaximum")
    
    private func readCorners(_ destination: IMPImageProvider) {
        if let size = destination.size,
            let texture = destination.texture?.pixelFormat != .rgba8Uint ?
                destination.texture?.makeTextureView(pixelFormat: .rgba8Uint) :
                destination.texture
        {
            let bytesPerRow = Int(size.width * 4)
            let bytesPerImage = Int(size.height)*bytesPerRow
            let imageByteSize = bytesPerRow * Int(size.height)
            let rawPixels = UnsafeMutablePointer<UInt8>.allocate(capacity:imageByteSize)
            
            texture.getBytes(rawPixels,
                             bytesPerRow: bytesPerRow,
                             bytesPerImage: bytesPerImage,
                             from: MTLRegion(origin: MTLOrigin(), size: texture.size),
                             mipmapLevel: 0, slice: 0)
            
            var corners = [float3]()
            
            //var currentByte = 0
            
            for x in stride(from: 0, to: bytesPerRow, by: 4){
                for y in stride(from: 0, to: Int(size.height), by: 1){
            //while (currentByte < imageByteSize) {
                let colorByte = rawPixels[y*bytesPerRow+x]
                
                if (colorByte > 0) {
                    //let xCoordinate = Float(currentByte % bytesPerRow)
                    //let yCoordinate = Float(currentByte / bytesPerRow)
                    let xCoordinate = Float(x/4) / Float(size.width)
                    let yCoordinate = 1 - Float(y) / Float(size.height)
                    
                    //corners.append(float3( xCoordinate / 4.0 / Float(size.width), yCoordinate / Float(size.height), 0))
                    corners.append(float3( xCoordinate , yCoordinate  , 0))
                }
                
                //currentByte += 4
                }
            }
            rawPixels.deallocate(capacity: imageByteSize)
            
            for o in cornersObserverList {
                o(corners)
            }
        }
    }
    
    func addObserver(corners observer: @escaping PointsListObserver) {
        cornersObserverList.append(observer)
    }
    
    private lazy var cornersObserverList = [PointsListObserver]()
    
    private lazy var resampleShader:IMPShader = IMPShader(context: self.context, name: "IMPFilterBaseResamplerShader")
    
    private lazy var resampler:IMPCIFilter = {
        return IMPCoreImageMTLShader.register(shader: self.resampleShader)
    }()
}
