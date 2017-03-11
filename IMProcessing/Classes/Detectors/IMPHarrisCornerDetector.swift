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


/** Harris corner detector
 
 First pass: reduce to luminance and take the derivative of the luminance texture (GPUImageXYDerivativeFilter)
 
 Second pass: blur the derivative (GaussianBlur)
 
 Third pass: apply the Harris corner detection calculation
 
 This is the Harris corner detector, as described in
 C. Harris and M. Stephens. A Combined Corner and Edge Detector. Proc. Alvey Vision Conf., Univ. Manchester, pp. 147-151, 1988.
 
 Sources:  https://github.com/BradLarson/GPUImage2
 
 */
public class IMPHarrisCornerDetector: IMPResampler{
    
    public typealias PointsListObserver = ((_ corners: [float2], _ imageSize:NSSize) -> Void)
    
    public static let defaultBlurRadius:Float = 2
    public static let defaultTexelRadius:Float = 1.5
    
    public var blurRadius:Float {
        set{
            blurFilter.radius = newValue
            dirty = true
        }
        get { return blurFilter.radius }
    }
    
    public var texelRadius:Float {
        set{
            xyDerivative.texelRadius = newValue
            dirty = true
        }
        get { return xyDerivative.texelRadius }
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
        
        maxSize = 200
        blurRadius = IMPHarrisCornerDetector.defaultBlurRadius
        sensitivity = IMPHarrisCorner.defaultSensitivity
        threshold = IMPNonMaximumSuppression.defaultThreshold
        texelRadius = IMPHarrisCornerDetector.defaultTexelRadius
    }
    
    private lazy var xyDerivative:IMPXYDerivative = IMPXYDerivative(context: self.context, name: "HarrisCornerDetector:XYDerivative")
    private lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context, name: "HarrisCornerDetector:Blur")
    private lazy var harrisCorner:IMPHarrisCorner = IMPHarrisCorner(context: self.context, name: "HarrisCornerDetector:Corner")
    private lazy var nonMaximumSuppression:IMPNonMaximumSuppression = IMPNonMaximumSuppression(context: self.context, name: "HarrisCornerDetector:NonMaximum")
    
    var rawPixels:UnsafeMutablePointer<UInt8>?
    var imageByteSize:Int = 0

    
    deinit {
        rawPixels?.deallocate(capacity: imageByteSize)
    }
    
    private var isReading = false
    
    private func readCorners(_ destination: IMPImageProvider) {
        
        guard !isReading else { return }
        
        isReading = true
        
        if let size = destination.size,
            let texture = destination.texture?.pixelFormat != .rgba8Uint ?
                destination.texture?.makeTextureView(pixelFormat: .rgba8Uint) :
                destination.texture
        {
            
            let width       = Int(size.width)
            let height      = Int(size.height)
            
            let bytesPerRow   = width * 4
            let newSize = height * bytesPerRow
            
            if imageByteSize != newSize {
                if imageByteSize > 0 {
                    rawPixels?.deallocate(capacity: imageByteSize)
                }
                rawPixels = UnsafeMutablePointer<UInt8>.allocate(capacity:newSize) 
            }

            imageByteSize = newSize
            
            texture.getBytes(rawPixels!,
                             bytesPerRow: bytesPerRow,
                             from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                             mipmapLevel: 0)
            
            var corners = [float2]()
            
            for x in stride(from: 0, to: width, by: 1){
                for y in stride(from: 0, to: height, by: 1){
                    let colorByte = rawPixels![y * bytesPerRow + x * 4]
                    
                    if (colorByte > 128) {
                        let xCoordinate = Float(x) / Float(width)
                        let yCoordinate = Float(y) / Float(height) 
                        corners.append(float2(xCoordinate, yCoordinate))
                    }
                }
            }
            
            for o in cornersObserverList {
                o(corners,size)
            }
            
            isReading = false
        }
    }
    
    func addObserver(corners observer: @escaping PointsListObserver) {
        cornersObserverList.append(observer)
    }
    
    private lazy var cornersObserverList = [PointsListObserver]()
}
