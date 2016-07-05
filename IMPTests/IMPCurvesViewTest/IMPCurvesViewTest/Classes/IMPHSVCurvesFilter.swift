//
//  IMPHSVCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 02/07/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing

public enum IMPHSVColorsType : String {
    case Master   = "Master"
    case Reds     = "Reds"
    case Yellows  = "Yellows"
    case Greens   = "Greens"
    case Cyans    = "Cyans"
    case Blues    = "Blues"
    case Magentas = "Magentas"
    
    public var index:Int {
        switch self {
        case .Reds:    return 0
        case .Yellows: return 1
        case .Greens:  return 2
        case .Cyans:   return 3
        case .Blues:   return 4
        case .Magentas:return 5
        case .Master:  return 6
        }
    }
}

public class IMPHSVCurvesFilter: IMPFilter,IMPAdjustmentProtocol {
    
    public typealias ColorsType = IMPHSVColorsType
    
    public class Splines{

        public init(function:IMPCurveFunction = .Cubic) {
            for i in 0..<7 {
                self[i] = function.spline
            }
        }
        
        public var reds:IMPSpline!    { didSet{ update() } }
        public var yellows:IMPSpline! { didSet{ update() } }
        public var greens:IMPSpline!  { didSet{ update() } }
        public var cyans:IMPSpline!   { didSet{ update() } }
        public var blues:IMPSpline!   { didSet{ update() } }
        public var magentas:IMPSpline!{ didSet{ update() } }
        
        public var master:IMPSpline!  { didSet{ update() } }
        
        public subscript(colors:IMPHSVColorsType) -> IMPSpline {
            get{
                return self[colors.index]
            }
            set{
                self[colors.index] = newValue
            }
        }
        
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
        
        func update()  {
            if let f = self.filter {
                for i in 0..<7 {
                    self[i].addUpdateObserver({ (spline) in
                        self.curves.update(self.all)
                        f.dirty = true
                    })
                }
            }
        }
        
        var filter:IMPHSVCurvesFilter! {
            didSet{
                update()
            }
        }
        
        var all:[[Float]] {
            var v = [[Float]]()
            for i in 0..<7 {
                v.append(self[i].curve)
            }
            return v
        }
        
        lazy var curves:IMPSplinesProvider = IMPSplinesProvider(context: self.filter.context, splines: self.all)
    }
    
    public var hue        = Splines(){
        didSet{
            hue.filter = self
        }
    }
    
    public var saturation = Splines(){
        didSet{
            saturation.filter = self
        }
    }
    
    public var value      = Splines(){
        didSet{
            value.filter = self
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
            
            hue.filter = self
            saturation.filter = self
            value.filter = self
            
        }
    }

    public static let defaultAdjustment = IMPAdjustment(blending: IMPBlending(mode: NORMAL, opacity: 1))
    
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
            adjustment = IMPHSVCurvesFilter.defaultAdjustment
            self.curveFunction = curveFunction
        }
    }
    
    public convenience required init(context: IMPContext) {
        self.init(context:context, curveFunction: .Cubic)
    }
    
    override public func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(hueWeights, atIndex: 2)
            command.setTexture(hue.curves.texture, atIndex: 3)
            command.setTexture(saturation.curves.texture, atIndex: 4)
            command.setTexture(value.curves.texture, atIndex: 5)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
    
    internal lazy var hueWeights:MTLTexture = {
        return IMPHSVFilter.defaultHueWeights(self.context, overlap: IMProcessing.hsv.hueOverlapFactor)
    }()
}
