//
//  IMPRawFile.swift
//  IMPCurveTest
//
//  Created by denis svinarchuk on 04.10.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import CoreImage

open class IMPRawFile: IMPImageProvider {

    
    public let mutex = IMPSemaphore()

    public func removeObserver(optionsChanged observer: @escaping ObserverType) {
        self.mutex.sync { () -> Void in
            self.unsafeRemoveObserver(optionsChanged: observer)
        }        
    }
    
    public func addObserver(optionsChanged observer: @escaping ObserverType) {
        self.mutex.sync { () -> Void in
            let key = self.unsafeRemoveObserver(optionsChanged: observer)
            self.filterObservers.append(IMPObserverHash<ObserverType>(key:key,observer: observer))
        }
    }
    
    private func unsafeRemoveObserver(optionsChanged observer: @escaping ObserverType) -> String {
        let key = IMPObserverHash<ObserverType>.observerKey(observer)
        if let index = self.filterObservers.index(where: { return $0.key == key }) {
            self.filterObservers.remove(at: index)
        }  
        return key
    }
    
    public func removeObservers() {
        self.mutex.sync { () -> Void in
            self.filterObservers.removeAll()
        }
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

    public var ev:Float = 0 {
        didSet{
            self.rawFilter?.setValue(self.ev, forKey: kCIInputEVKey)
            self.renderTexture()                
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
    
    public var orientation:IMPImageOrientation {
        set{
            inputOrientation = IMPExifOrientation(imageOrientation: newValue) ?? .up
        }
        get {
            return IMPImageOrientation(exifValue: Int(inputOrientation.rawValue)) ?? .up
        }
    }

    public var inputOrientation:IMPExifOrientation {
        set{
            rawFilter?.setValue(true, forKey: kCIInputIgnoreImageOrientationKey)
            rawFilter?.setValue(newValue.rawValue, forKey: kCIInputImageOrientationKey)
            renderTexture()            
        }
        get {
            let o = (rawFilter?.value(forKeyPath: kCIInputImageOrientationKey) as? NSNumber)?.int32Value ?? IMPExifOrientation.up.rawValue
            return IMPExifOrientation(rawValue: o) ?? IMPExifOrientation.up
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
                self.render(to: &_texture, flipVertical:true)
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
                            orientation:IMPImageOrientation? = nil,                            
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil, 
                            maxSize: CGFloat = 0) {
        self.init(context: context, storageMode: storageMode)
        rawFilter =  CIFilter(imageData: data, options: rawOptions) 
        intitFilter(scale: factor, draft: mode, orientation: orientation, maxSize:maxSize)
    }
    
    public convenience init(context: IMPContext, 
                            rawFile url: URL, 
                            scale factor: Float = 1,
                            draft mode: Bool = false,
                            orientation:IMPImageOrientation? = nil,                            
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil, 
                            maxSize: CGFloat = 0) {
        self.init(context: context, storageMode: storageMode)
        rawFilter = CIFilter(imageURL: url, options: rawOptions)
        intitFilter(scale: factor, draft: mode, orientation: orientation, maxSize:maxSize)
    }
    
    public convenience init(context: IMPContext, 
                            rawFile path: String,
                            scale factor: Float = 1,
                            draft mode: Bool = false,
                            orientation:IMPImageOrientation? = nil,
                            rawOptions:  [String : CFString]?=nil, 
                            storageMode: IMPImageStorageMode?=nil, 
                            maxSize: CGFloat = 0) {
        self.init(context: context, rawFile: URL(fileURLWithPath: path), scale: factor, draft: mode, orientation:orientation, rawOptions:rawOptions, storageMode: storageMode, maxSize:maxSize)
    }
    
    private  func intitFilter(scale factor: Float,
                             draft mode: Bool,
                             orientation:IMPImageOrientation?,
                             maxSize:CGFloat) {
                
        self.maxSize = maxSize
        rawFilter?.setValue(boost, forKey: kCIInputBoostKey)
        rawFilter?.setValue(boostShadow, forKey: kCIInputBoostShadowAmountKey)

        rawFilter?.setValue(noiseReduction, forKey: kCIInputNoiseReductionAmountKey)
        rawFilter?.setValue(noiseReductionSharpness, forKey: kCIInputNoiseReductionSharpnessAmountKey)
        rawFilter?.setValue(noiseReductionContrast, forKey: kCIInputNoiseReductionContrastAmountKey)
        rawFilter?.setValue(noiseReductionDetail, forKey: kCIInputNoiseReductionDetailAmountKey)
        
        rawFilter?.setValue(colorNoiseReduction, forKey: kCIInputColorNoiseReductionAmountKey)
        rawFilter?.setValue(luminanceNoiseReduction, forKey: kCIInputLuminanceNoiseReductionAmountKey)
        
        rawFilter?.setValue(enableSharpening, forKey: kCIInputEnableSharpeningKey)
        rawFilter?.setValue(factor, forKey: kCIInputScaleFactorKey)
        rawFilter?.setValue(mode, forKey: kCIInputAllowDraftModeKey)
        
        _image = renderOutput()
        
        if let o = orientation {
            self.orientation = o
        }
    }
    
    
    private var maxSize:CGFloat = 0 
    private func renderOutput() -> CIImage? {
        if var im = rawFilter?.outputImage {
            if maxSize > 0.01  { // 100%
                let size = im.extent.size
                let maxSizeOfIm = max(size.width, size.height)
                let scale =  maxSize/maxSizeOfIm
                if scale < 1 {
                    var t = CGAffineTransform.identity
                    t = t.scaledBy(x: scale, y: scale)
                    im = im.transformed(by: t)
                }
            }
            _image = im
        }
        return _image
    }
    
    private func renderTexture() {
        if self.renderOutput() != nil {            
            self.render(to: &self._texture, flipVertical:true) { (texture,command) in
                let observers = self.mutex.sync { return [IMPObserverHash<ObserverType>](self.filterObservers) }
                for hash in observers {
                    self.context.runOperation(.async) {
                        hash.observer(self)
                    }
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
    
    private var filterObservers = [IMPObserverHash<ObserverType>]() //[((IMPImageProvider) -> Void)]()

}

