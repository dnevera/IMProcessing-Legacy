//
//  IMPTpsFilter.swift
//  CryptoSwift
//
//  Created by denn on 16.08.2018.
//

import Foundation

public class IMPTpsFilter: IMPTpsTransform {
    
    public override var kernelName:String {
        return "kernel_tpsLutTransform"
    }
    
    override public func configure(complete: IMPFilter.CompleteHandler?) {
        
        super.extendName(suffix: "TPS Filter")
        super.configure(complete: nil)
        
        let kernel = IMPFunction(context: self.context, kernelName: kernelName)
        
        kernel.optionsHandler = {(shader, commandEncoder, input, output) in
            
//            commandEncoder.setBytes(&self.reference,
//                                    length: MemoryLayout.size(ofValue: self.reference),
//                                    index: 0)
            
            var index = self.space.index
            commandEncoder.setBytes(&index,
                                    length: MemoryLayout.size(ofValue: index),
                                    index: 0)
            
            commandEncoder.setBuffer(self.weightBuffer,
                                     offset: 0,
                                     index: 1)
            
            commandEncoder.setBuffer(self.qBuffer,
                                     offset: 0,
                                     index: 2)
            
            var count = self.controls.p.count
            commandEncoder.setBytes(&count,
                                    length: MemoryLayout.stride(ofValue: count),
                                    index: 3)
            
        }
        
        add(function: kernel) { (image) in
            complete?(image)
        }
    }
}
