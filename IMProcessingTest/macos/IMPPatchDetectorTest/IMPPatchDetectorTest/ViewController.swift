//
//  ViewController.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import CoreGraphics
import SnapKit


class ViewController: NSViewController {

    lazy var canvas:IMPCanvasView = IMPCanvasView(frame:self.view.bounds)
    lazy var gridView:IMPPatchesGridView = IMPPatchesGridView(frame: self.view.bounds)
    
    
    lazy var test:IMPFilter = {
        let  f = IMPFilter(context:self.context)
        f.extendName(suffix: "ViewController test filter")
        return f
    } ()
    
    let context = IMPContext()
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        f.extendName(suffix: "ViewController filter")
        //(
        
        f => self.test --> self.detector --> { (destination) in
            guard let size = destination.size else { return }
            DispatchQueue.main.async {
                self.canvas.imageSize = size
                //self.canvas.corners = self.detector.corners
                //self.canvas.hlines = self.detector.hLines
                //self.canvas.vlines = self.detector.vLines
                self.canvas.grid = self.detector.patchGrid
                self.gridView.grid = self.detector.patchGrid
            }
        }//).process()
        
        return f
    }()
    
    lazy var detector:IMPCCheckerDetector = {
        let f = IMPCCheckerDetector(context: self.context)
        f.maxSize = 800
        return f
    }()

    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))
    
    var currentImage:IMPImageProvider? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        gridView.wantsLayer = true
        gridView.frame = view.bounds
        gridView.layer?.backgroundColor = NSColor.clear.cgColor
        //gridView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
        canvas.wantsLayer = true
        canvas.frame = view.bounds
        canvas.layer?.backgroundColor = NSColor.clear.cgColor
        canvas.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
        
        imageView.exactResolutionEnabled = false
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        view.addSubview(imageView)
        //view.addSubview(gridView)
        
        //imageView.addSubview(canvas)
        imageView.addSubview(gridView)

        gridView.snp.makeConstraints { (make) in
            make.left.equalTo(gridView.superview!).offset(0)
            make.right.equalTo(gridView.superview!).offset(0)
            make.top.equalTo(gridView.superview!).offset(0)
            make.bottom.equalTo(gridView.superview!).offset(0)
        }
        
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.superview!).offset(0)
            make.right.equalTo(imageView.superview!).offset(0)
            make.top.equalTo(imageView.superview!).offset(0)
            make.bottom.equalTo(imageView.superview!).offset(-80)
        }
        
        IMPFileManager.sharedInstance.add { (file, type) in
            self.currentImage = IMPImage(context: self.context, path: file, maxSize: 2000)
            NSLog("open file \(file)")
            self.filter.source = self.currentImage
        }
        
        let tap1 = NSPressGestureRecognizer(target: self, action: #selector(clickHandler(gesture:)))
        tap1.minimumPressDuration = 0.01
        tap1.buttonMask = 1
        imageView.addGestureRecognizer(tap1)
        
        let tap2 = NSPressGestureRecognizer(target: self, action: #selector(clickHandler(gesture:)))
        tap2.minimumPressDuration = 0.01
        tap2.buttonMask = 1<<1
        imageView.addGestureRecognizer(tap2)
    }
    
    func clickHandler(gesture:NSClickGestureRecognizer)  {
        
        if  gesture.buttonMask == 1 {
            
            switch gesture.state {
            case .began:
                filter.enabled = false
            default:
                filter.enabled = true
                break
            }
            
        }
    }


    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

