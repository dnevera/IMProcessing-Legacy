//
//  IMPDetector.swift
//  IMPBaseOperations
//
//  Created by Denis Svinarchuk on 27/03/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

open class IMPDetector: IMPResampler {
    
    public var passImmediatelyProcessing:Bool = false
    
    open override func configure(complete: IMPFilterProtocol.CompleteHandler? = nil) {
        extendName(suffix: "Detector")
        super.configure(complete: complete)
        addObserver(newSource: { (source)in
            if self.passImmediatelyProcessing {
                self.process()
            }
        })
    }
    
    open lazy var regionSize:Int = {
        return Int(sqrt(Float(self.context.maxThreads.width)))
    }()

}
