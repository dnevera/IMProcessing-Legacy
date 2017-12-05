//
//  IMPDisplayTimer.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 28.05.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public typealias IMPTimingFunction = ((_ t:Float) -> Float)

open class IMPMediaTimingFunction {
    let function:CAMediaTimingFunction
    
    var controls = [float2](repeating: float2(0), count: 3)
    
    public init(name: String) {
        function = CAMediaTimingFunction(name: name)
        for i in 0..<3 {
            var coords = [Float](repeating: 0, count: 2)
            function.getControlPoint(at: i, values: &coords)
            controls[i] = float2(coords)
        }
    }
    
    open var c0:float2 {
        return controls[0]
    }
    open var c1:float2 {
        return controls[1]
    }
    open var c2:float2 {
        return controls[2]
    }
    
    static var  Default   = IMPMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
    static var  Linear    = IMPMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    static var  EaseIn    = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
    static var  EaseOut   = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
    static var  EaseInOut = IMPMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
}


public enum IMPTimingCurve: Float {
    
    case `default`
    case linear
    case easeIn
    case easeOut
    case easeInOut
    
    public var function:IMPTimingFunction {
        var curveFunction:IMPMediaTimingFunction
        
        switch self {
        case .linear:
            return {(t) in return t}
        case .default:
            curveFunction = IMPMediaTimingFunction.Default
            
        case .easeIn:
            curveFunction = IMPMediaTimingFunction.EaseIn
        case .easeOut:
            curveFunction = IMPMediaTimingFunction.EaseOut
        case .easeInOut:
            curveFunction = IMPMediaTimingFunction.EaseInOut
        }
        
        return { (t) -> Float in
            return t.cubicBesierFunction(c1: curveFunction.c1, c2: curveFunction.c2)
        }
    }
}

open class IMPDisplayTimer:NSObject {
    
    public enum UpdateCurveOptions{
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case decelerate
    }
    
    public typealias UpdateHandler   = ((_ atTime:TimeInterval)->Void)
    public typealias CompleteHandler = ((_ flag:Bool)->Void)
    
    
    open static func execute(duration: TimeInterval,
                                        options:IMPTimingCurve = .default,
                                        resolution:Int = 20,
                                        update:@escaping UpdateHandler,
                                        complete:CompleteHandler? = nil) -> IMPDisplayTimer {
        
        let timer = IMPDisplayTimer(duration: duration,
                                    timingFunction: options.function,
                                    resolution: resolution,
                                    update: update,
                                    complete: complete)
        IMPDisplayTimer.timerList.append(timer)
        timer.start()
        return timer
    }

    
    open static func cancelAll() {
        while let t = IMPDisplayTimer.timerList.last {
            t.cancel()
        }
    }

    open static func invalidateAll() {
        while let t = IMPDisplayTimer.timerList.last {
            t.invalidate()
        }
    }

    open func cancel() {
        stop(true)
    }

    open func invalidate() {
        stop(false)
    }
    
    static var timerList = [IMPDisplayTimer]()
    
    var timingFunction:IMPTimingFunction
    var timeElapsed:TimeInterval = 0
    
    let updateHandler:UpdateHandler
    let completeHandler:CompleteHandler?
    let duration:TimeInterval
    let resulution:Int
    var timer:IMPRTTimer? = nil
    
    
    fileprivate init(duration:TimeInterval,
                 timingFunction:@escaping IMPTimingFunction,
                 resolution r:Int,
                 update:@escaping UpdateHandler,
                 complete:CompleteHandler?){
        self.resulution = r
        self.duration = duration
        self.timingFunction = timingFunction
        updateHandler = update
        completeHandler = complete
    }
    
    func removeFromList()  {
        if let index = IMPDisplayTimer.timerList.index(of: self) {
            IMPDisplayTimer.timerList.remove(at: index)
        }
    }
    
    func start() {
        if duration > 0 {
            
            self.timeElapsed = 0
            
            self.timer = IMPRTTimer(usec: 50, update: { (timestamp, duration) in
                
                guard self.duration > 0    else {return}
                
                if self.timeElapsed > self.duration {
                    self.stop(true)
                    return
                }
                
                self.timeElapsed +=  TimeInterval(duration)/TimeInterval(IMPRTTimer.nanos_per_sec)
                let atTime = (self.timeElapsed/self.duration).float
                self.updateHandler(TimeInterval(self.timingFunction(atTime > 1 ? 1 : atTime)))
            })
            
            self.timer?.start()
        }
        else {
            self.stop(true)
        }
    }
    
    func stop(_ flag:Bool) {
        removeFromList()
        timer?.stop()
        timer = nil
        if let c = self.completeHandler {
            DispatchQueue.main.async {
                c(flag)
            }
        }
    }
}
