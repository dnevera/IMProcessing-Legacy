//
//  IMPCurveFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 12.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal
import Accelerate

public class IMPCurvesFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public class Splines: IMPTextureProvider,IMPContextProvider {
        
        public var context:IMPContext!
        
        public static let scale:Float    = 1
        public static let minValue = 0
        public static let maxValue = 255
        public static let defaultControls = [float2(minValue.float,minValue.float),float2(maxValue.float,maxValue.float)]
        public static let defaultRange    = Float.range(0..<maxValue)
        public static let defaultCurve    = defaultRange.cubicSpline(defaultControls, scale: scale) as [Float]

        var _redCurve:[Float]   = Splines.defaultCurve
        var _greenCurve:[Float] = Splines.defaultCurve
        var _blueCurve:[Float]  = Splines.defaultCurve
        
        
        func newGaussKernel(radius:Int) -> [Float] {
            if radius < 2 {
                return []
            }
            let sigma:Float = 0.5
            let mu:Float = 0.5
            let fi:Float = 1 //(sigma*sqrt(2*M_PI.float))
            return IMPHistogram(gauss: fi, mu: [mu], sigma: [sigma], size: radius, type: .PLANAR)[.X]
        }
        
        lazy var curveGaussFilter:[Float] = {
            return self.newGaussKernel(self.blurRadius)
        }()
        
        public var blurRadius:Int = 0 {
            didSet{
                doNotUpdate = true
                curveGaussFilter = newGaussKernel(blurRadius)
                doNotUpdate = false
                updateTexture()
            }
        }
        
        public var channelCurves:[[Float]]{
            get{
                return [_redCurve,_greenCurve,_blueCurve]
            }
        }
        public var redCurve:[Float]{
            get{
                return _redCurve
            }
        }
        public var greenCurve:[Float]{
            get{
                return _greenCurve
            }
        }
        public var blueCurve:[Float]{
            get{
                return _blueCurve
            }
        }
        
        var doNotUpdate = false
        public var redControls   = Splines.defaultControls {
            didSet{
                _redCurve = Splines.defaultRange.cubicSpline(redControls, scale: Splines.scale) as [Float]
                if curveGaussFilter.count > 0 {
                    _redCurve = _redCurve.convolve(curveGaussFilter)
                }
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var greenControls = Splines.defaultControls{
            didSet{
                _greenCurve = Splines.defaultRange.cubicSpline(greenControls, scale: Splines.scale) as [Float]
                if curveGaussFilter.count > 0 {
                    _greenCurve = _greenCurve.convolve(curveGaussFilter)
                }
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var blueControls  = Splines.defaultControls{
            didSet{
                _blueCurve = Splines.defaultRange.cubicSpline(blueControls, scale: Splines.scale) as [Float]
                if curveGaussFilter.count > 0 {
                    _blueCurve = _blueCurve.convolve(curveGaussFilter)
                }
                if !doNotUpdate {
                    updateTexture()
                }
            }
        }
        public var compositeControls = Splines.defaultControls{
            didSet{
                doNotUpdate = true
                redControls   = compositeControls
                greenControls = compositeControls
                blueControls  = compositeControls
                doNotUpdate = false
                updateTexture()
            }
        }
        
        public var texture:MTLTexture?
        public var filter:IMPFilter?
        
        public required init(context:IMPContext){
            self.context = context
            updateTexture()
        }
        
        func updateTexture(){

            if texture == nil {
                texture = context.device.texture1DArray(channelCurves)
            }
            else {
                texture?.update(channelCurves)
            }
                        
            if filter != nil {
                filter?.dirty = true
            }
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
    
    public var splines:Splines!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_adjustCurve")
        addFunction(kernel)
        splines = Splines(context: context)
        splines.filter = self
        defer{
            adjustment = IMPCurvesFilter.defaultAdjustment
        }
    }
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(splines.texture, atIndex: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
}

extension _ArrayType where Generator.Element == Float {
    
    public mutating func convolve(filter:[Float], scale:Float=1) -> [Float]{
        
        if filter.count == 0 {
            return []
        }
        
        var os = [Float](self)
        
        let halfs = vDSP_Length(filter.count)
        var asize = count+filter.count*2
        var addata = [Float](count: asize, repeatedValue: 0)
        var tempBuffer = [Float](count: asize, repeatedValue: 0)
        var one:Float = 1
        var cp:Float  = 0.5
        var sindex:vDSP_Length = 128;
        vDSP_vthrsc(os, 1, &cp, &one, &tempBuffer, 1, vDSP_Length(asize))
        vDSP_maxvi(tempBuffer, 1, &cp, &sindex, vDSP_Length(asize))
        

        //
        // we need to supplement source distribution to apply filter right
        //
        vDSP_vclr(&addata, 1, vDSP_Length(asize))
        
        var zero = self[0]
        vDSP_vsadd(&addata, 1, &zero, &addata, 1, vDSP_Length(filter.count))
        
        one  =  self[count-1]
        let rest = UnsafeMutablePointer<Float>(addata)+count+Int(halfs)
        vDSP_vsadd(rest, 1, &one, rest, 1, halfs-1)
        
        var addr = UnsafeMutablePointer<Float>(addata)+Int(halfs)
        vDSP_vadd(&os, 1, addr, 1, addr, 1, vDSP_Length(count))
        
        //
        // apply filter
        //
        asize = count+filter.count-1
        var maxv:Float = 1;
        vDSP_conv(addata, 1, filter, 1, &addata, 1, vDSP_Length(asize), vDSP_Length(filter.count))
        vDSP_maxv(addata, 1, &maxv, vDSP_Length(asize))
        vDSP_vsdiv(addata, 1, &maxv, &addata, 1, vDSP_Length(asize));

        //print("tempBuffer=\(addata.prefix(256)); x = 0:1/(length(tempBuffer)-1):1; plot(x,tempBuffer);")
        //print("self=\(self.prefix(256)); x = 0:1/(length(self)-1):1; plot(x,self);")

        var index:vDSP_Length = 128
        
        //
        // Отсекаем точку перехода из минимума в остальное
        //
        cp = 0.5
        one = 1
        vDSP_vthrsc(&addata, 1, &cp, &one, &tempBuffer, 1, vDSP_Length(asize))
        vDSP_maxvi(tempBuffer, 1, &cp, &index, vDSP_Length(asize))

        //
        // normalize coordinates
        //
        addr = UnsafeMutablePointer<Float>(addata) + ((Int(index)-Int(sindex)))
        memcpy(&os, addr, count*sizeof(Float))
        
        var left = -self[0]
        vDSP_vsadd(os, 1, &left, &os, 1, vDSP_Length(count))
        
        //
        // normalize
        //
        var denom:Float = 0
        
        if (scale>0) {
            vDSP_maxv (&os, 1, &denom, vDSP_Length(count))
            denom /= scale
            vDSP_vsdiv(os, 1, &denom, &os, 1, vDSP_Length(count))
        }
        
        //print("os=\(os.prefix(256)); x = 0:1/(length(os)-1):1; plot(x,os);")

        ///print("\nindex=\(index,sindex);")

        return os
    }
}
