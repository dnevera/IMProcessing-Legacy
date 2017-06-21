//
//  IMPCurveFunction.swift
//  IMPCurveTest
//
//  Created by denis svinarchuk on 16.06.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public enum IMPCurveFunction: String {
    
    case cubic       = "Cubic"
    case catmullRom  = "CatmullRom"
    case bezier      = "Bezier"
    
    public var curve:IMPCurve {
        switch self {
        case .catmullRom:
            return IMPCurve(function: IMPCurveFunction.CatmullRom)
        case .bezier:
            return IMPCurve(maxControlPoints: 2, function: IMPCurveFunction.Bezier)
        default:
            return IMPCurve(function: IMPCurveFunction.Cubic)
        }
    }
    
    public static var CatmullRom:IMPCurve.FunctionType = { (controls, segments, userInfo) -> [Float] in
        var c = [float2](controls)
        if c.count == 2 {
            c.append(float2(1))
        }
        return segments.catmullRomSpline(controls: c)
    }
    
    public static var Cubic:IMPCurve.FunctionType = { (controls, segments, userInfo) -> [Float] in
        return segments.cubicSpline(controls: controls)
    }
    
    public static var Bezier:IMPCurve.FunctionType = { (controls, segments, userInfo) -> [Float] in
        return segments.cubicBezierSpline(controls: controls)
    }
    
}

