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
    
    func update(detector:IMPCCheckerDetector, destination:IMPImageProvider)  {
        guard let size = destination.size else { return }
        
        Swift.print("Size: \(size) Corners: \(detector.corners)")
        
        DispatchQueue.main.async {
            // set absolute size of image to right scale of view canvas
            self.markersView.imageSize = size
            // set corners 
            self.markersView.corners = detector.corners
            
            // draw patches
            self.gridView.grid = detector.patchGrid
        }
    }
    
    //
    // Just redirect image rendering in IMPFilterView
    //
    lazy var filter:IMPFilter = {
        
        let detector = IMPCCheckerDetector(context: self.context, maxSize:800)
        
        let f = IMPFilter(context: self.context)
        
        f
            // add debug info
            .extendName(suffix: "ViewController filter")
            // add source image frame redirection to next filter
            // (multiplex operation)
            .addRedirection(to: detector)
            // add processing action to redirected filter
            .addProcessing { destination in
                self.update(detector: detector, destination: destination)
        }
        
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
    
    lazy var gridView:PatchesGridView = PatchesGridView(frame: self.view.bounds)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(targetView)
        targetView.addSubview(markersView)
        targetView.addSubview(gridView)
        
        targetView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(20)
        }
        
        gridView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }

}

