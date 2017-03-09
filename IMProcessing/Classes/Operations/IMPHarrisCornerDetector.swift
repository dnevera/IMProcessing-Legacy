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
            let imageByteSize = Int(size.width * size.height * 4)
            let rawPixels = UnsafeMutablePointer<UInt8>.allocate(capacity:imageByteSize)
            let bytesPerRow = Int(size.width * 4)
            let bytesPerImage = Int(size.height)*bytesPerRow
            
            texture.getBytes(rawPixels,
                             bytesPerRow: bytesPerRow,
                             bytesPerImage: bytesPerImage,
                             from: MTLRegion(origin: MTLOrigin(), size: texture.size),
                             mipmapLevel: 0, slice: 0)
            
            var corners = [float3]()
            
            var currentByte = 0
            while (currentByte < imageByteSize) {
                let colorByte = rawPixels[currentByte]
                
                if (colorByte > 0) {
                    let xCoordinate = currentByte % bytesPerRow
                    let yCoordinate = currentByte / bytesPerRow
                    
                    let point = float3(((Float(xCoordinate) / 4.0) / Float(size.width)), Float(yCoordinate) / Float(size.height), Float(colorByte/255))
                    corners.append(point)
                }
                currentByte += 4
            }
            rawPixels.deallocate(capacity: imageByteSize)
            
            print("corners = \(corners)")
        }
    }
    
    //private lazy var cornersObserverList = (_ corners: [float2]() -> Void)
}
