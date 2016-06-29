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
    
    public var x:IMPSpline {
        get {
            return curves.splines[0]
        }
        set {
            curves.splines[0] = newValue
        }
    }
    
    public var y:IMPSpline {
        get {
            return curves.splines[1]
        }
        set {
            curves.splines[1] = newValue
        }
    }

    public var z:IMPSpline {
        get {
            return curves.splines[2]
        }
        set {
            curves.splines[2] = newValue
        }
    }

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
            xChannel = curveFunction.spline
            yChannel = curveFunction.spline
            zChannel = curveFunction.spline
            curves  = IMPSplinesProvider(context: self.context, splines: [self.xChannel,self.yChannel,self.zChannel])
        }
    }
    
    private var xChannel:IMPSpline!
    private var yChannel:IMPSpline!
    private var zChannel:IMPSpline!
    private var curves:IMPSplinesProvider!
}

public class IMPRGBCurvesFilter:IMPXYZCurvesFilter {
    
    public required convenience init(context: IMPContext, curveFunction:IMPCurveFunction) {
        self.init(context: context, name: "kernel_adjustRGBCurve", curveFunction:curveFunction)
    }
    
    public required convenience init(context: IMPContext) {
        self.init(context: context, name: "kernel_adjustRGBCurve", curveFunction:.Cubic)
    }
}

