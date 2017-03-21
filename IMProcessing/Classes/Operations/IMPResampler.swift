//
//  IMPResampler.swift
//  IMPCameraManager
//
//  Created by denis svinarchuk on 11.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal
import Accelerate

open class IMPResampler: IMPFilter{
    
    public var maxSize:CGFloat? {
        didSet{
            updateResampler()
            dirty = true
        }
    }
    
    private func updateResampler(){
        resampler.flush()
        if let size = source?.size,
            let maxSize = self.maxSize {
            let scale = fmax(fmin(fmin(maxSize/size.width, maxSize/size.height),1),0.01)
            resampler.destinationSize = NSSize(width: size.width * scale, height: size.height * scale)
        }
    }
    
    public override var source: IMPImageProvider? {
        didSet{
            updateResampler()
        }
    }
    
    open override func configure() {
        extendName(suffix: "Resampler")
        super.configure()
        add(filter: resampler)
    }
    
    private lazy var resampleShader:IMPShader = IMPShader(context: self.context)
    private lazy var resampler:IMPCIFilter = { return IMPCoreImageMTLShader.register(shader: self.resampleShader)}()
}
