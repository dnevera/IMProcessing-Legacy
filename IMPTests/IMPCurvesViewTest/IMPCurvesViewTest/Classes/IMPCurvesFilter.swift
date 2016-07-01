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
            texture?.update1DArray(splines)
        }
    }
}

public class IMPXYZCurvesFilter:IMPFilter,IMPAdjustmentProtocol{

    
//    public var x:IMPSpline?  {
//        willSet{
//            if x == nil {
//                newValue = _x
//            }
//        }
////        get{
////            return _x
////        }
////        set {
////            _x = newValue
////        }
//        didSet{
//            _x=x
//        }
//    }
//    public var y:IMPSpline  { get{return _y}
//        set {
//            _y = newValue
//        }
//    }
//    public var z:IMPSpline  { get{return _z}
//        set {
//            _z = newValue
//        }
//    }
//    public var w:IMPSpline  { get {return _w }
//        set {
//            _w = newValue
//        }
//    }
    
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
            x = curveFunction.spline
            y = curveFunction.spline
            z = curveFunction.spline
            w = curveFunction.spline
            identity = curveFunction.spline
        }
    }
    
    private var channels:[[Float]] {
        let xx = matchMaster(x._curve) ?? x.curve
        let yy = matchMaster(y._curve) ?? y.curve
        let zz = matchMaster(z._curve) ?? z.curve
        return [xx, yy, zz]
    }
    
    public var x:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            x.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    public var y:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            y.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }
    
    public var z:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            z.addUpdateObserver { (spline) in
                self.curves.update(self.channels)
                self.dirty = true
            }
        }
    }

    public var w:IMPSpline = IMPCurveFunction.Cubic.spline {
        didSet{
            w.addUpdateObserver { (spline) in
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
        
        vDSP_vsmsb(w.curve, 1, &one, identity.curve, 1, &diff, 1, sz)
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

