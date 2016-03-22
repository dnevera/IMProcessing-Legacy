//
//  ViewController.swift
//  IMProcessingiOS
//
//  Created by denis svinarchuk on 24.12.15.
//  Copyright © 2015 ImageMetalling. All rights reserved.
//

import UIKit
import IMProcessing
import SnapKit

let TEST_CAMERA = true
let BLUR_FILTER = false


class IMPTestFilter: IMPFilter {
    
    var rangeSolver = IMPHistogramRangeSolver()
    var contrast:IMPContrastFilter!
    var histogram:IMPHistogramAnalyzer!
    
    required init(context: IMPContext) {
        super.init(context: context)
        
        histogram = IMPHistogramAnalyzer(context: context, hardware: .GPU)
        
        histogram.downScaleFactor = 0.5
        
        rangeSolver.clipping.shadows = 0.1
        rangeSolver.clipping.highlights = 0.1
        
        histogram.addSolver(rangeSolver)
        
        histogram.addUpdateObserver { (histogram) -> Void in
            self.contrast.adjustment.minimum = self.rangeSolver.minimum
            self.contrast.adjustment.maximum = self.rangeSolver.maximum
        }
        
        contrast = IMPContrastFilter(context: context)
        
        contrast.addSourceObserver { (source) -> Void in
            //let t1 = NSDate.timeIntervalSinceReferenceDate()
            self.histogram.source = source
            //let t2 = NSDate.timeIntervalSinceReferenceDate()
            //print(" hist\(self.histogram.hardware) time = \(t2-t1)")
        }
        
        addFilter(contrast)
    }
}


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    var cameraManager:IMPCameraManager!
    var containerView:UIView!
    
    var imageView:IMPImageView!
    var blur:IMPGaussianBlurFilter!
    var test:IMPTestFilter!
    
    var filter:IMPFilter?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.view.backgroundColor = IMProcessing.css.background

        let context = IMPContext(lazy: true)
        
        if BLUR_FILTER {
            blur = IMPGaussianBlurFilter(context: context)
            filter = blur
        }
        else{
            test = IMPTestFilter(context: context)
            filter = test
        }
        

        if !TEST_CAMERA {
            imageView = IMPImageView(context: (filter?.context)!,  frame: CGRectMake( 0, 20,
                self.view.bounds.size.width,
                self.view.bounds.size.height*3/4
                ))
            self.view.insertSubview(imageView, atIndex: 0)
            
            imageView.filter = filter
        }
        else {
            containerView = UIView(frame: CGRectMake( 0, 20,
                self.view.bounds.size.width,
                self.view.bounds.size.height*3/4
                ))
            self.view.insertSubview(containerView, atIndex: 0)
            
            
            cameraManager = IMPCameraManager(containerView: containerView)
            
            cameraManager.liveView.filter = filter
            
            cameraManager.start { (granted) -> Void in
                
                if !granted {
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        let alert = UIAlertController(
                            title:   "Camera is not granted",
                            message: "This application does not have permission to use camera. Please update your privacy settings.",
                            preferredStyle: .Alert)
                        
                        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { action -> Void in }
                        alert.addAction(cancelAction)
                        
                        let settingsAction = UIAlertAction(title: "Settings", style: .Default) { action -> Void in
                            if let appSettings = NSURL(string: UIApplicationOpenSettingsURLString) {
                                UIApplication.sharedApplication().openURL(appSettings)
                            }
                        }
                        alert.addAction(settingsAction)
                        
                        self.presentViewController(alert, animated: true, completion: nil)
                    })
                }
            }
            
        }

        let albumButton = UIButton(type: .System)
        
        albumButton.backgroundColor = IMPColor.clearColor()
        albumButton.tintColor = IMPColor.whiteColor()
        albumButton.setImage(IMPImage(named: "select-photos"), forState: .Normal)
        albumButton.addTarget(self, action: #selector(ViewController.openAlbum(_:)), forControlEvents: .TouchUpInside)
        view.addSubview(albumButton)
        
        albumButton.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-40)
            make.left.equalTo(view).offset(40)
        }

        let slider = UISlider()
        slider.value = 0
        slider.addTarget(self, action: #selector(ViewController.changeValue(_:)), forControlEvents: .ValueChanged)
        view.addSubview(slider)
        
        slider.snp_makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-40)
            if TEST_CAMERA {
                make.left.equalTo(view).offset(20)
            }
            else {
                make.left.equalTo(albumButton.snp_right).offset(20)
            }
            make.right.equalTo(view).offset(-20)
        }
        
        if !TEST_CAMERA{
            IMPMotionManager.sharedInstance.addRotationObserver { (orientation) -> Void in
                self.imageView.setOrientation(orientation, animate:true)
            }
        }
        else {
            albumButton.hidden = true
        }
    }
    
    internal func changeValue(sender:UISlider){
        dispatch_async(filter!.context.dispatchQueue) { () -> Void in
            if BLUR_FILTER {
                self.blur.radius = (128 * sender.value).int
            }
            else{
                //self.hsv.adjustment.greens.hue = (sender.value - 0.5) * 2
                self.test.contrast.adjustment.blending.opacity = sender.value
            }
        }
    }
    
    internal func openAlbum(sender:UIButton){
        imagePicker = UIImagePickerController()
    }
    
    private var imagePicker:UIImagePickerController!{
        didSet{
            self.imagePicker.delegate = self
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            if let actualPicker = self.imagePicker{
                self.presentViewController(actualPicker, animated:true, completion:nil)
            }
        }
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        let chosenImage:UIImage? = info[UIImagePickerControllerOriginalImage] as? UIImage
        
        if let actualImage = chosenImage{
            
            let image = IMPImageProvider(context: imageView.context, image: actualImage, maxSize: 1500)
            imageView?.source = image
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

