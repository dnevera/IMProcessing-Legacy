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
    
    lazy var curves:IMPXYZCurvesFilter = {
        let c = IMPRGBCurvesFilter(context: self.context)
        return c
    }()
    
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        
        f.addFilter(self.curves)
        
        return f
    }()
    
    lazy var imageView:IMPImageView = {
        let v = IMPImageView(context: self.context, frame: self.view.bounds)
        v.filter = self.filter
        v.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        return v
    }()
    
    lazy var curvesControl:IMPRGBCurvesControl = {
        let v = IMPRGBCurvesControl(frame: self.view.bounds)
        
        v.backgroundColor = IMPColor(color: IMPPrefs.colors.background)
        v.curvesView.curveFunction = .Cubic
        v.curvesView.didCurveFunctionUpdate = { (function) -> Void in
            self.curves.curveFunction = function
        }
        
        v.curvesView.didControlPointsUpdate = { (info) in
            
            if let t = IMPCurvesRGBChannelType(rawValue: info.id){
                
                guard let spline = info.spline else { return }
                
                switch  t {

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
        }
        
        v.autoCorrection = { () -> [(low:float2,high:float2)] in
            return self.computeRanges()
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
        v.generatorLayer.separatorWidth = 3
        v.generatorLayer.sample = false
        
        v.type = .PDF
        v.visibleBins = 40
        
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
                //
                // Загружаем файл и связываем источником фильтра
                //
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
                if let image = loadImage(file, size: 0) {
                    
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
        
        rightPanel.addSubview(curvesControl)
        curvesControl.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.rightPanel.snp_top).offset(10)
            make.left.equalTo(self.rightPanel).offset(5)
            make.right.equalTo(self.rightPanel).offset(-5)
            make.height.equalTo(200)
        }

        rightPanel.addSubview(histogramView)
        histogramView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.curvesControl.snp_bottom).offset(20)
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
        
    }
    
    func updateConfig() {
    }
    
    func saveConfig(){
        if let key = self.configKey {
            let json =  Mapper().toJSONString(config, prettyPrint: true)
            NSUserDefaults.standardUserDefaults().setValue(json, forKey: key)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    lazy var config = IMTLConfig()
}

///
/// Всякие полезные и в целом понятные уитилитарные расширения
///


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
/// Мапинг объектов в JSON для сохранения контекста редактирования файла, просто для удобства
///
public class IMTLConfig:Mappable {
    public init(){}
    required public init?(_ map: Map) {
    }
    public func mapping(map: Map) {
    }
}



