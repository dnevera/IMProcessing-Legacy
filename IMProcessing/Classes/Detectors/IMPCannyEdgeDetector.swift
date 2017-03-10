//
//  IMPCannyEdgeDetection.swift
//  IMPCameraManager
//
//  Created by denis svinarchuk on 10.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal

public class IMPSobelEdgeDetection: IMPDerivative {
    public required init(context: IMPContext, name: String?=nil) {
        super.init(context:context, name:name, functionName:"fragment_sobelEdge")
    }
    
    public required init(context: IMPContext, name: String?, functionName: String) {
        fatalError("IMPSobelEdgeDetection:init(context:name:functionName:) has been already implemented")
    }
    
    public override func configure() {
        extendName(suffix: "XY")
        super.configure()
    }
}

public class IMPCannyEdgeDetector: IMPFilter{
    
    public static let defaultBlurRadius:Float = 2
    
    public var blurRadius:Float {
        set{
            blurFilter.radius = newValue
            //dirty = true
        }
        get { return blurFilter.radius }
    }
    
    public override func configure() {
        extendName(suffix: "CannyEdgeDetector")
        super.configure()
        
        add(function: luminance)
        add(filter: blurFilter)
        add(filter: sobleEdgeFilter)
        
        blurRadius = IMPCannyEdgeDetector.defaultBlurRadius
    }
    
    private lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    private lazy var luminance:IMPFunction = IMPFunction(context: self.context, kernelName: "kernel_luminance")
    private lazy var sobleEdgeFilter:IMPSobelEdgeDetection = IMPSobelEdgeDetection(context: self.context)
}
