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
    
    public var linesHandler:((_ lines:[IMPLineSegment], _ size:NSSize?)->Void)?
    public var cornersHandler:((_ points:[float2], _ size:NSSize?)->Void)?
    
    public override var source: IMPImageProvider? {
        didSet{
            print(" source = \(source?.size)")
            self.linesHandler?([],source?.size)
            self.cornersHandler?([],source?.size)
        }
    }
    
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
        
//        harrisCornerDetectorOverlay.enabled = false
        
//        add(filter:harrisCornerDetectorOverlay)

//        add(function: kernelRed)
//        add(function: kernelEV)
        add(filter: exposureFilter)
//        add(filter: blurFilter)
//        add(filter: ciBlurFilter)

//        add(filter: houghLineDetector)

        var t1 = Date()
        var t2 = Date()
        
        addObserver(destinationUpdated: { (source) in
            self.harrisCornerDetector.context.runOperation(.async) {
                t1 = Date()
                self.harrisCornerDetector.source = source
            }
            self.houghLineDetector.context.runOperation(.async) {
                t2 = Date()
                self.houghLineDetector.source = source
            }
        })

        harrisCornerDetector.addObserver { (corners:[float2], size:NSSize) in
            self.context.runOperation(.async) {
                self.cornersHandler?(corners,size)
                print(" corners[n:\(corners.count)] detector time = \(-t1.timeIntervalSinceNow) ")
            }
        }

        houghLineDetector.addObserver { (lines, size) in
            self.context.runOperation(.async) {
                self.linesHandler?(lines,size)
                print(" lines[n:\(lines.count)] detector time = \(-t2.timeIntervalSinceNow) ")
                //for l in lines {
                //    print(l)
                //}
            }
        }
    }
    
    lazy var exposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    lazy var cannyEdgeDetector:IMPCannyEdgeDetector = IMPCannyEdgeDetector(context: self.context)
    
    lazy var houghLineDetector:IMPHoughLinesDetector = IMPHoughLinesDetector(context:  IMPContext())
    lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())

    lazy var crosshairGenerator:IMPCrosshairsGenerator = IMPCrosshairsGenerator(context: self.context)

}

class CanvasView: NSView {
    
    var lines = [IMPLineSegment]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    var corners = [float2]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    
    func drawLine(segment:IMPLineSegment,
                  color:NSColor = NSColor(red: 0,   green: 1, blue: 1, alpha: 0.6),
                  width:CGFloat = 1
                  ){
        let path = NSBezierPath()
        
        let fillColor = color
        
        fillColor.set()
        path.fill()
        path.lineWidth = width
        
        let p0 = NSPoint(x: segment.p0.x.cgfloat * bounds.size.width,
                         y: (1-segment.p0.y.cgfloat) * bounds.size.height)

        let p1 = NSPoint(x: segment.p1.x.cgfloat * bounds.size.width,
                         y: (1-segment.p1.y.cgfloat) * bounds.size.height)

        path.move(to: p0)
        path.line(to: p1)

        path.stroke()
    }
    
    func drawCrosshair(point:float2,
                  color:NSColor = NSColor(red: 0,   green: 1, blue: 0, alpha: 1),
                  width:CGFloat = 10,
                  thickness:CGFloat = 2
        ){
        let w  = (width/bounds.size.width/2).float
        let h  = (width/bounds.size.height/2).float
        let p0 = float2(point.x-w, point.y)
        let p1 = float2(point.x+w, point.y)
        let p10 = float2(point.x, point.y-h)
        let p11 = float2(point.x, point.y+h)
        
        let segment1 = IMPLineSegment(p0: p0, p1: p1)
        let segment2 = IMPLineSegment(p0: p10, p1: p11)
        
        drawLine(segment: segment1, color: color, width: thickness)
        drawLine(segment: segment2, color: color, width: thickness)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        for s in lines {
            drawLine(segment: s)
        }
        
        for c in corners {
            drawCrosshair(point: c)
        }
    }
}

class ViewController: NSViewController {

    lazy var filter:TestFilter = {
        let f = TestFilter(context: self.context)
        f.linesHandler = { (lines,size) in
            DispatchQueue.main.async {
                self.canvas.lines = lines
            }
        }
        f.cornersHandler = { (points,size) in
            DispatchQueue.main.async {
                self.canvas.corners = points
            }
        }
        return f
    }()
    
    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))

    var context:IMPContext = IMPContext(lazy:false)
    var currentImage:IMPImageProvider? = nil
    
    var canvas = CanvasView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        imageView.exactResolutionEnabled = false
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        view.addSubview(imageView)
        imageView.addSubview(canvas)
        
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.clear.cgColor
        canvas.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
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
        
        
        let tap1 = NSPressGestureRecognizer(target: self, action: #selector(clickHandler(gesture:)))
        tap1.minimumPressDuration = 0.01
        tap1.buttonMask = 1
        imageView.addGestureRecognizer(tap1)

        let tap2 = NSPressGestureRecognizer(target: self, action: #selector(clickHandler(gesture:)))
        tap2.minimumPressDuration = 0.01
        tap2.buttonMask = 1<<1
        imageView.addGestureRecognizer(tap2)

    }

    func clickHandler(gesture:NSClickGestureRecognizer)  {
        
        if  gesture.buttonMask == 1 {
            
            print("1 clickHandler state = \(gesture.state.rawValue)")
            
            switch gesture.state {
            case .began:
                filter.enabled = false
            default:
                filter.enabled = true
                break
            }
            
        }
        else if gesture.buttonMask == 1<<1 {
           
            print("2 clickHandler state = \(gesture.state.rawValue)")

//            switch gesture.state {
//            case .began:
//                filter.harrisCornerDetectorOverlay.enabled = false
//            default:
//                filter.harrisCornerDetectorOverlay.enabled = true
//                
//                break
//            }
            
            
            filter.dirty = true
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
                //self.filter.inputEV = sender.floatValue
                self.filter.ci_inputEV = sender.floatValue
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

