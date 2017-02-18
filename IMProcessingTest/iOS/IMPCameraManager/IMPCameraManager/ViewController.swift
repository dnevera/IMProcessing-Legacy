//
//  ViewController.swift
//  DehancerI-CropEditor
//
//  Created by Denis Svinarchuk on 07/12/16.
//  Copyright © 2016 Dehancer. All rights reserved.
//

import UIKit
import IMProcessing
import SnapKit
import MetalPerformanceShaders

class BaseNavigationController: UINavigationController {

    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    return CGRect(x: x, y: y, width: width, height: height)
}


public class TestFilter: IMPFilter {
    
    lazy var impBlurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)
    
    public var blurRadius:Float = 1 {
        didSet{
            if context.supportsGPUv2 {
                blurFilter.sigma = blurRadius
            }
            else {
                //ciBlurFilter.setValue(blurRadius, forKey: "inputRadius")
                impBlurFilter.radius = blurRadius.int
            }
            dirty = true
        }
    }
    
    public var inputEV:Float = 1 {
        didSet{
            dirty = true
        }
    }
    

    lazy var kernelEVBuffer:MTLBuffer = self.context.device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    lazy var kernelEV:IMPFunction = {
        let f = IMPFunction(context: self.context, name: "kernel_EV")
        f.optionsHandler = { (kernel,commandEncoder) in
            var value  = self.inputEV
            var buffer = self.kernelEVBuffer
            memcpy(buffer.contents(), &value, buffer.length)
            commandEncoder.setBuffer(buffer, offset: 0, at: 0)
        }
        return f
    }()
    
    override public func configure(_ withName: String?) {
        super.configure("Test filter")
        add(function: kernelEV)
        
        if context.supportsGPUv2 {
            add(mps: blurFilter)
        }
        else {
            //add(filter: ciBlurFilter)
            add(filter: impBlurFilter)
        }
        
        inputEV = 2
        blurRadius = 20
    }
    
    private lazy var exposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
    private lazy var ciBlurFilter:CIFilter = CIFilter(name:"CIGaussianBlur")!
    
    class BlurFilter: IMPMPSUnaryKernelProvider {
        var name: String { return "BlurFilter" }
        func mps(device:MTLDevice) -> MPSUnaryImageKernel? {
            return MPSImageGaussianBlur(device: device, sigma: sigma)
        }
        var sigma:Float = 1
        var context: IMPContext?
        init(context:IMPContext?) {
            self.context = context
        }
    }
    
    lazy var blurFilter:BlurFilter = BlurFilter(context:self.context)
}


class ViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    let context = IMPContext(lazy: true)
    
    lazy var containerView:UIView = {
        let y = (self.navigationController?.navigationBar.bounds.height)! + UIApplication.shared.statusBarFrame.height
        let v = UIView(frame: CGRectMake( 0, y,
            self.view.bounds.size.width,
            self.view.bounds.size.height*3/4
            ))
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressHandler(gesture:)))
        press.minimumPressDuration = 0.05
        v.addGestureRecognizer(press)

        //let zoom = UIPinchGestureRecognizer(target: self, action: #selector(self.zoomHandler(sender:)))
        //v.addGestureRecognizer(zoom)

        return v
    }()
    
    
    lazy var cameraManager:IMPCameraManager = {
        
        let c = IMPCameraManager(containerView: self.containerView, context: IMPContext(lazy: true))
        if !c.context.supportsGPUv2 {
            //
            // 5s
            //
            //c.frameRate = 24
            //c.scaleFactor = DHCommon.settings[.Camera][.downScaleFactor].value
        }
        else {
            //c.frameRate = 30
        }
        
        //c.addLiveViewReadyObserver({ (camera) in
         //   self.dehancerLiveViewFilter.enabled = true
        //})
        
        return c
    }()
    
    
    lazy var liveViewFilter:TestFilter = {
        let f = TestFilter(context: self.context)
        return f
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = NSColor.black
        self.view.insertSubview(containerView, at: 0)

        
        let triggerButton = UIButton(frame: CGRectMake(0, 0, 90, 90))
        
        triggerButton.backgroundColor = NSColor.clear
        
        triggerButton.setImage(NSImage(named: "shutterUp"), for: .normal)
        triggerButton.setImage(NSImage(named: "shutterDown"), for: .selected)
        triggerButton.setImage(NSImage(named: "shutterDown"), for: .highlighted)
        
        triggerButton.addTarget(self, action: #selector(self.capturePhoto(sender:)), for: .touchUpInside)
        view.addSubview(triggerButton)
        
        triggerButton.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-20)
            make.centerX.equalTo(view.snp.centerX).offset(0)
        }
        
        cameraManager.liveView.filter = liveViewFilter
        
        NSLog("starting ...")
        
        //cameraManager.addLiveViewReadyObserver { (camera) in
        //    NSLog("live view is ready ...")
        //}
        
        cameraManager.start { (granted) -> Void in
            
            NSLog("started ...")
            
            if !granted {
                DispatchQueue.main.async{
                    
                    let alert = UIAlertController(
                        title:   "Camera is not granted",
                        message: "This application does not have permission to use camera. Please update your privacy settings.",
                        preferredStyle: .alert)
                    
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in }
                    alert.addAction(cancelAction)
                    
                    let settingsAction = UIAlertAction(title: "Settings", style: .default) { action -> Void in
                        if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
                            UIApplication.shared.open(appSettings as URL, options: [:], completionHandler: { (completed) in
                                
                            })
                        }
                    }
                    alert.addAction(settingsAction)                    
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func pressHandler(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            liveViewFilter.enabled = false
        }
        else if gesture.state == .ended {
            liveViewFilter.enabled = true
        }
    }
    
//    var scaleZoomFactor:CGFloat = 1
//
//    func zoomHandler(gesture:UIPinchGestureRecognizer) {
//        let currentScale = cameraManager.zoomFactor.cgfloat
//
//        if gesture.state == .began {
//            gesture.scale = currentScale
//        }
//        else if gesture.state == .changed {
//            scaleZoomFactor = gesture.scale
//        }
//        
//        scaleZoomFactor = fmin(scaleZoomFactor, fmin(cameraManager.maximumZoomFactor.cgfloat,10) )
//        scaleZoomFactor = fmax(scaleZoomFactor, 1 )
//        
//        cameraManager.setZoom(factor: scaleZoomFactor.float, animate: false) { (camera, factor) in
//            print("zoom factor = \(factor, self.scaleZoomFactor, currentScale, gesture.scale) max = \(self.cameraManager.maximumZoomFactor.cgfloat)")
//        }
//    }
//    
    
    func capturePhoto(sender:UIButton)  {
        print("capture")
//        cameraManager.capturePhoto{ (camera, finished, file, metadata, error) in
//            if error == nil {
//                print("\(error)")
//            }
//        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        cameraManager.pause()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        cameraManager.resume()
    }
}
