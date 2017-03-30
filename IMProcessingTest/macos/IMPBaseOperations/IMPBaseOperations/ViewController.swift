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


extension IMPCorner: Equatable {
    
    public static func ==(lhs: IMPCorner, rhs: IMPCorner) -> Bool {
        return (abs(lhs.point.x-rhs.point.x) < 0.1) && (abs(lhs.point.y-rhs.point.y) < 0.1)
    }

    
    var left:float2  { return float2(-slops.x,0) }
    var top:float2   { return float2(0,slops.y)  }
    var right:float2 { return float2(slops.w,0)  }
    var bottom:float2{ return float2(0,-slops.z) }
    
    enum Direction:Int {
        case leftTop
        case rightTop
        case leftBottom
        case rightBottom
        case none
    }
    
    func normal(p0:float2,p1:float2) -> float2 {
        let s = IMPLineSegment(p0: p0, p1: p1)
        return s.normalIntersection(point: float2(0))
    }
    
    var ltSlope:float2 {get{ return normal(p0: left,  p1: top) }}
    var rtSlope:float2 {get{ return normal(p0: top,   p1: right) }}
    var rbSlope:float2 {get{ return normal(p0: right, p1: bottom) }}
    var lbSlope:float2 {get{ return normal(p0: left,  p1: bottom) }}
    
    var direction:float2 {
        //return ltSlope+rtSlope+rbSlope+lbSlope
        return left + top + right + bottom
    }

    var normalDirection:float2 {
        return ltSlope+rtSlope+rbSlope+lbSlope
    }

    func thresholdDirection(threshold:Float = 0.1) -> Direction {
        // x - left, y - top, z - bottom, w - right

        let d = direction
    
        if d.x>0 && d.y<0 && length(d)>=threshold {
            return .leftTop
        }
        if d.x<0 && d.y<0 && length(d)>=threshold {
            return .rightTop
        }
        if d.x<0 && d.y>0 && length(d)>=threshold {
            return .rightBottom
        }
        if d.x>0 && d.y>0 && length(d)>=threshold {
            return .leftBottom
        }
        
        return .none
    }
    
    func match(corner:IMPCorner, threshold:Float = 0.3) -> Direction {
        
        if thresholdDirection(threshold: threshold) == .leftTop {
            let d = corner.thresholdDirection(threshold: threshold)
            if d == .rightTop {
                return d
            }
            if d == .leftBottom {
                return d
            }
            if d == .rightBottom {
                return d
            }
        }
        
        return .none
    }
}

public class IMPPatch {
    
    let theta:Float
    
    public init(lt: IMPCorner, theta:Float = 0) {
        self.theta = theta
        defer{
            self.lt = lt
        }
    }
    
    func find(at place:IMPCorner.Direction, withIn corners: [IMPCorner], threshold:Float = 0.2) -> IMPCorner? {
        
        var dist:Float = 10000
        
        var next:IMPCorner?
        
        for c in corners{
            
            if c.thresholdDirection(threshold: threshold) == .leftTop { continue }

            let d = c.thresholdDirection(threshold: threshold)
            
            if d == place {
                let newDist = distance(lt.point, c.point)
                if dist > newDist {
                    next = c
                    dist = newDist
                }
            }
        }
        
        return next
    }
    
    var lt = IMPCorner() {didSet{ mask |= 0b1000  }}
    var rt = IMPCorner() {didSet{ mask |= 0b0100  }}
    var lb = IMPCorner() {didSet{ mask |= 0b0010  }}
    var rb = IMPCorner() {didSet{ mask |= 0b0001  }}

    var hasLt:Bool {
        return (mask & 0b1000) > 0
    }

    var hasRt:Bool {
        return (mask & 0b0100) > 0
    }

    var hasLb:Bool {
        return (mask & 0b0010) > 0
    }

    var hasRb:Bool {
        return (mask & 0b0001) > 0
    }

    var isCompleted:Bool { return (((mask % 0b1111) == 0) && mask>0) }
    var mask:UInt8 = 0b0000
    
    private func normalIntersection(_ x0:Float, _ y0:Float, _ x1:Float, _ y1:Float) -> float2 {
        let segment = IMPLineSegment(p0: float2(x0,y0), p1: float2(x1,y1))
        return segment.normalIntersection(point: lt.point)
    }
    
    private func thetaDiff(corner: IMPCorner, _ x0:Float, _ y0:Float, _ x1:Float, _ y1:Float) -> float2 {
        let n = normalIntersection(x0,y0,x1,y1)
        let a1 = n.y - corner.point.y
        let b1 = lt.point.x - n.x
        let a2 = n.x - corner.point.x
        let b2 = lt.point.y - n.y
        return float2(abs(atan(a1/b1)),abs(atan(a2/b2)))
    }
    
    func addCorner(corner:IMPCorner, threshold:Float = 0.2, thetaThreshold:Float = Float.pi/90) -> Bool {
        
        if isCompleted { return false }
        
        var ret = false
        
        switch corner.thresholdDirection(threshold: threshold) {
        case .leftTop:
            
            if (mask & 0b1000) == 0 { lt = corner; return true }
            
        case .rightTop:
            
            if abs(corner.point.y - lt.point.y)<=threshold{
                if (mask & 0b0100) == 0 {
                    rt = corner;
                    ret = true
                }
                else {
                    let newDist = distance(lt.point, corner.point)
                    if newDist < distance(lt.point, rt.point){
                        rt = corner;
                        ret = true
                    }
                }
            }
            
        case .leftBottom:
            if abs(corner.point.x - lt.point.x)<=threshold {
                if (mask & 0b0010) == 0 {
                    lb = corner;
                    ret = true
                }
                else {
                    let newDist = distance(lt.point, corner.point)
                    if newDist < distance(lt.point, lb.point){
                        lb = corner;
                        ret = true
                    }
                }
            }
        case .rightBottom:
            if abs(corner.point.x - rt.point.x)<=threshold {
                if (mask & 0b0001) == 0 {
                    rb = corner;
                    ret = true
                }
                else {
                    let newDist = distance(lt.point, corner.point)
                    if newDist < distance(lt.point, rb.point){
                        rb = corner;
                        ret = true
                    }
                }
            }
        default:
            ret = false
        }
        
        
        return ret
    }
}

public class TestFilter: IMPFilter {
    
    public var linesHandler:((_ h:[IMPPolarLine],_ v:[IMPPolarLine], _ size:NSSize?)->Void)?
    public var cornersHandler:((_ points:[IMPCorner], _ size:NSSize?)->Void)?
    public var patchesHandler:((_ points:[IMPPatch], _ size:NSSize?)->Void)?
    
    public override var source: IMPImageProvider? {
        didSet{
            self.linesHandler?([],[],source?.size)
            self.cornersHandler?([],source?.size)
            self.patchesHandler?([],source?.size)
        }
    }
    
    lazy var blurFilter:IMPGaussianBlur = IMPGaussianBlur(context: self.context)
    
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
            cornerLinesDetector.threshold =  Int(medianDim)
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
        
        levels = 8
        
        var t1 = Date()
        var t2 = Date()

        
//        add(filter: segments)
        
//        add(filter: median)
//
//        add(function: kernelEV)
//        add(filter: blurFilter)
//        add(filter: ciContrast)

        add(filter: posterize)
        
        add(filter: erosion)
        add(filter: dilation)

//        add(filter: cornerLinesDetector)
        
//        add(filter: edgels)
//        add(filter:gDerivativeEdges)
//        add(filter:sobelEdges)
//        add(filter: cannyEdgeDetector)
        
//        add(filter: lineDetector)
//        add(filter: harrisCornerDetector)
        
//        add(filter: houghLineDetector)
        
//        cornersDetector.addObserver(newSource: { (source) in
//            t1 = Date()
//        })
//        add(filter: cornersDetector)
        
        let resampler = IMPResampler(context:context)
        resampler.maxSize = 800
        
        lineDetector.threshold = 100
        
        addObserver(destinationUpdated: { (source) in
        
            resampler.source = source
            let dest = resampler.destination
            
            self.harrisCornerDetector.context.runOperation(.async) {
                t1 = Date()
                self.harrisCornerDetector.source = dest
            }
            
//            self.houghLineDetector.context.runOperation(.async) {
//                t2 = Date()
//                self.houghLineDetector.source = dest
//            }
            
            self.lineDetector.context.runOperation(.async) {
                t2 = Date()
                self.lineDetector.source = dest
            }
      
            
            self.cornerLinesDetector.context.runOperation(.async) {
                t2 = Date()
                self.cornerLinesDetector.source = dest
            }

        })

        
        harrisCornerDetector.addObserver { (corners:[IMPCorner], size:NSSize) in
            self.context.runOperation(.async) {
                print(" corners[n:\(corners.count)] detector time = \(-t1.timeIntervalSinceNow) ")

                let oppositThreshold:Float = 0.5
                let nonOrientedThreshold:Float = 0.4

                let filtered = corners.filter { (corner) -> Bool in
                    
                    var count = 0
                    for i in 0..<4 {
                        if corner.slops[i] >= nonOrientedThreshold{
                            count += 1
                        }
                    }
                    
                    if count > 2 {
                        return false
                    }
                    
                    if corner.slops.x>=oppositThreshold && corner.slops.y>=oppositThreshold {
                        return true
                    }
                    if corner.slops.y>=oppositThreshold && corner.slops.w>=oppositThreshold {
                        return true
                    }

                    if corner.slops.w>=oppositThreshold && corner.slops.z>=oppositThreshold {
                        return true
                    }

                    if corner.slops.z>=oppositThreshold && corner.slops.x>=oppositThreshold {
                        return true
                    }

                    return false
                }

                let w = Float(size.width)
                let h = Float(size.height)
                
                let prec:Float = 8
                
                let sorted = filtered.sorted { (c0, c1) -> Bool in
                    
                    var pi0 = c0.point * float2(w,h)
                    var pi1 = c1.point * float2(w,h)
                    
                    pi0 = floor(pi0/float2(prec)) * float2(prec)
                    pi1 = floor(pi1/float2(prec)) * float2(prec)
                    
                    let i0 = pi0.x  + pi0.y * w
                    let i1 = pi1.x  + pi1.y * w
                    
                    return i0<i1
                    //return  pi0.x < pi1.x || pi0.y < pi1.y ? true : i0<i1
                    
//                    var r0 = length(pi0)
//                    let a0 = pi0.y/pi0.x
//
//                    var r1 = length(pi1)
//                    let a1 = pi1.y/pi1.x
//                    
//                    let numrho = distance(float2(0), float2(w,h))
//                    
//                    let index0 = a0 * numrho + r0
//                    let index1 = a1 * numrho + r1
//
//                    //return distance(float2(0), pi0)<distance(float2(0), pi1)
//                    return index0<index1
                }
                
                var pp = [float2]()
                for c in filtered{
                    pp.append(c.point)
                }
                
                let hough = IMPHoughSpace(points: pp, width: Int(w), height: Int(h))
                let lines = hough.getLines()
                
                let patches = self.matchPatches(corners: sorted, size:size)
                
                self.cornersHandler?(sorted,size)
               self.patchesHandler?(patches,size)
                //self.linesHandler?(lines,[],size)
            }
        }

        lineDetector.addObserver(lines: { (horisontal, vertical, size) in
            self.context.runOperation(.async) {
                print(" oriented lines[n:\(horisontal.count, vertical.count)] detector time = \(-t2.timeIntervalSinceNow) ")

                //let quads = self.squaresDetector(horizontalLines: horsontal, verticalLines: horsontal, size: size)
                
                //let h = self.filterByDensity(lines: horisontal, theta: M_PI_2.float, size: Int(size.width), count: 16)
                //let v = self.filterByDensity(lines: vertical, theta: 0, size: Int(size.height), count: 16)
                
                self.linesHandler?(horisontal, vertical, size)
            }
        })
        
        cornerLinesDetector.addObserver(lines: { (horisontal, vertical, size) in
            self.context.runOperation(.async) {
                print(" corner lines[n:\(horisontal.count, vertical.count)] detector time = \(-t2.timeIntervalSinceNow) ")
                self.linesHandler?(horisontal, vertical, size)
            }
        })

        
        houghLineDetector.addObserver(lines: { (lines, size) in
            self.context.runOperation(.async) {
                print(" hough lines[n:\(lines.count)] detector time = \(-t2.timeIntervalSinceNow) ")
                self.linesHandler?(lines, [], size)
            }
        })
        
    
    }
    
    lazy var segments:IMPSegmentsDetector = IMPSegmentsDetector(context: self.context)
    
    lazy var gDerivativeEdges:IMPGaussianDerivativeEdges = IMPGaussianDerivativeEdges(context: self.context)
    //lazy var sobelEdges:IMPSobelEdges = IMPSobelEdges(context: self.context)
    lazy var sobelEdges:IMPSobelEdgesGradient = IMPSobelEdgesGradient(context: self.context)
    //lazy var sobelEdges:IMPSobelEdgesRasterized = IMPSobelEdgesRasterized(context: self.context)
    
    lazy var edgels:IMPEdgelsDetector = IMPEdgelsDetector(context: self.context)
    
    lazy var posterize:IMPPosterize = IMPPosterize(context: self.context)
    
    lazy var median:IMPTwoPassMedian = IMPTwoPassMedian(context: self.context)

    lazy var erosion:IMPMorphology = IMPErosion(context: self.context)
    lazy var dilation:IMPMorphology = IMPDilation(context: self.context)
    
    lazy var cannyEdgeDetector:IMPCannyEdges = IMPCannyEdges(context: self.context)
    
    lazy var lineDetector:IMPOrientedLinesDetector = IMPOrientedLinesDetector(context:  IMPContext())
    lazy var cornerLinesDetector:IMPCornerLinesDetector = IMPCornerLinesDetector(context:  IMPContext())

    lazy var houghLineDetector:IMPHoughLinesDetector = IMPHoughLinesDetector(context:  IMPContext())
    lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())
    
    lazy var crosshairGenerator:IMPCrosshairsGenerator = IMPCrosshairsGenerator(context: self.context)

    lazy var ciExposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    lazy var ciContrast:CIFilter = CIFilter(name:"CIColorControls")!
    
    func matchPatches(corners:[IMPCorner], size:NSSize) -> [IMPPatch] {
        var patches = [IMPPatch]()

        for (i,current) in corners.enumerated() {
            
            if current.thresholdDirection() != .leftTop { continue }
            
            let patch = IMPPatch(lt: current)
            
            if let next = patch.find(at: .rightTop, withIn: corners) {
                patch.rt = next
            }

            if let next = patch.find(at: .leftBottom, withIn: corners) {
                patch.lb = next
            }

            if let next = patch.find(at: .rightBottom, withIn: corners) {
                patch.rb = next
            }

//            for next in corners {
//                
//                if next == current { continue }
//                if next.thresholdDirection() == .leftTop { continue }
//                
//                if patch.addCorner(corner: next) {
//                    if patch.isCompleted { break }
//                }
//            }
            if patch.isCompleted {
                patches.append(patch)
            }
        }
        
        return patches
    }
    
    
    func matchPatches_(corners:[IMPCorner], size:NSSize) -> [IMPPatch] {
        
//        let w = Float(size.width)
//        let h = Float(size.height)
//        
//        let prec:Float = 16
//        
        var sorted = corners
        
//        var sorted = corners.sorted { (c0, c1) -> Bool in
//            
//            var pi0 = c0.point * float2(w,h)
//            var pi1 = c1.point * float2(w,h)
//            
//            pi0 = floor(pi0/float2(prec)) * float2(prec)
//            pi1 = floor(pi1/float2(prec)) * float2(prec)
//            
//            let i0 = pi0.x  + pi0.y * w
//            let i1 = pi1.x  + pi1.y * w
//            
//            return i0<i1
//        }
        
        var patches = [IMPPatch]()
    
        while sorted.count > 0 {
            
            let current = sorted.remove(at: 0)
            
//            if current.thresholdDirection() != .leftTop {
//                sorted.insert(current, at: 0)
//                continue
//            }
            
            let currentDirection = current.thresholdDirection()

            if currentDirection != .leftTop {
                continue
            }
            
            let patch = IMPPatch(lt:current)
            //if !patch.addCorner(corner: current, place: currentDirection) {
            //    continue
            //}
            
            for next in sorted {
                
                let place = current.match(corner: next)
                
                if place == .none {
                    continue
                }
                
                if patch.addCorner(corner: next) {
                    if patch.isCompleted {
                        patches.append(patch)
                        
                        sorted.removeObject(object: patch.lt)
                        sorted.removeObject(object: patch.rt)
                        sorted.removeObject(object: patch.lb)
                        sorted.removeObject(object: patch.rb)
                        
                        break
                    }
                }
                
            }
        }
        
//        for (i,p) in patches.enumerated() {
//            print("patch[\(i)] = \(p.lt.point, p.rt.point, p.lb.point, p.rb.point)")
//        }
        
        return patches
    }
    
    
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
    
    var patches = [IMPPatch]() {
        didSet{
            setNeedsDisplay(bounds)
        }
    }
    
    
    func drawLine(segment:IMPLineSegment,
                  color:NSColor,
                  width:CGFloat = 1.2
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
                  thickness:CGFloat = 4,
                  index:Int = -1
        ){
        
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
        if index >= 0 {
            
            let text = NSString(format: "[%i] %.2f,%.2f", index, corner.point.x, corner.point.y)
            //let text = "\(index): \(corner.point.x),\(corner.point.y)" as NSString
            let font = NSFont(name: "Helvetica Bold", size: 11.0)

            if let actualFont = font {

                
                let p0 = NSPoint(x: corner.point.x.cgfloat * bounds.size.width,
                                 y: (1-corner.point.y.cgfloat) * bounds.size.height)

                let textRect  = NSMakeRect(CGFloat(p0.x+4), CGFloat(p0.y-16), 100, 16)
                let textStyle = NSMutableParagraphStyle.default().mutableCopy() as! NSMutableParagraphStyle
                textStyle.alignment = .left
                
                let textColor = NSColor(red: 0,   green: 0, blue: 0, alpha: 1)

                let textFontAttributes = [
                    NSFontAttributeName: actualFont,
                    NSForegroundColorAttributeName: textColor,
                    NSParagraphStyleAttributeName: textStyle
                ]
                
                text.draw(in: NSOffsetRect(textRect, 0, 0), withAttributes: textFontAttributes)
            }
        }
    }
    
    func drawPatch(patch:IMPPatch,
                   color:NSColor = NSColor(red: 1, green: 1, blue: 0.2, alpha: 0.6),
                   thickness:CGFloat = 4
        ){
        
        drawLine(segment: IMPLineSegment(p0:patch.lt.point,p1:patch.rt.point), color: color, width: thickness)
        drawLine(segment: IMPLineSegment(p0:patch.rt.point,p1:patch.rb.point), color: color, width: thickness)
        drawLine(segment: IMPLineSegment(p0:patch.rb.point,p1:patch.lb.point), color: color, width: thickness)
        drawLine(segment: IMPLineSegment(p0:patch.lb.point,p1:patch.lt.point), color: color, width: thickness)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        for s in hlines {
            drawLine(segment: s, color:  NSColor(red: 0,   green: 0.9, blue: 0.1, alpha: 0.8))
        }
        
        for s in vlines {
            drawLine(segment: s, color: NSColor(red: 0,   green: 0.1, blue: 0.9, alpha: 0.8))
        }
        
        for (i,c) in corners.enumerated() {
            drawCrosshair(corner: c, index: i)
        }
        for p in patches {
            drawPatch(patch: p)
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
                    let segment = IMPLineSegment(line:i,size:size!)
                    hh.append(segment)
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
        
        f.patchesHandler = { (patches,size) in
            DispatchQueue.main.async {
                self.canvas.patches = patches
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

        
        let posterizeSlider = NSSlider(value: Double(filter.levels), minValue: 4, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
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

        
        let medianSlider = NSSlider(value: 50, minValue: 10, maxValue: 100, target: self, action: #selector(sliderHandler(sender:)))
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

