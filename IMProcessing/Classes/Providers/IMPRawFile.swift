//
//  IMPRawFile.swift
//  IMPCurveTest
//
//  Created by denis svinarchuk on 04.10.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import CoreImage

open class IMPRawFile: IMPImageProvider {
    
    public func addObserver(optionsChanged observer: @escaping ((IMPImageProvider) -> Void)) {
        filterObservers.append(observer)
    }
    
    public var baselineExposure:Float {
        set {
            rawFilter?.setValue(baselineExposure,  forKey: kCIInputBaselineExposureKey)
            renderTexture()
        }
        get {
            return (rawFilter?.value(forKey: kCIInputBaselineExposureKey) as? NSNumber)?.floatValue ?? 0 
        }
    }
    
    public var bias:Float = 0 {
        didSet{
            rawFilter?.setValue(bias, forKey: kCIInputBiasKey)
            renderTexture()
        }
    }
    
    public var boost:Float = 0 {
        didSet{
            rawFilter?.setValue(max(min(1, boost),0), forKey: kCIInputBoostKey)
            renderTexture()
        }
    }
    
    public var boostShadow:Float = 0 {
        didSet{
            rawFilter?.setValue(max(min(1, boostShadow),0), forKey: kCIInputBoostShadowAmountKey)
            renderTexture()
        }        
    }
    
    public var neutralChromaticity:float2? {
        set {
            if let nc = newValue {
                rawFilter?.setValue(nc.x, forKey: kCIInputNeutralChromaticityXKey)
                rawFilter?.setValue(nc.y, forKey: kCIInputNeutralChromaticityYKey)
                renderTexture()
            }
        }
        get{
            if let y = (rawFilter?.value(forKeyPath: kCIInputNeutralChromaticityYKey) as? NSNumber)?.floatValue,
                let x = (rawFilter?.value(forKeyPath: kCIInputNeutralChromaticityXKey) as? NSNumber)?.floatValue{
                return float2(x,y)
            }
            return nil
        }
    }
    
    public var neutralLocation:float2? {
        didSet{
            if let point = neutralLocation {
                let loc = CIVector(cgPoint: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
                rawFilter?.setValue(loc, forKey: kCIInputNeutralLocationKey)
                renderTexture()
            }
        }
    }
    
    public var orientation = IMPImageOrientation.up {
        didSet{
            rawFilter?.setValue(false, forKey: kCIInputIgnoreImageOrientationKey)
            rawFilter?.setValue(orientation.exifValue, forKey: kCIInputImageOrientationKey)        
        }
    }
    
    public var temperature:Float {
        set{
            rawFilter?.setValue(newValue, forKey: kCIInputNeutralTemperatureKey)
            renderTexture()            
        }
        get {
            return (rawFilter?.value(forKeyPath: kCIInputNeutralTemperatureKey) as? NSNumber)?.floatValue ?? 5000
        }
    }
    
    public var tint:Float {
        set{
            rawFilter?.setValue(newValue, forKey: kCIInputNeutralTintKey)
            renderTexture()            
        }
        get {
            return (rawFilter?.value(forKeyPath: kCIInputNeutralTintKey) as? NSNumber)?.floatValue ?? 0
        }
    }
    
    public var enableSharpening:Bool = false {
        didSet{  
            rawFilter?.setValue(enableSharpening, forKey: kCIInputEnableSharpeningKey)
            renderTexture()
        }
    }    
    
    public var noiseReduction:Float = 0 {
        didSet{  
            rawFilter?.setValue(noiseReduction, forKey: kCIInputNoiseReductionAmountKey)
            renderTexture()
        }        
    }
    
    public var luminanceNoiseReduction:Float = 0 {
        didSet{  
            rawFilter?.setValue(luminanceNoiseReduction, forKey: kCIInputLuminanceNoiseReductionAmountKey)
            renderTexture()
        }                
    }
    
    public var noiseReductionDetail:Float = 0 {
        didSet{  
            rawFilter?.setValue(noiseReductionDetail, forKey: kCIInputNoiseReductionDetailAmountKey)
            renderTexture()
        }                
    }
    
    public var colorNoiseReduction:Float = 0 {
        didSet{  
            rawFilter?.setValue(colorNoiseReduction, forKey: kCIInputColorNoiseReductionAmountKey)
            renderTexture()
        }                
    }
    
    public var noiseReductionContrast:Float = 0 {
        didSet{  
            rawFilter?.setValue(noiseReductionContrast, forKey: kCIInputNoiseReductionContrastAmountKey)
            renderTexture()
        }                
    }
    
    public var noiseReductionSharpness:Float = 0 {
        didSet{  
            rawFilter?.setValue(noiseReductionSharpness, forKey: kCIInputNoiseReductionSharpnessAmountKey)
            renderTexture()
        }                
    }
    
    public let storageMode: IMPImageStorageMode
    public let context: IMPContext
    
    public var texture: MTLTexture? {
        set{
            fatalError("IMPRawFile: texture could not be set \(#file):\(#line)")
        }
        get{
            if _texture == nil && _image != nil {
                self.render(to: &_texture)
            }
            return _texture
        }
    }
    
    open var image: CIImage? {
        set{
            fatalError("IMPRawFile: input image could not be set \(#file):\(#line)")
        }
        get {
            return renderOutput() 
        }
    }
    
    public var size: NSSize? {
        get{
            return _image?.extent.size ?? _texture?.cgsize
        }
    }
    
    public convenience init(context: IMPContext, 
                            rawImage data: Data, 
                            scale factor: Float = 1,
                            draft mode: Bool = false,
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil) {
        self.init(context: context, storageMode: storageMode)
        rawFilter =  CIFilter(imageData: data, options: rawOptions) 
        intitFilter(scale: factor, draft: mode)
    }
    
    public convenience init(context: IMPContext, 
                            rawFile url: URL, 
                            scale factor: Float = 1,
                            draft mode: Bool = false,
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil) {
        self.init(context: context, storageMode: storageMode)
        rawFilter = CIFilter(imageURL: url, options: rawOptions)
        intitFilter(scale: factor, draft: mode)
    }
    
    public convenience init(context: IMPContext, 
                            rawFile path: String,
                            scale factor: Float = 1,
                            draft mode: Bool = false,
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil) {
        self.init(context: context, rawFile: URL(fileURLWithPath: path), scale: factor, draft: mode, rawOptions:rawOptions, storageMode: storageMode)
    }
    
    private func intitFilter(scale factor: Float = 1,
                             draft mode: Bool = false) {
                
        rawFilter?.setValue(boost, forKey: kCIInputBoostKey)
        rawFilter?.setValue(boostShadow, forKey: kCIInputBoostShadowAmountKey)
        rawFilter?.setValue(noiseReductionSharpness, forKey: kCIInputNoiseReductionSharpnessAmountKey)
        rawFilter?.setValue(noiseReductionContrast, forKey: kCIInputNoiseReductionContrastAmountKey)
        rawFilter?.setValue(noiseReductionDetail, forKey: kCIInputNoiseReductionDetailAmountKey)
        rawFilter?.setValue(colorNoiseReduction, forKey: kCIInputColorNoiseReductionAmountKey)
        rawFilter?.setValue(luminanceNoiseReduction, forKey: kCIInputLuminanceNoiseReductionAmountKey)
        rawFilter?.setValue(noiseReduction, forKey: kCIInputNoiseReductionAmountKey)
        rawFilter?.setValue(enableSharpening, forKey: kCIInputEnableSharpeningKey)
        rawFilter?.setValue(factor, forKey: kCIInputScaleFactorKey)
        rawFilter?.setValue(mode, forKey: kCIInputAllowDraftModeKey)
        rawFilter?.setValue(false, forKey: kCIInputIgnoreImageOrientationKey)
        rawFilter?.setValue(Int(IMPExifOrientation.verticalFlipped.rawValue), forKey: kCIInputImageOrientationKey)        
        _image = renderOutput()        
    }
    
    private func renderOutput() -> CIImage? {
        _image = rawFilter?.outputImage
        return _image
    }
    
    private func renderTexture() {
        if renderOutput() != nil {
            render(to: &_texture) { (texture,command) in
                for o in self.filterObservers {
                    o(self)
                }
            }            
        }
    }
    
    public lazy var videoCache:IMPVideoTextureCache = {
        return IMPVideoTextureCache(context: self.context)
    }()
    
    private var rawFilter:CIFilter?   
    fileprivate var _image:CIImage? = nil
    fileprivate var _texture:MTLTexture? = nil
    
    //
    // http://stackoverflow.com/questions/12524623/what-are-the-practical-differences-when-working-with-colors-in-a-linear-vs-a-no
    //
    lazy public var colorSpace:CGColorSpace = {
        if #available(iOS 10.0, *) {
            return CGColorSpace(name: CGColorSpace.sRGB)!
        }
        else {
            fatalError("extendedLinearSRGB: ios >10.0 supports only")
        }
    }()
    
    public required init(context: IMPContext, storageMode:IMPImageStorageMode? = .shared) {
        self.context = context        
        if storageMode != nil {
            self.storageMode = storageMode!
        }
        else {
            self.storageMode = .shared
        }
    }
    
    private var filterObservers = [((IMPImageProvider) -> Void)]()
    
}
