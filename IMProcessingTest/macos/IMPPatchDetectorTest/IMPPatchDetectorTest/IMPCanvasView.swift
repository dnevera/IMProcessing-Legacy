//
//  IMPCanvasView.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa

class IMPCanvasView: NSView {
    
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
    
    
    func drawPatch(patch:IMPPatchesGrid.Patch,
                  color:NSColor,
                  width:CGFloat = 8
        ){
        
        if let lt = patch.lt, let center = patch.center {
            
            var path = NSBezierPath()
            
            var fillColor = color
            
            fillColor.set()
            path.fill()
            path.lineWidth = width
            
            let mag = float2(bounds.size.width.float, bounds.size.height.float)/float2(2)
            let radius = distance(lt.point *  mag, center.point * mag)
            let p0 = NSPoint(x: center.point.x.cgfloat * bounds.size.width,
                             y: (1-center.point.y.cgfloat) * bounds.size.height)
            
            path.appendArc(withCenter: p0, radius: CGFloat(radius), startAngle: 0, endAngle: 360)
            
            path.stroke()
            path.close()
            
            path = NSBezierPath()
            fillColor = NSColor.black
            
            fillColor.set()
            path.fill()
            path.lineWidth = 1

            path.appendArc(withCenter: p0, radius: CGFloat(radius), startAngle: 0, endAngle: 360)

            path.stroke()
            path.close()
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
                       thickness:CGFloat = 12,
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
    
//    func drawPatch(patch:IMPPatch,
//                   color:NSColor = NSColor(red: 1, green: 1, blue: 0.2, alpha: 0.6),
//                   thickness:CGFloat = 4
//        ){
//        
//        drawLine(segment: IMPLineSegment(p0:patch.lt.point,p1:patch.rt.point), color: color, width: thickness)
//        drawLine(segment: IMPLineSegment(p0:patch.rt.point,p1:patch.rb.point), color: color, width: thickness)
//        drawLine(segment: IMPLineSegment(p0:patch.rb.point,p1:patch.lb.point), color: color, width: thickness)
//        drawLine(segment: IMPLineSegment(p0:patch.lb.point,p1:patch.lt.point), color: color, width: thickness)
//    }
    
    override func draw(_ dirtyRect: NSRect) {
        for s in hlines {
            drawLine(segment: s, color:  NSColor(red: 0,   green: 0.9, blue: 0.1, alpha: 0.8))
        }
        
        for s in vlines {
            drawLine(segment: s, color: NSColor(red: 0,   green: 0.1, blue: 0.9, alpha: 0.8))
        }
        
        for (i,c) in corners.enumerated() {
            drawCrosshair(corner: c,
                          color: NSColor(red: CGFloat(c.color.r),   green: CGFloat(c.color.g), blue: CGFloat(c.color.b), alpha: 1),
                          index: i)
        }
                
        for p in patches {
            if let c = p.center {
                drawPatch(patch: p, color: NSColor(red: CGFloat(c.color.r),
                                                   green: CGFloat(c.color.g),
                                                   blue: CGFloat(c.color.b),
                                                   alpha: CGFloat(1)))
            }
        }
    }
}
