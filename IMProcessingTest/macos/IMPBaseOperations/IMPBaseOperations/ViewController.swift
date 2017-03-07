//
//  ViewController.swift
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 06.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import SnapKit

public class TestFilter: IMPFilter {
    
    lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    
    public var blurRadius:Float = 0 {
        didSet{
            blurFilter.radius = blurRadius
        }
    }
    
    public var ciBlurRadius:Float = 0 {
        didSet{
            ciBlurFilter.setValue(NSNumber(value:ciBlurRadius), forKey: "inputRadius")
            dirty = true
        }
    }
    
    public var inputEV:Float = 0 {
        didSet{
            print("exposure MTL EV = \(inputEV)")
            print("exposure CI EV = \(ci_inputEV)")
            dirty = true
        }
    }
    
    public var ci_inputEV:Float = 0 {
        didSet{
            exposureFilter.setValue(ci_inputEV, forKey: "inputEV")
            print("exposure MTL EV = \(inputEV)")
            print("exposure CI EV = \(ci_inputEV)")
            dirty = true
        }
    }
    
    public var redAmount:Float = 1 {
        didSet{
            dirty = true
        }
    }
    
    lazy var kernelRedBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    lazy var kernelRed:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_red")
        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            var value  = self.redAmount
            var buffer = self.kernelRedBuffer
            memcpy(buffer.contents(), &value, buffer.length)
            commandEncoder.setBuffer(buffer, offset: 0, at: 0)
        }
        return f
    }()
    
    lazy var kernelEVBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    lazy var kernelEV:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_EV")
        f.optionsHandler = { (kernel,commandEncoder, input, output) in
            var value  = self.inputEV
            var buffer = self.kernelEVBuffer
            memcpy(buffer.contents(), &value, buffer.length)
            commandEncoder.setBuffer(buffer, offset: 0, at: 0)
        }
        return f
    }()
    
    override public func configure(_ withName: String?) {
        super.configure("Test filter")
        add(function: kernelRed)
        add(function: kernelEV)
        add(filter: exposureFilter)
        add(filter: blurFilter)
        add(filter: ciBlurFilter)
    }
    
    private lazy var exposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    private lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
}


class ViewController: NSViewController {

    lazy var filter:TestFilter = TestFilter(context: self.context)
    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))

    var context:IMPContext = IMPContext()
    var currentImage:IMPImageProvider? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        imageView.clearColor = MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        imageView.filter = filter
        
        view.addSubview(imageView)
        
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.superview!).offset(0)
            make.right.equalTo(imageView.superview!).offset(0)
            make.top.equalTo(imageView.superview!).offset(0)
            make.bottom.equalTo(imageView.superview!).offset(-80)
        }
        
        let blurSlider = NSSlider(value: 0, minValue: 0, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
        blurSlider.tag = 100
        
        view.addSubview(blurSlider)
        
        blurSlider.snp.makeConstraints { (make) in
            make.left.equalTo(blurSlider.superview!).offset(20)
            make.bottom.equalTo(blurSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }
        
        let ciBlurSlider = NSSlider(value: 0, minValue: 0, maxValue: 32, target: self, action: #selector(sliderHandler(sender:)))
        ciBlurSlider.floatValue = 0
        ciBlurSlider.tag = 101
        
        view.addSubview(ciBlurSlider)
        
        ciBlurSlider.snp.makeConstraints { (make) in
            make.left.equalTo(blurSlider.snp.right).offset(20)
            make.bottom.equalTo(ciBlurSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        let evSlider = NSSlider(value: 0, minValue: -3, maxValue: 3, target: self, action: #selector(sliderHandler(sender:)))
        evSlider.floatValue = 0
        evSlider.tag = 102
        
        view.addSubview(evSlider)
        
        evSlider.snp.makeConstraints { (make) in
            make.left.equalTo(ciBlurSlider.snp.right).offset(20)
            make.bottom.equalTo(evSlider.superview!.snp.bottom).offset(-20)
            make.width.equalTo(200)
        }

        
        IMPFileManager.sharedInstance.add { (file, type) in
            if let im = NSImage(contentsOfFile: file) {
                //self.currentImage = IMPImage(context: self.context, path: file)
                self.currentImage = IMPImage(context: self.context, image: im)
                NSLog("open file \(file)")
                self.filter.source = self.currentImage
            }
        }
        
    }

    func sliderHandler(sender:NSSlider)  {
        filter.context.runOperation(.async) {
            switch sender.tag {
            case 100:
                self.filter.blurRadius = sender.floatValue
            case 101:
                self.filter.ciBlurRadius = sender.floatValue
            case 102:
                self.filter.inputEV = sender.floatValue
            default:
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

