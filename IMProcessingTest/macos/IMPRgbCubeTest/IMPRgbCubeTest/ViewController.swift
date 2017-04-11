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
import IMProcessing



class ViewController: NSViewController {
    
    lazy var gridView:IMPPatchesGridView = IMPPatchesGridView(frame: self.view.bounds)

    lazy var rgbCubeView:IMPRgbCubeView = IMPRgbCubeView(frame: self.view.bounds)
    lazy var lchCylinderView:IMPHsvCylinderView = IMPHsvCylinderView(frame: self.view.bounds)

    lazy var tabView:NSTabView = NSTabView(frame: self.view.bounds)
    
    lazy var cubeTabItem:NSTabViewItem = {
        var i = NSTabViewItem(identifier: "RGB Cube")
        i.label = "RGB Cube"
        i.view = self.rgbCubeView
        return i
    }()
    
    lazy var lchTabItem:NSTabViewItem = {
        var i = NSTabViewItem(identifier: "HSV Cylinder")
        i.label = "HSV Cylinder"
        i.view = self.lchCylinderView
        return i
    }()

    lazy var test:IMPFilter = {
        let  f = IMPFilter(context:self.context)
        f.extendName(suffix: "ViewController test filter")
        return f
    } ()
    
    let context = IMPContext()
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        f.extendName(suffix: "ViewController filter")
        
        f => self.detector --> { (destination) in
            guard let size = destination.size else { return }
            DispatchQueue.main.async {
                self.rgbCubeView.grid = self.detector.patchGrid
            }
            DispatchQueue.main.async {
                self.lchCylinderView.grid = self.detector.patchGrid
            }
            DispatchQueue.main.async {
                self.gridView.grid = self.detector.patchGrid
            }
        }
        
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
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1).cgColor
        
        imageView.exactResolutionEnabled = false
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        imageView.addSubview(gridView)
        
        view.addSubview(imageView)
        //view.addSubview(rgbCubeView)
        view.addSubview(tabView)
        
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.superview!).offset(0)
            make.right.equalTo(imageView.superview!.snp.centerX).offset(100)
            make.top.equalTo(imageView.superview!).offset(0)
            make.bottom.equalTo(imageView.superview!).offset(0)
        }

        gridView.snp.makeConstraints { (make) in
            make.left.equalTo(gridView.superview!).offset(0)
            make.right.equalTo(gridView.superview!).offset(0)
            make.top.equalTo(gridView.superview!).offset(0)
            make.bottom.equalTo(gridView.superview!).offset(0)
        }

        tabView.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.snp.right).offset(0)
            make.right.equalTo(tabView.superview!).offset(0)
            make.top.equalTo(tabView.superview!).offset(0)
            make.bottom.equalTo(imageView.snp.bottom).offset(0)
        }

        tabView.addTabViewItem(lchTabItem)
        tabView.addTabViewItem(cubeTabItem)
        
//        rgbCubeView.snp.makeConstraints { (make) in
//            make.left.equalTo(imageView.snp.right).offset(0)
//            make.right.equalTo(rgbCubeView.superview!).offset(0)
//            make.top.equalTo(rgbCubeView.superview!).offset(0)
//            make.bottom.equalTo(imageView.snp.bottom).offset(0)
//        }

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

