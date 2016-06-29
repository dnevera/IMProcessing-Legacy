//
//  IMPCurvesView.swift
//  ImageMetalling-14
//
//  Created by denis svinarchuk on 26.06.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Cocoa
import SnapKit
import IMProcessing
import simd

public func <- (left:IMPCurvesView, right:IMPCurvesView.CurveInfo) {
    left.add(right)
}

public func == (left: IMPCurvesView.CurveInfo, right: IMPCurvesView.CurveInfo) -> Bool {
    return left.id == right.id
}

public class IMPPopUpButton: NSPopUpButton {
    public var backgroundColor:IMPColor?
}

public class IMPCurvesView: IMPViewBase {
    
    public typealias ControlPointsUpdateHandler = ((CurveInfo:CurveInfo) -> Void)

    public var backgroundColor:IMPColor? = IMPColor.clearColor(){
        didSet{
            wantsLayer = true
            layer?.backgroundColor = backgroundColor?.CGColor
        }
    }
    
    public var markerSize:Float = 5 {
        didSet{
            needsDisplay = true
        }
    }
    
    public var lineWidth:Float = 1 {
        didSet{
            needsDisplay = true
        }
    }

    public var gridWidth:Float = 0.5 {
        didSet{
            needsDisplay = true
        }
    }

    public var gridColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3) {
        didSet{
            needsDisplay = true
        }
    }

    public var precision:Float = 0.05 {
        didSet{
            needsDisplay = true
        }
    }
    
    public var curveFunction:IMPCurveFunction = .Cubic {
        didSet{
            for l in list {
                l._spline = curveFunction.spline
            }
        }
    }
    
    public class CurveInfo: Equatable{
        
        public var spline:IMPSpline? {
            return _spline
        }
        
        public var id:String { return _id }
        public let name:String
        public let color:IMPColor
        public var controlPoints:[float2] {
            guard let s = _spline else { return [] }
            return s.controlPoints
        }
        
        public var isActive = false {
            didSet {
                view.needsDisplay = true
            }
        }
        
        public var _id:String
        public init (id: String, name: String, color: IMPColor) {
            self._id = id
            self.name = name
            self.color = color
        }
        
        public convenience init (name: String, color: IMPColor) {
            self.init(id: name, name: name, color: color)
        }
        
        var _spline:IMPSpline? {
            didSet {
                _spline?.addUpdateObserver({ (spline) in
                    self.view.needsDisplay = true
                })
            }
        }
        var view:IMPCurvesView! {
            didSet{
                _spline = view.curveFunction.spline
            }
        }
    }

    var list = [CurveInfo]()
    
    public subscript(id:String) -> CurveInfo? {
        get{
            let el = list.filter { (object) -> Bool in
                return object.id == id
            }
            if el.count > 0 {
                return el[0]
            }
            else {
                return nil
            }
        }
        set{
            if let index = (list.indexOf { (object) -> Bool in
                return object.id == id
                }) {
                if let v = newValue {
                    v.view = self
                    list[index] = v
                }
            }
            else {
                if let v = newValue {
                    v._id = id
                    v.view = self
                    list.append(v)
                }
                else {
                    let el = list.filter { (object) -> Bool in
                        return object.id == id
                    }
                    if el.count > 0 {
                        list.removeObject(el[0])
                    }
                }
            }
        }
    }
    
    public func add(info:CurveInfo) {
        self[info.id] = info
    }

    public var didControlPointsUpdate:ControlPointsUpdateHandler?

    var activeCurve:CurveInfo? {
        get {
            for i in list {
                if i.isActive {
                    return i
                }
            }
            return nil
        }
    }
    
    func covertPoint(event:NSEvent) -> float2 {
        let location = event.locationInWindow
        let point  = self.convertPoint(location,fromView:nil)
        return float2((point.x/bounds.size.width).float,(point.y/bounds.size.height).float)
    }
    
    var currentPoint:float2?
    var currentPointIndex:Int?
    
    override public func mouseDragged(event: NSEvent) {
        
        guard let cp = currentPoint else { return }

        let xy = covertPoint(event)

        if let curve = activeCurve {
            
            if let i = curve.spline?.indexOf(point: cp) {
                currentPointIndex = i
                currentPoint = xy
            }
            else if currentPointIndex != nil {
                currentPoint = xy
            }
    
            guard let index = currentPointIndex else { return }
            
            currentPoint = curve.spline?.set(point: xy, atIndex: index)
        }
    }
    
    override public func mouseDown(event: NSEvent) {
        let xy = covertPoint(event)
        
        currentPointIndex = nil
        currentPoint = nil
        
        func location(i:Int, spline:IMPSpline) -> float2 {
            let x = i.float/spline.curve.count.float
            let y = spline.curve[i]
            return float2(x,y)
        }
        
        if let spline = activeCurve?.spline {
            if spline.maxControlPoints == spline.controlPoints.count {
                for i in 0..<spline.controlPoints.count {
                    let p = spline.controlPoints[i]
                    if distance(p, xy) < precision {
                        currentPoint = xy
                        spline.set(point: xy, atIndex: i)
                        break
                    }
                }
            }
            else if let i = spline.indexOf(point: xy, distance: precision) {
                spline.set(point: xy, atIndex: i)
                currentPoint = xy
            }
            else if distance(spline.bounds.first, xy) < precision {
                spline.set(point: xy, atIndex: 0)
                currentPoint = xy
            }
            else if distance(spline.bounds.last, xy) < precision {
                spline.set(point: xy, atIndex: spline.controlPoints.count-1)
                currentPoint = xy
            }
            else {
                for i in 0..<spline.curve.count {
                    if distance(location(i, spline: spline), xy) < precision {
                        spline.add(points: [xy])
                        currentPoint = xy
                        break
                    }
                }
            }
        }
    }
    
    func drawGrid(dirtyRect: NSRect)  {
        
        gridColor.set()
        let noHLines = 4
        let noVLines = 4
        
        let vSpacing = dirtyRect.size.height / CGFloat(noHLines)
        let hSpacing = dirtyRect.size.width / CGFloat(noVLines)
        
        let bPath:NSBezierPath = NSBezierPath()
        
        bPath.lineWidth = gridWidth.cgfloat
        
        for i in 1..<noHLines{
            let yVal = CGFloat(i) * vSpacing
            bPath.moveToPoint(NSMakePoint(0, yVal))
            bPath.lineToPoint(NSMakePoint(dirtyRect.size.width , yVal))
        }
        bPath.stroke()
        
        for i in 1..<noVLines{
            let xVal = CGFloat(i) * hSpacing
            bPath.moveToPoint(NSMakePoint(xVal, 0))
            bPath.lineToPoint(NSMakePoint(xVal, dirtyRect.size.height))
        }
        bPath.stroke()
    }
    
    func colorOf(info:CurveInfo) -> IMPColor {
        var a = info.color.alphaComponent
        if !info.isActive {
            a *= 0.5
        }
        return IMPColor(red: info.color.redComponent,   green: info.color.greenComponent, blue: info.color.blueComponent, alpha: a)
    }
    
    func drawCurve(dirtyRect: NSRect, info:CurveInfo){
        
        guard let spline = info.spline else { return }
        
        colorOf(info).set()

        let path = NSBezierPath()
        path.fill()
        path.lineWidth = lineWidth.cgfloat
        
        path.moveToPoint(NSPoint(x:0, y:0))
        
        for i in 0..<spline.curve.count {
            let x = CGFloat(i) * dirtyRect.size.width / CGFloat(255)
            let y = spline.curve[i].cgfloat*dirtyRect.size.height
            path.lineToPoint(NSPoint(x: x, y: y))
        }
        
        path.stroke()
    }
    
    func drawControlPoints(dirtyRect: NSRect, info:CurveInfo) {
        
        guard let spline = info.spline else { return }
        
        if !info.isActive { return }
        
        
        let cp = currentPoint ?? float2(-1)
        
        let markerSizeHere = (markerSize).cgfloat

        for p in spline.controlPoints {

            let boldPathColor = backgroundColor ?? IMPColor.blackColor()
            let pathColor     = colorOf(info)

            let boldPath = NSBezierPath()
            boldPath.lineWidth = lineWidth.cgfloat
            
            let path = NSBezierPath()
            path.lineWidth = lineWidth.cgfloat

            let isClosennes = spline.closeness(one: cp, two: p)
            
            var np = NSPoint(x:p.x.cgfloat*dirtyRect.size.width, y:p.y.cgfloat*dirtyRect.size.height)
            let ms = (markerSize+lineWidth).cgfloat/2
            
            if np.x < ms {
                np.x = ms
            }

            if np.y < ms {
                np.y = ms
            }
            
            if np.x > dirtyRect.size.width-ms {
                np.x = dirtyRect.size.width - ms
            }
            
            if np.y > dirtyRect.size.height - ms {
                np.y = dirtyRect.size.height - ms
            }

            let rect = NSRect(
                x: np.x-markerSizeHere/2,
                y: np.y-markerSizeHere/2,
                width: markerSizeHere, height: markerSizeHere)

            if  isClosennes  {
                pathColor.set()
                
                path.appendBezierPathWithRect(rect)
                boldPath.appendBezierPathWithRect(rect)

                path.stroke()
                boldPath.fill()
            }
            else {                
                boldPathColor.set()
                boldPath.appendBezierPathWithRect(rect)
                boldPath.fill()

                pathColor.set()
                path.appendBezierPathWithRect(rect)
                path.stroke()

            }
        }
    }
    
    override public func drawRect(dirtyRect: NSRect)
    {
        super.drawRect(dirtyRect)
        drawGrid(dirtyRect)
        for i in list {
            drawCurve(dirtyRect, info: i)
        }
        for i in list {
            drawControlPoints(dirtyRect, info: i)
        }
    }
  
}
