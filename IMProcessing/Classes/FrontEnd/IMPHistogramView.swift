//
//  IMPHistogramView.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 19.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public class IMPHistogramView: IMPViewBase, IMPContextProvider {
    
    public enum HistogramType {
        case PDF
        case CDF
    }
    
    public var type:HistogramType = .PDF {
        didSet{
            filter?.dirty = true
        }
    }
    
    public var generatorLayer:IMPHistogramGenerator.Layer {
        set {
            generator.layer = newValue
        }
        get{
            return generator.layer
        }
    }
    
    public var visibleBins = 256 {
        didSet{
            generator.dirty = true
        }
    }
    
    public var context: IMPContext!
        
    public init(context contextIn: IMPContext, frame: NSRect, histogramHardware:IMPHistogramAnalyzer.Hardware) {
        super.init(frame: frame)
        self.context = contextIn
        self.histogramHardware = histogramHardware 
        self.autoresizesSubviews = true
        addSubview(imageView)
        self.wantsLayer = true
        self.layer?.backgroundColor = IMPColor.clearColor().CGColor
    }

    public convenience init(context contextIn: IMPContext, frame: NSRect) {
        self.init(context: contextIn, frame: frame, histogramHardware: .GPU)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var imageView:IMPView = { 
        let v = IMPView(filter: self.generator,frame: self.bounds)
        #if os(OSX)
        v.autoresizingMask = [.ViewHeightSizable, .ViewWidthSizable, .ViewMinXMargin, .ViewMinYMargin]
        #else
        v.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        #endif
        v.backgroundColor = IMPColor.yellowColor()
        return v
    }()
    
    var histogramHardware = IMPHistogramAnalyzer.Hardware.GPU
    
    lazy var analizer:IMPHistogramAnalyzer = { 
        let a = IMPHistogramAnalyzer(context: self.context, hardware: self.histogramHardware)
        a.addUpdateObserver({ (histogram) in
            if self.type == .PDF {
                self.generator.histogram = histogram.pdf(1).segment(count: self.visibleBins)
            }
            else {
                self.generator.histogram = histogram.cdf(1).segment(count: self.visibleBins)
            }
        })
        return a
    }()
    
    lazy var generator:IMPHistogramGenerator = {        
        return IMPHistogramGenerator(context: self.context, size: IMPSize(width: self.bounds.width, height: self.bounds.height)*IMPView.scaleFactor)
    }()
    
    public var filter:IMPFilter?{
        set(newFiler){
            fatalError("IMPHistogramView does not allow set new filter...")
        }
        get{ return analizer }
    }
    
    #if os(OSX)
    override public func updateLayer() {
        super.updateLayer()
        imageView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        generator.size = IMPSize(width: self.bounds.width, height: self.bounds.height)*IMPView.scaleFactor
    }
    #endif
}