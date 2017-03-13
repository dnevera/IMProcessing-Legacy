//
//  IMPHoughLinesDetector.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 11.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal


public class IMPHoughLinesDetector: IMPCannyEdgeDetector {
    
    public typealias LinesListObserver = ((_ lines: [IMPLineSegment], _ imageSize:NSSize) -> Void)
    
    public override var source: IMPImageProvider? {
        didSet{
            self.readLines(self.destination)
        }
    }
    
    public override func configure() {
        extendName(suffix: "HoughLinesDetector")
        super.configure()
        maxSize = 800
        
        //add(function:houghTransformKernel){ (result) in
         //   print("houghTransformKernel....")
        //}
    }
    
    var rawPixels:UnsafeMutablePointer<UInt8>?
    var imageByteSize:Int = 0
    
    deinit {
        rawPixels?.deallocate(capacity: imageByteSize)
    }
    
    private var isReading = false
    
    private lazy var houghTransformKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_houghTransformAtomic")
        f.optionsHandler = { (function,commandEncoder, input, output) in
            
            //commandEncoder.setBuffer(self.hTexelSizeBuffer, offset: 0, at: 0)
            //commandEncoder.setTexture(self.weightsTexture, at:2)
            //commandEncoder.setTexture(self.offsetsTexture, at:3)
        }

        return f
    }()
    
    private func readLines(_ destination: IMPImageProvider) {
        
        guard let size = destination.size else {
            isReading = false
            return
        }

        guard !isReading else {
            isReading = false
            return
        }
        isReading = true

        let width       = Int(size.width)
        let height      = Int(size.height)
        
        var bytesPerRow:Int = 0
        if let rawPixels = destination.read(bytes: &rawPixels, length: &imageByteSize, bytesPerRow: &bytesPerRow) {

            let hough = HoughSpace(image: rawPixels,
                                   bytesPerRow: bytesPerRow,
                                   width: width,
                                   height: height)
            
            let lines = hough.getLines(threshold: 50)
            
            if lines.count > 0 {
                for l in linesObserverList {
                    l(lines, size)
                }
            }
            
            rawPixels.deallocate(capacity: imageByteSize)
        }
        rawPixels = nil

        isReading = false
    }

    func addObserver(lines observer: @escaping LinesListObserver) {
        linesObserverList.append(observer)
    }
    
    private lazy var linesObserverList = [LinesListObserver]()
    
}
