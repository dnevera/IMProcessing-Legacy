//
//  IMPRGBCurvesFilter.swift
//  IMPCurvesViewTest
//
//  Created by Denis Svinarchuk on 02/07/16.
//  Copyright © 2016 IMProcessing. All rights reserved.
//

import Foundation
import IMProcessing

public class IMPRGBCurvesFilter:IMPCurvesFilter {    
    public required convenience init(context: IMPContext, curveFunction:IMPCurveFunction) {
        self.init(context: context, name: "kernel_adjustRGBWCurves", curveFunction:curveFunction)
    }
    public required convenience init(context: IMPContext) {
        self.init(context: context, name: "kernel_adjustRGBWCurves", curveFunction:.Cubic)
    }
}
