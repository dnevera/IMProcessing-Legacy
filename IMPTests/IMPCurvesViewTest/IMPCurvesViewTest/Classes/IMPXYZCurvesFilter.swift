//
//  IMPChannelCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 29/06/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing

public class IMPSplinesProvider: IMPImageProvider {

    public var splines:[IMPSpline]! {
        didSet{
            update(splines)
        }
    }
    
    public convenience init(context: IMPContext, splines:[IMPSpline]) {
        self.init(context: context)
        defer {
            self.splines = splines
        }
    }
    
    public func update(splines:[IMPSpline]){
        var channelCurves = [[Float]]()
        
        for c in splines {
            channelCurves.append(c.curve)
        }
        
        if texture == nil {
            texture = context.device.texture1DArray(channelCurves)
        }
        else {
            texture?.update(channelCurves)
        }
    }
}

public class IMPXYZCurvesFilter:IMPFilter,IMPAdjustmentProtocol{

    
    public var x:IMPSpline  { return _x }
    public var y:IMPSpline  { return _y }
    public var z:IMPSpline  { return _z }
    public var w:IMPSpline  { return _w }
    
    public static let defaultAdjustment = IMPAdjustment(
        blending: IMPBlending(mode: IMPBlendingMode.LUMNINOSITY, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeofValue(adjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    public required init(context: IMPContext, name:String, curveFunction:IMPCurveFunction) {
        super.init(context: context)
        
        kernel = IMPFunction(context: self.context, name: name)
        addFunction(kernel)

        defer{
            self.curveFunction = curveFunction
            adjustment = IMPCurvesFilter.defaultAdjustment
        }
    }
    
    public required init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(curves.texture, atIndex: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
    
    public var curveFunction:IMPCurveFunction! {
        didSet{
            _x = curveFunction.spline
            _y = curveFunction.spline
            _z = curveFunction.spline
            _w = curveFunction.spline
            identity = curveFunction.spline
        }
    }
    
    private var channels:[IMPSpline] {
        return [x,y,z]
    }
    
    var _x:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _x.addUpdateObserver { (spline) in
                if self.doNotUpdate {return}
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    var _y:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _y.addUpdateObserver { (spline) in
                if self.doNotUpdate {return}
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    var _z:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _z.addUpdateObserver { (spline) in
                if self.doNotUpdate {return}
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }

    var doNotUpdate = false
    var _w:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _w.addUpdateObserver { (spline) in
                self.doNotUpdate = true
                self._x <- self._w.controlPoints
                self._y <- self._w.controlPoints
                self._z <- self._w.controlPoints
                self.curves.update(self.channels)
                self.doNotUpdate = false
                self.dirty = true
            }
        }
    }
    
    var identity = IMPCurveFunction.Cubic.spline
    
    private lazy var curves:IMPSplinesProvider = IMPSplinesProvider(context: self.context, splines: self.channels)
}

public class IMPRGBCurvesFilter:IMPXYZCurvesFilter {
    
    public required convenience init(context: IMPContext, curveFunction:IMPCurveFunction) {
        self.init(context: context, name: "kernel_adjustRGBWCurve", curveFunction:curveFunction)
    }
    
    public required convenience init(context: IMPContext) {
        self.init(context: context, name: "kernel_adjustRGBWCurve", curveFunction:.Cubic)
    }
}

