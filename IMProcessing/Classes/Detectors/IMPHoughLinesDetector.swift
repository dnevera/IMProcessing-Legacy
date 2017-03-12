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
        maxSize = 200
    }
    
    var rawPixels:UnsafeMutablePointer<UInt8>?
    var imageByteSize:Int = 0
    
    deinit {
        rawPixels?.deallocate(capacity: imageByteSize)
    }
    
    private var isReading = false
    
    
    private func readLines(_ destination: IMPImageProvider) {
        guard let size = destination.size else { return }

        guard !isReading else { return }
        isReading = true

        let width       = Int(size.width)
        let height      = Int(size.height)
        
        var bytesPerRow:Int = 0
        if let rawPixels = destination.read(bytes: &rawPixels, length: &imageByteSize, bytesPerRow: &bytesPerRow) {
            
            let hough = Hough(image: rawPixels,
                              bytesPerRow: bytesPerRow,
                              width: width,
                              height: height,
                              threshold: 90)
            
            let lines = hough.getLines()
            
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
