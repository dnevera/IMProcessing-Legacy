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
//            cannyEdgeDetector.blurRadius = blurRadius
            dirty = true
        }
    }
    
    public var inputEV:Float = 0 {
        didSet{
            dirty = true
        }
    }

    public var contrastLevel:Float = 0 {
        didSet{
            ciContrast.setValue(contrastLevel, forKey: "inputContrast")
            dirty = true
        }
    }
    public var opening:Float = 0 {
        didSet{
            erosion.dimensions = (Int(opening),Int(opening))
            dilation.dimensions = (Int(opening),Int(opening))
            dirty = true
        }
    }

    public var levels:Float = 0 {
        didSet{
            posterize.levels = levels
            dirty = true
        }
    }

    public var medianDim:Float = 0 {
        didSet{
            median.dimensions = Int(medianDim)
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
        
        add(function: kernelEV)
        add(filter: blurFilter)
        add(filter: ciContrast)

        add(filter: median)
        add(filter: dilation)
        add(filter: erosion)
//        add(filter: posterize)

//        add(filter: houghLineDetector)
        
        add(filter: harrisCornerDetector)
        //add(filter: cannyEdgeDetector)
        
        var t1 = Date()
        var t2 = Date()
        
        addObserver(destinationUpdated: { (source) in
//            self.harrisCornerDetector.context.runOperation(.async) {
//                t1 = Date()
//                self.harrisCornerDetector.source = source
//            }
//            self.houghLineDetector.context.runOperation(.async) {
//                t2 = Date()
//                self.houghLineDetector.source = source
//            }
        })

//        harrisCornerDetector.addObserver { (corners:[float2], size:NSSize) in
//            self.context.runOperation(.async) {
//                self.cornersHandler?(corners,size)
//                
//                let hough = IMPHoughSpace(points: corners, width: Int(size.width), height: Int(size.height))
//                let lines = hough.getLines(linesMax: 50, threshold: 150)
//                
//                let p1lines = [IMPLineSegment](lines)
//                var linesout = [IMPLineSegment]()
//
//                let squares = hough.getSquares(squaresMax: 50, threshold: 20)
//                
////                for l in lines {
////                    for p in p1lines {
////                        if (p != l) && l.isParallel(toLine: p) && p.distanceTo(parallelLine: l) > (1/size.width * 50).float {
////                            print(" p = \(p,l)")
////                            linesout.append(p)
////                        }
////                    }
////                }
////                
////                self.linesHandler?(linesout,size)
////                print(" corners[n:\(corners.count)] detector time = \(-t1.timeIntervalSinceNow) ")
//            }
//        }
//
//        houghLineDetector.addObserver { (lines, size) in
//            self.context.runOperation(.async) {
//                self.linesHandler?(lines,size)
//                print(" lines[n:\(lines.count)] detector time = \(-t2.timeIntervalSinceNow) ")
//            }
//        }
    }
    
    lazy var posterize:IMPPosterize = IMPPosterize(context: self.context)
    
    lazy var median:IMPTwoPassMedian = IMPTwoPassMedian(context: self.context)

    lazy var erosion:IMPMorphology = IMPErosion(context: self.context)
    lazy var dilation:IMPMorphology = IMPDilation(context: self.context)
    
    lazy var cannyEdgeDetector:IMPCannyEdgeDetector = IMPCannyEdgeDetector(context: self.context)
    
    lazy var houghLineDetector:IMPHoughLinesDetector = IMPHoughLinesDetector(context:  IMPContext(), filtering:.edges)
    lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())

    lazy var crosshairGenerator:IMPCrosshairsGenerator = IMPCrosshairsGenerator(context: self.context)

    lazy var ciExposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    lazy var ciContrast:CIFilter = CIFilter(name:"CIColorControls")!

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
                  color:NSColor = NSColor(red: 1,   green: 1, blue: 0.1, alpha: 1),
                  width:CGFloat = 2
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
                  color:NSColor = NSColor(red: 0,   green: 1, blue: 0.3, alpha: 1),
                  width:CGFloat = 20,
                  thickness:CGFloat = 4
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
        
        let evSlider = NSSlider(value: 0, minValue: -3, maxValue: 3, target: self, action: #selector(sliderHandler(sender:)))
        evSlider.floatValue = 0
        evSlider.tag = 101
        
        view.addSubview(evSlider)
        
        evSlider.snp.makeConstraints { (make) in
            make.left.equalTo(blurSlider.snp.right).offset(20)
            make.bottom.equalTo(evSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        let openingSlider = NSSlider(value: 0, minValue: 0, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
        openingSlider.floatValue = 0
        openingSlider.tag = 102
        
        view.addSubview(openingSlider)
        
        openingSlider.snp.makeConstraints { (make) in
            make.left.equalTo(evSlider.snp.right).offset(20)
            make.bottom.equalTo(openingSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        
        let posterizeSlider = NSSlider(value: 0, minValue: 4, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
        posterizeSlider.floatValue = 0
        posterizeSlider.tag = 103
        
        view.addSubview(posterizeSlider)
        
        posterizeSlider.snp.makeConstraints { (make) in
            make.left.equalTo(openingSlider.snp.right).offset(20)
            make.bottom.equalTo(posterizeSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        let contrastSlider = NSSlider(value: 0, minValue: 0, maxValue: 10, target: self, action: #selector(sliderHandler(sender:)))
        contrastSlider.floatValue = 0
        contrastSlider.tag = 104
        
        view.addSubview(contrastSlider)
        
        contrastSlider.snp.makeConstraints { (make) in
            make.left.equalTo(posterizeSlider.snp.right).offset(20)
            make.bottom.equalTo(contrastSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        
        let medianSlider = NSSlider(value: 3, minValue: 3, maxValue: 16, target: self, action: #selector(sliderHandler(sender:)))
        medianSlider.floatValue = 0
        medianSlider.tag = 105
        
        view.addSubview(medianSlider)
        
        medianSlider.snp.makeConstraints { (make) in
            make.left.equalTo(contrastSlider.snp.right).offset(20)
            make.bottom.equalTo(medianSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }
        

        
        IMPFileManager.sharedInstance.add { (file, type) in
            self.currentImage = IMPImage(context: self.context, path: file, maxSize: 1000)
            NSLog("open file \(file)")
            self.filter.source = self.currentImage
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
                self.filter.inputEV = sender.floatValue
            case 102:
                self.filter.opening = sender.floatValue
            case 103:
                self.filter.levels = sender.floatValue
            case 104:
                self.filter.contrastLevel = sender.floatValue
            case 105:
                self.filter.medianDim = sender.floatValue
            default:
                break
            }
        }
        
        print("  slider v = \(sender.floatValue, sender.tag)")
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

