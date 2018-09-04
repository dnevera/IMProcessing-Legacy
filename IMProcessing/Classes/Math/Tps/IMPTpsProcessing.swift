//
//  TpsSolver.swift
//  IMProcessing
//
//  Created by denn on 10.08.2018.
//  Copyright © 2018 Dehancer. All rights reserved.
//

import Foundation

public class IMPTpsProcessing: IMPTransformable {
    
    public typealias Vector = float3
    
    public var points: [Vector] = []
    
    public var lambda: Float = 1
    
    public init(points:[Vector]?=nil,
                controls:IMPControlPoints<Vector>?=nil,
                lambda:Float = 1,
                complete:((_ points:[Vector])->Void)? = nil) {
        
        self.lambda = lambda
        
        if let s = points {
            self.points = s
        }
        if let controls = controls,
            controls.p.count == controls.q.count && controls.p.count > 0 && self.points.count > 0 {
            try? process(controls: controls, complete: complete)
        }
    }
}

extension IMPTpsProcessing {
    
    public func process(controls: IMPControlPoints<Vector>, complete: (([Vector]) -> Void)?) throws {
        
        var cp = controls.p
        var cq = controls.q
        let count = Int32(cp.count)
        
        let tps = IMPTpsSolver(&cp, destination: &cq, count: count, lambda:lambda)

        var result = [Vector](repeating: Vector(), count: points.count)
        
        for (i,p) in points.enumerated() {
            result[i] = tps.value(p)
        }
        
        complete?(result)
    }
}
