//
//  IMPWheelCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by denis svinarchuk on 21.07.16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing

public enum IMPColorWheel : String {
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

public protocol IMPColorBlending: IMPContextProvider {
    
    var weights:MTLTexture! {get set}
    
    var didUpdate:((bending:IMPColorBlending)->Void)? {get set}
    
    init(context:IMPContext)
    func  create() -> MTLTexture
}

public class IMPColorGaussBlending: IMPColorBlending{
    
    public var weights: MTLTexture!{
        didSet{
            if let o = didUpdate {
                o(bending: self)
            }
        }
    }
    
    public var context: IMPContext!
    
    public required init(context: IMPContext) {
        self.context = context
        weights = create()
    }
    
    public var overlap: Float = IMProcessing.hsv.hueOverlapFactor {
        didSet{
            weights = create()
        }
    }
    
    public var didUpdate: ((bending: IMPColorBlending) -> Void)?
    
    public func create() -> MTLTexture {
        return IMPHSVFilter.defaultHueWeights(context, overlap: overlap)
    }
}

public class IMPWheelCurvesFilter: IMPFilter,IMPAdjustmentProtocol {
    
    public class Splines{
        
        public init(function:IMPCurveFunction = .Cubic, filter:IMPWheelCurvesFilter?=nil) {
            for i in 0..<7 {
                self[i] = function.spline
            }
            self.filter = filter
        }
        
        public var reds:IMPSpline!    { didSet{ update() } }
        public var yellows:IMPSpline! { didSet{ update() } }
        public var greens:IMPSpline!  { didSet{ update() } }
        public var cyans:IMPSpline!   { didSet{ update() } }
        public var blues:IMPSpline!   { didSet{ update() } }
        public var magentas:IMPSpline!{ didSet{ update() } }
        
        public var master:IMPSpline!  { didSet{ update() } }
        
        public subscript(colors:IMPColorWheel) -> IMPSpline {
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
        
        var filter:IMPWheelCurvesFilter! {
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
    
    public var x        = Splines(){
        didSet{
            x.filter = self
        }
    }
    
    public var y = Splines(){
        didSet{
            y.filter = self
        }
    }
    
    public var z      = Splines(){
        didSet{
            z.filter = self
        }
    }
    
    public var colorBlending:IMPColorBlending! {
        didSet{
            colorBlending.didUpdate = { (blending) in
                self.dirty = true
            }
        }
    }
    
    public var curveFunction:IMPCurveFunction! {
        didSet{            
            x = Splines(function: curveFunction, filter: self)
            y = Splines(function: curveFunction, filter: self)
            z = Splines(function: curveFunction, filter: self)
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
    
    public required init(context: IMPContext, name:String, curveFunction:IMPCurveFunction = .Cubic) {
        super.init(context: context)
        
        kernel = IMPFunction(context: self.context, name: name)
        addFunction(kernel)
        
        defer{
            adjustment = IMPHSVCurvesFilter.defaultAdjustment
            colorBlending = IMPColorGaussBlending(context: context)
            self.curveFunction = curveFunction
        }
    }
    
    required public init(context: IMPContext) {
        fatalError("init(context:) has not been implemented")
    }
    
    //public convenience required init(context: IMPContext) {
    //self.init(context:context, curveFunction: .Cubic)
    //}
    
    override public func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(colorBlending.weights,      atIndex: 2)
            command.setTexture(x.curves.texture,         atIndex: 3)
            command.setTexture(y.curves.texture,  atIndex: 4)
            command.setTexture(z.curves.texture,       atIndex: 5)
            
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}
