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

    var canvas = IMPCanvasView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))

    let context = IMPContext()
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        
        (f => self.detector).process()
        
        return f
    }()
    
    lazy var detector:IMPCCheckerDetector = IMPCCheckerDetector(context: self.context)

    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))
    
    var currentImage:IMPImageProvider? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        detector --> { (destination) in
            guard let size = destination.size else { return }
            DispatchQueue.main.async {
                self.canvas.imageSize = size
                self.canvas.hlines = self.detector.hLines
                self.canvas.vlines = self.detector.vLines
                self.canvas.grid = self.detector.patchGrid
            }
        }
        
        detector.maxSize = 800
        
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.clear.cgColor
        canvas.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]

        imageView.exactResolutionEnabled = false
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        view.addSubview(imageView)
        imageView.addSubview(canvas)

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
                detector.enabled = false
            default:
                detector.enabled = true
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

