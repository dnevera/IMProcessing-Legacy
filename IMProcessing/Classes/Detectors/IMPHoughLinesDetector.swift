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
            //self.readLines(self.destination)
            //process()
            //readLines(destination)
            
            let hough = IMPHoughSpace(image: self.destination)
            
            guard let size = destination.size else {
                return
            }
            
            if let lines = hough?.getLines(threshold: 20) {
                print("   size = \(size)")
                print(lines)
                if lines.count > 0 {
                    for l in linesObserverList {
                        l(lines, size)
                    }
                }
            }
        }
    }
    
    public override func configure() {
        extendName(suffix: "HoughLinesDetector")
        super.configure()
        maxSize = 400
        blurRadius = 2
        
//        addObserver(destinationUpdated: { (destination) in
//            self.readLines(destination)
//
//        })
        
        //add(function:houghTransformKernel){ (result) in
         //   print("houghTransformKernel....")
        //}
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
        
        if let (buffer,bytesPerRow,imageSize) = destination.read() {
            
            let rawPixels = buffer.contents().bindMemory(to: UInt8.self, capacity: imageSize)
            
            print(" readLines width,height \(width,height)")
            
            let hough = IMPHoughSpace(image: rawPixels,
                                   bytesPerRow: bytesPerRow,
                                   width: width,
                                   height: height)
            
            let lines = hough.getLines(threshold: 20)
            
            if lines.count > 0 {
                for l in linesObserverList {
                    l(lines, size)
                }
            }
            
        }
        isReading = false
    }

    func addObserver(lines observer: @escaping LinesListObserver) {
        linesObserverList.append(observer)
    }
    
    private lazy var linesObserverList = [LinesListObserver]()
    
}
