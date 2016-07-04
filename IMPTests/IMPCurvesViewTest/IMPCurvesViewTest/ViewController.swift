//
//  ViewController.swift
//  ImageMetalling-12
//
//  Created by denis svinarchuk on 12.06.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//
//
//  http://dolboeb.livejournal.com/2957593.html
//
//

import Cocoa
import IMProcessing
import SnapKit
import ImageIO
import MediaLibrary
import ObjectMapper


class ViewController: NSViewController {
    
    var context = IMPContext()
    
    lazy var curves:IMPCurvesFilter = {
        let c = IMPRGBCurvesFilter(context: self.context)
        return c
    }()
   
    lazy var hsvCurves:IMPHSVCurvesFilter = {
        let c = IMPHSVCurvesFilter(context: self.context)
        return c
    }()
    
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        
        f.addFilter(self.curves)
        f.addFilter(self.hsvCurves)
        
        return f
    }()
    
    lazy var imageView:IMPImageView = {
        let v = IMPImageView(context: self.context, frame: self.view.bounds)
        v.filter = self.filter
        v.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        return v
    }()
    
    lazy var curvesControl:IMPRGBCurvesController = {
        let v = IMPRGBCurvesController()
        
        v.didCurvesUpdate = { (channel, spline) in
            switch  channel {
            case .RGB:
                self.curves.w = spline
            case .Red:
                self.curves.x = spline
            case .Green:
                self.curves.y = spline
            case .Blue:
                self.curves.z = spline
            }
        }
        
        v.autoCorrection = { () -> [(low:float2,high:float2)] in
            return self.computeRanges()
        }
        
        return v
    }()

    lazy var hsvCurvesControl:IMPHSVCurvesController = {
        let v = IMPHSVCurvesController()

        v.didCurvesUpdate = { (channel, colors, spline) in
                        
            switch channel {
            case .Hue:
                self.hsvCurves.hue[colors.index] = spline
            case .Saturation:
                self.hsvCurves.saturation[colors.index] = spline
            case .Value:
                self.hsvCurves.value[colors.index] = spline
            }
        }
        
        return v
    }()
    
    var autoRagnesDegree:Float = 1
    func computeRanges()  -> [(low:float2,high:float2)] {
        self.analyzer.source = self.filter.source
        
        let lowlimit:Float = 0.15
        let highlimit:Float = 0.85
        let f:Float = curvesControl.curvesView.curveFunction == .Cubic ? 1 : 2 * autoRagnesDegree
        
        var ranges = [(low:float2,high:float2)]()
        ranges.append((low:float2(0),high:float2(1)))
        
        for i in 0..<3 {
            var m = self.rangeSolver.minimum[i] * f
            var M = 1 - (1-self.rangeSolver.maximum[i]) * f
            
            m = m < 0 ? 0 : m > highlimit ? highlimit : m
            M = M < lowlimit ? lowlimit : M > 1 ? 1 : M
            
            ranges.append((low:float2(m,0),high:float2(M,1)))
        }

        return ranges
    }
    
    lazy var rangeSolver:IMPHistogramRangeSolver = {
        let r = IMPHistogramRangeSolver()
        r.clipping.shadows = 3.5/100.0
        r.clipping.highlights = 0.5/100.0
        return r
    }()
    
    lazy var analyzer:IMPHistogramAnalyzer = {
        let a = IMPHistogramAnalyzer(context: self.context)
        a.addSolver(self.rangeSolver)
        return a
    }()

    
    lazy var rightPanel:NSView = {
        let v = NSView(frame: self.view.bounds)
        return v
    }()
    
    lazy var histogramView:IMPHistogramView = {
        let v = IMPHistogramView(context: self.context, frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        
        v.generatorLayer.components = (
            IMPHistogramLayerComponent(color: float4([1,0.2,0.2,0.3]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.2,1,0.2,0.3]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.2,0.2,1,0.3]), width: Float(UInt32.max)),
            IMPHistogramLayerComponent(color: float4([0.9,0.9,0.9,0.7]), width: Float(UInt32.max)))
        
        v.generatorLayer.backgroundColor = float4(0.1,0.1,0.1,0.3)
        v.generatorLayer.separatorWidth = 0
        v.generatorLayer.sample = true
        
        v.type = .PDF
        v.visibleBins = 128
        
        self.filter.addDestinationObserver(destination: { (destination) in
            v.filter?.source = destination
        })
        return v
    }()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if !IMPContext.supportsSystemDevice {
            
            self.asyncChanges({ () -> Void in
                let alert = NSAlert(error: NSError(domain: "com.imagemetalling.08", code: 0, userInfo: [
                    NSLocalizedFailureReasonErrorKey:"MTL initialization error",
                    NSLocalizedDescriptionKey:"The system does not support MTL..."
                    ]))
                alert.runModal()
            })
            return
        }
        
        
        func loadImage(file:String, size:Float) -> IMPImageProvider? {
            var image:IMPImageProvider? = nil
            do{
                let meta = IMPJpegProvider.metadata(file)
                var orientation = IMPExifOrientationUp
                if let o = meta?[IMProcessing.meta.imageOrientationKey] as? NSNumber {
                    orientation = IMPExifOrientation(rawValue: o as Int)
                }
                
                image = try IMPJpegProvider(context: self.context, file: file, maxSize: size, orientation: orientation)
                
            }
            catch let error as NSError {
                self.asyncChanges({ () -> Void in
                    let alert = NSAlert(error: error)
                    alert.runModal()
                })
            }
            
            return image
        }
        
        IMPDocument.sharedInstance.addDocumentObserver { (file, type) -> Void in
            
            if type == .Image {
                if let image = loadImage(file, size: 1200) {
                    
                    self.curvesControl.curvesView.reset()
                    
                    self.imageView.filter?.source = image
                    
                    self.currentImageFile = file
                    
                    self.asyncChanges({ () -> Void in
                        self.zoomFit()
                        dispatch_after(1 * NSEC_PER_SEC, dispatch_get_main_queue(), {
                            self.restoreConfig()
                        })
                    })
                }
            }
        }
        
        imageView.dragOperation = { (files) in
            
            if files.count > 0 {
                
                let path = files[0]
                let url = NSURL(fileURLWithPath: path)
                if let suffix = url.pathExtension {
                    for ext in ["jpg", "jpeg"] {
                        if ext.lowercaseString == suffix.lowercaseString {
                            IMPDocument.sharedInstance.currentFile = path
                            return true
                        }
                    }
                }
            }
            return false
        }
        
        IMPDocument.sharedInstance.addSavingObserver { (file, type) in
            if type == .Image {
                if let image = loadImage(IMPDocument.sharedInstance.currentFile!, size: 0) {
                    
                    let filter = IMPFilter(context: IMPContext())
                    
                    let curves = IMPRGBCurvesFilter(context: filter.context)
                    let hsvCurves = IMPHSVCurvesFilter(context: filter.context)
                    
                    curves.adjustment = self.curves.adjustment
                    curves.x = self.curves.x
                    curves.y = self.curves.y
                    curves.z = self.curves.z
                    curves.w = self.curves.w
                    
                    hsvCurves.adjustment = self.hsvCurves.adjustment
                    hsvCurves.hue = self.hsvCurves.hue
                    hsvCurves.saturation = self.hsvCurves.saturation
                    hsvCurves.value = self.hsvCurves.value
                    
                    filter.addFilter(curves)
                    filter.addFilter(hsvCurves)
                    
                    filter.source = image
                    
                    do {
                        try filter.destination?.writeToJpeg(file, compression: 1)
                    }
                    catch let error as NSError {
                        self.asyncChanges({ () -> Void in
                            let alert = NSAlert(error: error)
                            alert.runModal()
                        })
                    }
                }
            }
        }
        
        IMPMenuHandler.sharedInstance.addMenuObserver { (item) -> Void in
            if let tag = IMPMenuTag(rawValue: item.tag) {
                switch tag {
                case .zoomFit:
                    self.zoomFit()
                case .zoom100:
                    self.zoom100()
                default:
                    break
                }
            }
        }
        
        view.addSubview(rightPanel)
        rightPanel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.snp_top).offset(5)
            make.bottom.equalTo(self.view.snp_bottom).offset(-5)
            make.right.equalTo(self.view.snp_right).offset(-5)
            make.width.equalTo(320)
        }
        
        rightPanel.addSubview(curvesControl.view)
        curvesControl.view.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.rightPanel.snp_top).offset(10)
            make.left.equalTo(self.rightPanel).offset(5)
            make.right.equalTo(self.rightPanel).offset(-5)
            make.height.equalTo(200)
        }

        rightPanel.addSubview(hsvCurvesControl.view)
        hsvCurvesControl.view.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.curvesControl.view.snp_bottom).offset(20)
            make.left.equalTo(self.rightPanel).offset(5)
            make.right.equalTo(self.rightPanel).offset(-5)
            make.height.equalTo(200)
        }

        rightPanel.addSubview(histogramView)
        histogramView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.hsvCurvesControl.view.snp_bottom).offset(20)
            make.left.equalTo(self.rightPanel).offset(5)
            make.right.equalTo(self.rightPanel).offset(5)
            make.height.equalTo(200)
        }
        
        view.addSubview(toolBar)
        toolBar.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(self.view).offset(1)
            make.left.equalTo(self.view).offset(-1)
            make.right.equalTo(self.rightPanel.snp_left).offset(1)
            make.height.equalTo(80)
            make.width.greaterThanOrEqualTo(600)
        }
        
        view.addSubview(imageView)
        imageView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.snp_top).offset(10)
            make.bottom.equalTo(self.toolBar.snp_top).offset(0)
            make.left.equalTo(self.view.snp_left).offset(10)
            make.right.equalTo(self.rightPanel.snp_left).offset(0)
        }
    }
    
    func enableFilter(sender:NSButton){
        if sender.state == 1 {
            filter.enabled = true
        }
        else {
            filter.enabled = false
        }
    }
    
    func reset(){
    }
    
    
    func zoomFit(){
        asyncChanges { () -> Void in
            self.imageView.sizeFit()
        }
    }
    
    func zoom100(){
        asyncChanges { () -> Void in
            self.imageView.sizeOriginal()
        }
    }
    
    let duration:NSTimeInterval = 0.2
    
    lazy var toolBar:IMPToolBar = {
        let t = IMPToolBar(frame: NSRect(x: 0,y: 0,width: 100,height: 40))
        
        t.shadows = self.rangeSolver.clipping.shadows
        t.highlights = self.rangeSolver.clipping.highlights
        
        t.enableFilterHandler = { (flag) in
            self.filter.enabled = flag
        }
        
        t.enableNormalHandler = { (flag) in
            self.curves.adjustment.blending.mode = flag == false ? .LUMNINOSITY : .NORMAL
        }
        
        t.slideHandler = { (step) in
            self.autoRagnesDegree = step.float/100
            self.curvesControl.currentRanges = self.computeRanges()

        }
        
        t.shadowsHandler = { (value) in
            self.rangeSolver.clipping.shadows = value
            self.curvesControl.currentRanges = self.computeRanges()
        }
        
        t.highlightsHandler = { (value) in
            self.rangeSolver.clipping.highlights = value
            self.curvesControl.currentRanges = self.computeRanges()
        }

        t.resetHandler = {
            self.reset()
        }
        
        return t
    }()
    
    var q = dispatch_queue_create("ViewController", DISPATCH_QUEUE_CONCURRENT)
    
    private func asyncChanges(block:()->Void) {
        dispatch_async(q, { () -> Void in
            dispatch_after(0, dispatch_get_main_queue()) { () -> Void in
                block()
            }
        })
    }
    
    override func viewWillDisappear() {
        saveConfig()
    }
    
    var currentImageFile:String? = nil {
        willSet {
            self.saveConfig()
        }
    }
    
    var configKey:String? {
        if let file = self.currentImageFile {
            return "IMTL-CONFIG-" + file
        }
        return nil
    }
    
    func restoreConfig() {
        
        if let key = self.configKey {
            let json =  NSUserDefaults.standardUserDefaults().valueForKey(key) as? String
            if let m = Mapper<IMTLConfig>().map(json) {
                config = m
            }
        }
        else{
            config = IMTLConfig()
        }
        
        curves.adjustment = config.rgbAdjustment
        hsvCurves.adjustment = config.hsvAdjustment
        
        curves.curveFunction = config.rgbFunction
        hsvCurves.curveFunction = config.hsvFunction
        
        curves.x <- config.rControlPoints
        curves.y <- config.gControlPoints
        curves.z <- config.bControlPoints
        curves.w <- config.wControlPoints
        
        for i in 0..<7 {
            hsvCurves.hue[i] <- config.hueControlPoints[i]
        }
        for i in 0..<7 {
             hsvCurves.saturation[i] <- config.saturationControlPoints[i]
        }
        for i in 0..<7 {
             hsvCurves.value[i] <- config.valueControlPoints[i]
        }
    }
    
    func updateConfig() {
        config.rgbAdjustment = curves.adjustment
        config.hsvAdjustment = hsvCurves.adjustment
        
        config.rControlPoints = curves.x.controlPoints
        config.gControlPoints = curves.y.controlPoints
        config.gControlPoints = curves.x.controlPoints
        config.wControlPoints = curves.w.controlPoints
        
        for i in 0..<7 {
            config.hueControlPoints[i] = hsvCurves.hue[i].controlPoints
        }
        for i in 0..<7 {
            config.saturationControlPoints[i] = hsvCurves.saturation[i].controlPoints
        }
        for i in 0..<7 {
            config.valueControlPoints[i] = hsvCurves.value[i].controlPoints
        }
    }
    
    func saveConfig(){
        if let key = configKey {
            let json =  Mapper().toJSONString(config, prettyPrint: true)
            NSUserDefaults.standardUserDefaults().setValue(json, forKey: key)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    lazy var config = IMTLConfig()
}

public extension NSRect {
    mutating func setRegion(region:IMPRegion){
        let x = region.left.cgfloat*size.width
        let y = region.top.cgfloat*size.height
        self = NSRect(x: origin.x+x,
                      y: origin.y+y,
                      width: size.width*(1-region.right.cgfloat)-x,
                      height: size.height*(1-region.bottom.cgfloat)-y)
    }
}

public func == (left:NSPoint, right:NSPoint) -> Bool{
    return left.x==right.x && left.y==right.y
}

public func != (left:NSPoint, right:NSPoint) -> Bool{
    return !(left==right)
}

public func - (left:NSPoint, right:NSPoint) -> NSPoint {
    return NSPoint(x: left.x-right.x, y: left.y-right.y)
}

public func + (left:NSPoint, right:NSPoint) -> NSPoint {
    return NSPoint(x: left.x+right.x, y: left.y+right.y)
}

extension IMPJpegProvider {
    
    static func metadata(file:String) -> [String: AnyObject]?  {
        let url = NSURL(fileURLWithPath: file)
        
        guard let imageSrc = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            NSLog ("Error: file name : %@", file);
            return nil
        }
        
        let  meta = CGImageSourceCopyPropertiesAtIndex ( imageSrc, 0, nil ) as NSDictionary?
        
        guard let metadata = meta as? [String: AnyObject] else {
            NSLog ("Error: read meta : %@", file);
            return nil
        }
        
        return metadata
    }
}

/// https://github.com/Hearst-DD/ObjectMapper
///
///
public class IMTLConfig:Mappable {
    
    var rgbAdjustment = IMPAdjustment(blending: IMPBlending(mode: LUMINOSITY, opacity: 1))
    var hsvAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))

    var rgbFunction = IMPCurveFunction.Cubic
    var hsvFunction = IMPCurveFunction.Cubic

    var rControlPoints = [float2]([float2(0),float2(1)])
    var gControlPoints = [float2]([float2(0),float2(1)])
    var bControlPoints = [float2]([float2(0),float2(1)])
    var wControlPoints = [float2]([float2(0),float2(1)])
    
    var hueControlPoints        = [[float2]](count:7, repeatedValue:[float2]([float2(0),float2(1)]))
    var saturationControlPoints = [[float2]](count:7, repeatedValue:[float2]([float2(0),float2(1)]))
    var valueControlPoints      = [[float2]](count:7, repeatedValue:[float2]([float2(0),float2(1)]))
    
    public init(){}
    required public init?(_ map: Map) {}
    
    public func mapping(map: Map) {
        rgbAdjustment <- (map["rgbAdjustment"],transformAdjustment)
        hsvAdjustment <- (map["hsvAdjustment"],transformAdjustment)
        rgbFunction <- (map["rgbFunction"],transformFunction)
        hsvFunction <- (map["hsvFunction"],transformFunction)
        rControlPoints <- (map["rControlPoints"],transformPoints)
        gControlPoints <- (map["gControlPoints"],transformPoints)
        bControlPoints <- (map["bControlPoints"],transformPoints)
        wControlPoints <- (map["wControlPoints"],transformPoints)
        hueControlPoints <- (map["hueControlPoints"],transformPoints2)
        saturationControlPoints <- (map["saturationControlPoints"],transformPoints2)
        valueControlPoints <- (map["valueControlPoints"],transformPoints2)
    }
    
    
    let transformAdjustment = TransformOf<IMPAdjustment, [String:AnyObject]>(fromJSON: { (value: [String:AnyObject]?) -> IMPAdjustment? in
        
        if let value = value {
            let mode = value["mode"] as? NSNumber ?? NSNumber(unsignedInteger: 0)
            let opacity = value["opacity"] as? NSNumber ?? 1
            return IMPAdjustment(blending: IMPBlending(mode: IMPBlendingMode(rawValue:mode.unsignedIntValue), opacity: opacity.floatValue))
        }
        return nil
        }, toJSON: { (value: IMPAdjustment?) -> [String:AnyObject]? in
            if let adj = value {
                let json = [
                    "mode":  NSNumber(unsignedInt:adj.blending.mode.rawValue),
                    "opacity": adj.blending.opacity
                ]
                return json
            }
            return nil
    })

    let transformFunction = TransformOf<IMPCurveFunction, [String:String]>(fromJSON: { (value: [String:String]?) -> IMPCurveFunction? in
        
        if let f = value?["function"] {
            return IMPCurveFunction(rawValue:f)
        }
        return nil
        }, toJSON: { (value: IMPCurveFunction?) -> [String:String]? in
            if let v = value?.rawValue {
                let json = [
                    "function":  v
                ]
                return json
            }
            return nil
    })

    let transformPoints = TransformOf<[float2], [[Float]]>(fromJSON: { (value: [[Float]]?) -> [float2]? in
        if let value = value {
            var points = [float2]()
            for p in value {
                points.append(float2(p[0],p[1]))
            }
            return points
        }
        return nil
        }, toJSON: { (value: [float2]?) -> [[Float]]? in
            if let value = value {
                var json = [[Float]]()
                for p in value{
                    json.append([p.x,p.y])
                }
                return json
            }
            return nil
    })
    
    let transformPoints2 = TransformOf<[[float2]], [[[Float]]]>(fromJSON: { (value: [[[Float]]]?) -> [[float2]]? in
        if let value = value {
            var points = [[float2]](count:7, repeatedValue:[float2]())
            for i in 0..<7{
                for p in value[i] {
                    points[i].append(float2(p[0],p[1]))
                }
            }
            return points
        }
        return nil
        }, toJSON: { (value: [[float2]]?) -> [[[Float]]]? in
            if let value = value {
                var json = [[[Float]]](count:7, repeatedValue:[[Float]]())
                for i in 0..<7{
                    for p in value[i] {
                        json[i].append([p.x,p.y])
                    }
                }
                return json
            }
            return nil
    })


}



