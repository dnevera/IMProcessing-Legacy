//
//  IMPChannelCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 29/06/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing
import Accelerate

public class IMPSplinesProvider: IMPImageProvider {

    public var splines:[[Float]]! {
        didSet{
            update(splines)
        }
    }
    
    public convenience init(context: IMPContext, splines:[[Float]]) {
        self.init(context: context)
        defer {
            self.splines = splines
        }
    }
    
    public func update(splines:[[Float]]){
        if texture == nil {
            texture = context.device.texture1DArray(splines)
        }
        else {
            texture?.update(splines)
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
    
    private var channels:[[Float]] {
        let xx = matchMaster(x._curve)
        let yy = matchMaster(y._curve)
        let zz = matchMaster(z._curve)
        return [xx ?? x.curve, yy ?? y.curve, zz ?? z.curve]
    }
    
    var _x:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _x.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    var _y:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _y.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    var _z:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _z.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }

    var _w:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            _w.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    var identity = IMPCurveFunction.Cubic.spline
    
    func matchMaster(in_out:[Float]) -> [Float]? {
        
        guard in_out.count > 0 else { return nil }
        
        var diff = [Float](count:in_out.count, repeatedValue: 0)
        var one:Float = 1
        let sz = vDSP_Length(in_out.count)
        
        vDSP_vsmsb(_w.curve, 1, &one, identity.curve, 1, &diff, 1, sz)
        vDSP_vsma(in_out, 1, &one, diff, 1, &diff, 1, sz)
        return diff
    }
    
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

