//
//  ViewController.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 06.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import SnapKit
import Accelerate

public class TestFilter: IMPFilter {
    
    public var linesHandler:((_ h:[IMPPolarLine],_ v:[IMPPolarLine], _ size:NSSize?)->Void)?
    public var cornersHandler:((_ points:[IMPCorner], _ size:NSSize?)->Void)?
    
    public override var source: IMPImageProvider? {
        didSet{
            print(" source = \(source?.size)")
            self.linesHandler?([],[],source?.size)
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
            lineDetector.radius = Int(opening)
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
    
    override public func configure(complete:CompleteHandler?=nil) {
        extendName(suffix: "Test filter")
        super.configure()
        
        var t1 = Date()
        var t2 = Date()

        
//        add(filter: segments)
        
//        add(filter: median)

//        add(function: kernelEV)
//        add(filter: blurFilter)
//        add(filter: ciContrast)

//        add(filter: posterize)

        
//        add(filter: dilation)
        add(filter: erosion)

//        add(filter: edgels)

//        add(filter:gDerivativeEdges)
//        add(filter:sobelEdges)
        
//        add(filter: lineDetector)
        
//        add(filter: harrisCornerDetector)
        
//        cornersDetector.addObserver(newSource: { (source) in
//            t1 = Date()
//        })
        
//        add(filter: cornersDetector)
        
//        add(filter: cannyEdgeDetector)
        
        
        addObserver(destinationUpdated: { (source) in
//            self.cornersDetector.context.runOperation(.async) {
//                t1 = Date()
//                self.cornersDetector.source = source
//            }

            self.harrisCornerDetector.context.runOperation(.async) {
                t1 = Date()
                self.harrisCornerDetector.source = source
            }
            
//            self.houghLineDetector.context.runOperation(.async) {
//                t2 = Date()
//                self.houghLineDetector.source = source
//            }
            
//            self.lineDetector.context.runOperation(.async) {
//                t2 = Date()
//                self.lineDetector.source = source
//            }
            
        })

        
        cornersDetector.addObserver { (corners:[IMPCorner], size:NSSize) in
            self.context.runOperation(.async) {
                print(" corners[n:\(corners.count)] detector time = \(-t1.timeIntervalSinceNow) ")
                self.cornersHandler?(corners,size)
            }
        }

        harrisCornerDetector.addObserver { (corners:[IMPCorner], size:NSSize) in
            self.context.runOperation(.async) {
                print(" corners[n:\(corners.count)] detector time = \(-t1.timeIntervalSinceNow) ")
                self.cornersHandler?(corners,size)
            }
        }

//        lineDetector.addObserver(lines: { (horisontal, vertical, size) in
//            self.context.runOperation(.async) {
//                print(" lines[n:\(horisontal.count, vertical.count)] detector time = \(-t2.timeIntervalSinceNow) ")
//
//                //let quads = self.squaresDetector(horizontalLines: horsontal, verticalLines: horsontal, size: size)
//                
//                //let cartezianH  = IMPLineSegment(line: horsontal, size: size)
//                //let cartezianV  = IMPLineSegment(line: vertical, size: size)
//                
//                let h = self.filterByDensity(lines: horisontal, theta: M_PI_2.float, size: Int(size.width), count: 16)
//                let v = self.filterByDensity(lines: vertical, theta: 0, size: Int(size.height), count: 16)
//                
//                self.linesHandler?(horisontal, vertical, size)
//            }
//        })
//        
//        houghLineDetector.addObserver(lines: { (lines, size) in
//            self.context.runOperation(.async) {
//                print(" lines[n:\(lines.count)] detector time = \(-t2.timeIntervalSinceNow) ")
//                self.linesHandler?(lines, [], size)
//            }
//        })

    }
    
    lazy var segments:IMPSegmentsDetector = IMPSegmentsDetector(context: self.context)
    
    lazy var gDerivativeEdges:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    lazy var sobelEdges:IMPSobelEdges = IMPSobelEdges(context: self.context)
    
    lazy var edgels:IMPEdgelsDetector = IMPEdgelsDetector(context: self.context)
    
    lazy var posterize:IMPPosterize = IMPPosterize(context: self.context)
    
    lazy var median:IMPTwoPassMedian = IMPTwoPassMedian(context: self.context)

    lazy var erosion:IMPMorphology = IMPErosion(context: self.context)
    lazy var dilation:IMPMorphology = IMPDilation(context: self.context)
    
    lazy var cannyEdgeDetector:IMPCannyEdges = IMPCannyEdges(context: self.context)
    
    lazy var lineDetector:IMPLinesDetector = IMPLinesDetector(context:  IMPContext())

    lazy var houghLineDetector:IMPHoughLinesDetector = IMPHoughLinesDetector(context:  IMPContext(), filtering:.edges)
    lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())

    lazy var cornersDetector:IMPCornersDetector = IMPCornersDetector(context: self.context)
    
    lazy var crosshairGenerator:IMPCrosshairsGenerator = IMPCrosshairsGenerator(context: self.context)

    lazy var ciExposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    lazy var ciContrast:CIFilter = CIFilter(name:"CIColorControls")!
    
    
    
    
    func filterByDensity(lines:[IMPPolarLine], theta:Float, size:Int, count:Int = 8) -> [IMPPolarLine] {
        
        let horizontalLines = lines.sorted { return  $0.rho<$1.rho }
        
        var densityKernel = size/count
        var density = [Int: [Float]]()
        
        for p in horizontalLines {
            let di = Int(floor(p.rho/densityKernel.float))
            
            if density[di] == nil {
                density[di] = [Float]() //float3(0,MAXFLOAT,0)
            }
            density[di]!.append(p.rho)
        }
        
        var result = [IMPPolarLine]()
        for k in density.keys.sorted() {
            guard let d = density[k] else { continue }

            if d.count > 1 {
                var mean:Float = 0
                var sigma:Float = 0
                let median = d.count/2
                vDSP_normalize(d, 1, nil, 0, &mean, &sigma, vDSP_Length(d.count))
                print(" d[\(k)] = \(d) mean = \(mean) sigma = \(sigma)")
                //result.append(IMPPolarLine(rho: mean -  sign(mean) * sigma, theta: theta))
                //result.append(IMPPolarLine(rho: mean + sign(mean) * sigma, theta: theta))
                result.append(IMPPolarLine(rho: d[median], theta: theta))
                //result.append(IMPPolarLine(rho: mean, theta: theta))
            }
        }
        
        return result
    }
    
    func squaresDetector(horizontalLines:[IMPPolarLine],verticalLines:[IMPPolarLine], size:NSSize) -> [IMPQuad] {
        var quads = [IMPQuad]()
        return quads
    }
}

class CanvasView: NSView {
    
    var hlines = [IMPLineSegment]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    var vlines = [IMPLineSegment]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    var corners = [IMPCorner]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    
    func drawLine(segment:IMPLineSegment,
                  color:NSColor,
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
        
        path.close()
    }
    
    func drawCrosshair(corner:IMPCorner,
                  color:NSColor = NSColor(red: 0,   green: 1, blue: 0.2, alpha: 1),
                  width:CGFloat = 50,
                  thickness:CGFloat = 2
        ){
        
        //NSLog("corner = \(corner)")
        
        let slops = corner.slops
        
        let w  = (width/bounds.size.width/2).float
        let h  = (width/bounds.size.height/2).float
        let p0 = float2(corner.point.x-w * slops.x, corner.point.y)
        let p1 = float2(corner.point.x+w * slops.w, corner.point.y)
        let p10 = float2(corner.point.x, corner.point.y-h * slops.y)
        let p11 = float2(corner.point.x, corner.point.y+h * slops.z)
        
        let segment1 = IMPLineSegment(p0: p0, p1: p1)
        let segment2 = IMPLineSegment(p0: p10, p1: p11)
        
        drawLine(segment: segment1, color: color, width: thickness)
        drawLine(segment: segment2, color: color, width: thickness)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        for s in hlines {
            drawLine(segment: s, color:  NSColor(red: 0,   green: 0.9, blue: 0.1, alpha: 1))
        }
        
        for s in vlines {
            drawLine(segment: s, color: NSColor(red: 0,   green: 0.1, blue: 0.9, alpha: 1))
        }
        
        for c in corners {
            drawCrosshair(corner: c)
        }
    }
}

class ViewController: NSViewController {

    lazy var filter:TestFilter = {
        let f = TestFilter(context: self.context)
        
        f.linesHandler = { (h, v, size) in
            DispatchQueue.main.async {
                var hh = [IMPLineSegment]()
                for i in h {
                    hh.append(IMPLineSegment(line:i,size:size!))
                }
                var vv = [IMPLineSegment]()
                for i in v {
                    vv.append(IMPLineSegment(line:i,size:size!))
                }
                self.canvas.hlines = hh
                self.canvas.vlines = vv
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
            self.currentImage = IMPImage(context: self.context, path: file, maxSize: 2000)
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

