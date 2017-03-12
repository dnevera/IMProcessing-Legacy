//
//  ViewController.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 06.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import SnapKit

public class TestFilter: IMPFilter {
    
    lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    
    public var blurRadius:Float = 0 {
        didSet{
            blurFilter.radius = blurRadius
            cannyEdgeDetector.blurRadius = blurRadius
            dirty = true
        }
    }
    
    public var ciBlurRadius:Float = 0 {
        didSet{
            ciBlurFilter.setValue(NSNumber(value:ciBlurRadius), forKey: "inputRadius")
            cannyEdgeDetector.maxSize = CGFloat(400 * ciBlurRadius)
            dirty = true
        }
    }
    
    public var inputEV:Float = 0 {
        didSet{
            print("exposure MTL EV = \(inputEV)")
            print("exposure CI EV = \(ci_inputEV)")
            dirty = true
        }
    }
    
    public var ci_inputEV:Float = 0 {
        didSet{
            exposureFilter.setValue(ci_inputEV, forKey: "inputEV")
            print("exposure MTL EV = \(inputEV)")
            print("exposure CI EV = \(ci_inputEV)")
            dirty = true
        }
    }
    
    public var redAmount:Float = 1 {
        didSet{
            dirty = true
        }
    }
    
    lazy var kernelRedBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    lazy var kernelRed:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_red")
        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            var value  = self.redAmount
            var buffer = self.kernelRedBuffer
            memcpy(buffer.contents(), &value, buffer.length)
            commandEncoder.setBuffer(buffer, offset: 0, at: 0)
        }
        return f
    }()
    
    lazy var kernelEVBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    lazy var kernelEV:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_EV")
        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            var value  = self.inputEV
            var buffer = self.kernelEVBuffer
            memcpy(buffer.contents(), &value, buffer.length)
            commandEncoder.setBuffer(buffer, offset: 0, at: 0)
        }
        return f
    }()
    
    override public func configure() {
        extendName(suffix: "Test filter")
        super.configure()
        
//        add(function: kernelRed)
//        add(function: kernelEV)
//        add(filter: exposureFilter)
//        add(filter: blurFilter)
//        add(filter: ciBlurFilter)
        
        var t1 = Date()
        
        addObserver(newSource: { (source) in
            self.context.runOperation(.async) {
                t1 = Date()
                self.houghLineDetector.source = source
                self.harrisCornerDetector.source = source
            }
        })
        
        harrisCornerDetector.addObserver { (corners:[float2], size:NSSize) in
            self.context.runOperation(.async) {
                self.crosshairGenerator.points = corners
                self.dirty = true
                print(" corners detector time = \(-t1.timeIntervalSinceNow) ")
            }
        }

        houghLineDetector.addObserver { (lines, size) in
            self.context.runOperation(.async) {
                self.linesGenerator.lines = lines
                self.dirty = true
                print(" lines detector time = \(-t1.timeIntervalSinceNow) ")
            }
        }
        
        var lines = [IMPLineSegment]()
        
        lines.append(IMPLineSegment(p0: float2(0,0.25), p1: float2(1,0.25)))
        lines.append(IMPLineSegment(p0: float2(0,0.5), p1: float2(1,0.5)))
        lines.append(IMPLineSegment(p0: float2(0,0.75), p1: float2(1,0.75)))
        
        linesGenerator.lines = lines
        
        //add(filter: linesGenerator)
        add(filter: crosshairGenerator)

//        addObserver(newSource: { (source) in
//            self.context.runOperation(.async) {
//                self.houghLineDetector.source = source
//            }
//        })
        
    }
    
    private lazy var exposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    private lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    
    private lazy var houghLineDetector:IMPHoughLinesDetector = IMPHoughLinesDetector(context: self.context)
    private lazy var cannyEdgeDetector:IMPCannyEdgeDetector = IMPCannyEdgeDetector(context: self.context)
    private lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context: self.context /*IMPContext(lazy: false)*/)

    private lazy var crosshairGenerator:IMPCrosshairsGenerator = IMPCrosshairsGenerator(context: self.context)
    private lazy var linesGenerator:IMPLinesGenerator = IMPLinesGenerator(context: self.context)

}

class ViewController: NSViewController {

    lazy var filter:TestFilter = TestFilter(context: self.context)
    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))

    var context:IMPContext = IMPContext(lazy:true)
    var currentImage:IMPImageProvider? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        imageView.exactResolutionEnabled = true
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        view.addSubview(imageView)
        
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.superview!).offset(0)
            make.right.equalTo(imageView.superview!).offset(0)
            make.top.equalTo(imageView.superview!).offset(0)
            make.bottom.equalTo(imageView.superview!).offset(-80)
        }
        
        let blurSlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: self, action: #selector(sliderHandler(sender:)))
        blurSlider.tag = 100
        
        view.addSubview(blurSlider)
        
        blurSlider.snp.makeConstraints { (make) in
            make.left.equalTo(blurSlider.superview!).offset(20)
            make.bottom.equalTo(blurSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }
        
        let ciBlurSlider = NSSlider(value: 0, minValue: 0, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
        ciBlurSlider.floatValue = 0
        ciBlurSlider.tag = 101
        
        view.addSubview(ciBlurSlider)
        
        ciBlurSlider.snp.makeConstraints { (make) in
            make.left.equalTo(blurSlider.snp.right).offset(20)
            make.bottom.equalTo(ciBlurSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        let evSlider = NSSlider(value: 0, minValue: -3, maxValue: 3, target: self, action: #selector(sliderHandler(sender:)))
        evSlider.floatValue = 0
        evSlider.tag = 102
        
        view.addSubview(evSlider)
        
        evSlider.snp.makeConstraints { (make) in
            make.left.equalTo(ciBlurSlider.snp.right).offset(20)
            make.bottom.equalTo(evSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        
        IMPFileManager.sharedInstance.add { (file, type) in
            if let im = NSImage(contentsOfFile: file) {
                //self.currentImage = IMPImage(context: self.context, path: file)
                self.currentImage = IMPImage(context: self.context, image: im)
                NSLog("open file \(file)")
                self.filter.source = self.currentImage
            }
        }
        
    }

    func sliderHandler(sender:NSSlider)  {
        filter.context.runOperation(.async) {
            switch sender.tag {
            case 100:
                self.filter.blurRadius = sender.floatValue
            case 101:
                self.filter.ciBlurRadius = sender.floatValue
            case 102:
                self.filter.inputEV = sender.floatValue
            default:
                break
            }
        }
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

