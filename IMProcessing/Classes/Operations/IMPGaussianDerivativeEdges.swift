//
//  IMPGaussianDerivative.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 24.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public class IMPGaussianDerivativeEdges: IMPFilter{
    public override func configure() {
        extendName(suffix: "GaussianDerivativeEdges")
        add(function: gaussianDerivative)
    }
    lazy var gaussianDerivative:IMPFunction = {
        return IMPFunction(context: self.context, kernelName: "kernel_gaussianDerivativeEdge")
    }()
}
