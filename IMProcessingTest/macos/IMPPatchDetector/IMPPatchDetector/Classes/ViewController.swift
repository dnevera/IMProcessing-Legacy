//
//  ViewController.swift
//  IMPPatchDetector
//
//  Created by denn on 07.07.2018.
//  Copyright © 2018 Dehancer. All rights reserved.
//

import Cocoa
import IMProcessing
import SnapKit

class ViewController: NSViewController {
    
    let context = IMPContext()
    
    var imagePath:String? {
        didSet{
            if let path = imagePath {
                filter.source = IMPImage(context: context, path: path)
            }
        }
    }
    
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        f.extendName(suffix: "ViewController filter")
        
        f => self.detector --> { (destination) in
            guard let size = destination.size else { return }
            
            Swift.print("Size: \(size) Corners: \(self.detector.corners)")
            
            DispatchQueue.main.async {
                self.markersView.imageSize = size
                self.markersView.corners = self.detector.corners
            }
        }
        
        return f
    }()
    
    lazy var detector:IMPCCheckerDetector = {
        let f = IMPCCheckerDetector(context: self.context)
        f.maxSize = 800
        f.addObserver(newSource: { (source) in
            NSLog("Detector filter source... updated")
        })
        return f
    }()
    
    lazy var targetView:IMPFilterView = {
        let f = IMPFilterView()
        f.filter = self.filter
        return f
    }()
    
    lazy var markersView:MarkersView = {
        let v = MarkersView(frame:self.view.bounds)
        
        v.wantsLayer = true
        v.frame = self.targetView.bounds
        v.layer?.backgroundColor = NSColor.clear.cgColor
        v.autoresizingMask = [.width, .height]
        
        return v
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(targetView)
        targetView.addSubview(markersView)
        
        targetView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(20)
        }
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }
    
    
}

