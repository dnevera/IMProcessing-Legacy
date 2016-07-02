//
//  IMPHSVCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 02/07/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing

public class IMPHSVCurvesFilter: IMPFilter,IMPAdjustmentProtocol {
    
    
    public class Splines{

        public init(function:IMPCurveFunction = .Cubic) {
            for i in 0..<7 {
                self[i] = function.spline
            }
        }
        
        public var reds:IMPSpline!
        public var yellows:IMPSpline!
//            {
//            didSet{
//                print("yellows = \(yellows.curve)")
//            }
//        }
        public var greens:IMPSpline!
        public var cyans:IMPSpline!
        public var blues:IMPSpline!
        public var magentas:IMPSpline!
        public var master:IMPSpline!
        
        public subscript(index:Int) -> IMPSpline {
            get{
                switch(index){
                case 0:
                    return reds
                case 1:
                    return yellows
                case 2:
                    return greens
                case 3:
                    return cyans
                case 4:
                    return blues
                case 5:
                    return magentas
                default:
                    return master
                }
            }
            set {
                switch(index){
                case 0:
                    reds = newValue
                case 1:
                    yellows = newValue
                case 2:
                    greens = newValue
                case 3:
                    cyans = newValue
                case 4:
                    blues = newValue
                case 5:
                    magentas = newValue
                default:
                    master = newValue
                }
            }
        }
    }
    
    public var hue        = Splines()
    
    public var saturation = Splines(){
        didSet{
            for i in 0..<7 {
                saturation[i].addUpdateObserver({ (spline) in
                    
                    print(" saturation =  \(self.saturations[1])")
                    
                    self.saturationCurves.update(self.saturations)
                    self.dirty = true
                })
            }
        }
    }
    
    public var value      = Splines(){
        didSet{
            for i in 0..<7 {
                value[i].addUpdateObserver({ (spline) in
                    
                    //print(" spline =  \(self.values[1])")

                    self.valueCurves.update(self.values)
                    self.dirty = true
                })
            }
        }
    }
    
    public var overlap:Float = IMProcessing.hsv.hueOverlapFactor {
        didSet{
            hueWeights = IMPHSVFilter.defaultHueWeights(self.context, overlap: overlap)
            dirty = true
        }
    }
    
    public var curveFunction:IMPCurveFunction! {
        didSet{
            hue = Splines(function: curveFunction)
            saturation = Splines(function: curveFunction)
            value = Splines(function: curveFunction)
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
    
    public required init(context: IMPContext, curveFunction:IMPCurveFunction) {
        super.init(context: context)
        
        kernel = IMPFunction(context: self.context, name: "kernel_adjustHSVCurves")
        addFunction(kernel)
        
        defer{
            self.curveFunction = curveFunction
            adjustment = IMPCurvesFilter.defaultAdjustment
        }
    }
    
    public convenience required init(context: IMPContext) {
        self.init(context:context, curveFunction: .Cubic)
    }
    
    override public func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(hueWeights, atIndex: 2)
            command.setTexture(hueCurves.texture, atIndex: 3)
            command.setTexture(saturationCurves.texture, atIndex: 3)
            command.setTexture(valueCurves.texture, atIndex: 3)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
    
    internal lazy var hueWeights:MTLTexture = {
        return IMPHSVFilter.defaultHueWeights(self.context, overlap: IMProcessing.hsv.hueOverlapFactor)
    }()
    
    func getSplinesOf(v:Splines) -> [[Float]] {
        var v = [[Float]]()
        for i in 0..<7 {
            v.append(value[i].curve)
        }
        return v
    }
    
    var hues:[[Float]] { return getSplinesOf(hue)}
    var saturations:[[Float]] { return getSplinesOf(saturation)}
    var values:[[Float]] { return getSplinesOf(value)}
    
    lazy var hueCurves:IMPSplinesProvider = IMPSplinesProvider(context: self.context, splines: self.hues)
    lazy var saturationCurves:IMPSplinesProvider = IMPSplinesProvider(context: self.context, splines: self.saturations)
    lazy var valueCurves:IMPSplinesProvider = IMPSplinesProvider(context: self.context, splines: self.values)
}
