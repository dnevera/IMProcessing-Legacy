//
//  ViewController.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 05.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

//import IMProcessing
import UIKit
import Photos
import SnapKit
import CoreImage
import MetalPerformanceShaders

func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    return CGRect(x: x, y: y, width: width, height: height)
}


public class TestFilter: IMPFilter {

    lazy var blurFilter:IMPGaussianBlurFilter = IMPGaussianBlurFilter(context: self.context)

    public var blurRadius:Float = 1 {
        didSet{
            blurFilter.radius = blurRadius
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
        let f = IMPFunction(context: self.context, name: "kernel_red")
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
        let f = IMPFunction(context: self.context, name: "kernel_EV")
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
        add(filter:blurFilter)
    }
    
    private lazy var exposureFilter:CIFilter = CIFilter(name:"CIExposureAdjust")!
}


public class DownScaleFilter: IMPFilter {
    
    public var scale:Float = 1.0 {
        didSet{
            lancoz.setValue(scale, forKey: kCIInputScaleKey)
            dirty = true
        }
    }
    
    public override func configure(_ withName: String?) {
        super.configure("Downscale input filter")
        lancoz.setValue(1, forKey: kCIInputScaleKey)
        add(filter: lancoz)
    }
    
    lazy var lancoz:CIFilter = CIFilter(name: "CILanczosScaleTransform")!
}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate{

    let context = IMPContext(lazy: true)
    
    //lazy var imageView:IMPGLView = IMPGLView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    //
    // Test rendering to Metal Layer...
    //
    lazy var imageView:IMPView = IMPView(frame:CGRect(x: 0, y: 0, width: 100, height: 100))
    
    lazy var containerView:UIView = {
        let y = (self.navigationController?.navigationBar.bounds.height)! + UIApplication.shared.statusBarFrame.height
        let v = UIView(frame: CGRectMake( 0, y,
                                          self.view.bounds.size.width,
                                          self.view.bounds.size.height*3/4
        ))
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressHandler(gesture:)) )
        press.minimumPressDuration = 0.05
        v.addGestureRecognizer(press)
        
        return v
    }()

    
    func pressHandler(gesture:UILongPressGestureRecognizer)  {
        if gesture.state == .began{
            imageView.filter?.enabled = false
        }
        else if gesture.state == .ended{
            imageView.filter?.enabled = true
        }
    }
    
    var blurSlider = UISlider(frame: CGRect(x: 0, y: 0, width: 150, height: 10))
    var inputEVSlider = UISlider(frame: CGRect(x: 0, y: 0, width: 150, height: 10))
    var ci_inputEVSlider = UISlider(frame: CGRect(x: 0, y: 0, width: 150, height: 10))
    var redSlider = UISlider(frame: CGRect(x: 0, y: 0, width: 150, height: 10))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(containerView)
        
        imageView.exactResolutionEnabled = false
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        imageView.frame = containerView.bounds
        imageView.backgroundColor = NSColor.init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        
        imageView.filter = testFilter
        
        testFilter.blurRadius = 0
        
        containerView.addSubview(imageView)
        
        view.backgroundColor = UIColor.black
        
        let albumButton = UIButton(frame: CGRectMake(0, 0, 90, 90))
        
        albumButton.backgroundColor = UIColor.clear
        albumButton.setImage(UIImage(named: "film-roll"), for: .normal)
        albumButton.addTarget(self, action: #selector(openAlbum(sender:)), for: .touchUpInside)
        view.addSubview(albumButton)
        
        albumButton.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-35)
            make.centerX.equalTo(view.snp.centerX).offset(-view.bounds.width/3)
        }
        
        view.addSubview(redSlider)
        redSlider.value = 0
        redSlider.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-110)
            make.left.equalTo(albumButton.snp.right).offset(20)
            make.right.equalTo(view.snp.right).offset(-10)
        }

        view.addSubview(inputEVSlider)
        inputEVSlider.value = 0
        inputEVSlider.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-80)
            make.left.equalTo(albumButton.snp.right).offset(20)
            make.right.equalTo(view.snp.right).offset(-10)
        }
        
        view.addSubview(ci_inputEVSlider)
        ci_inputEVSlider.value = 0
        ci_inputEVSlider.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-50)
            make.left.equalTo(albumButton.snp.right).offset(20)
            make.right.equalTo(view.snp.right).offset(-10)
        }

        view.addSubview(blurSlider)
        blurSlider.value = 0
        blurSlider.snp.makeConstraints { (make) -> Void in
            make.bottom.equalTo(view).offset(-20)
            make.left.equalTo(albumButton.snp.right).offset(20)
            make.right.equalTo(view.snp.right).offset(-10)
        }
        
        redSlider.addTarget(self, action: #selector(redHandler(slider:)), for: .valueChanged)
        blurSlider.addTarget(self, action: #selector(blurHandler(slider:)), for: .valueChanged)
        inputEVSlider.addTarget(self, action: #selector(evHandler(slider:)), for: .valueChanged)
        ci_inputEVSlider.addTarget(self, action: #selector(ci_evHandler(slider:)), for: .valueChanged)
    }
    
    func redHandler(slider:UISlider)  {
        testFilter.context.async {
            self.testFilter.redAmount = slider.value
        }
    }

    func blurHandler(slider:UISlider)  {
        testFilter.context.async {
            self.testFilter.blurRadius = slider.value * 200
        }
    }

    func evHandler(slider:UISlider)  {
        testFilter.context.async {
            self.testFilter.inputEV = slider.value * 2
        }
    }
    
    func ci_evHandler(slider:UISlider)  {
        testFilter.context.async {
            self.testFilter.ci_inputEV = slider.value * 2
        }
    }


    var isAlbumOpened = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isAlbumOpened {
            isAlbumOpened = true
            openAlbum(sender: nil)
        }
    }
    
    func openAlbum(sender:UIButton?)  {
        imagePicker = UIImagePickerController()
    }
    
    var imagePicker:UIImagePickerController!{
        didSet{
            self.imagePicker.delegate = self
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .photoLibrary
            if let actualPicker = self.imagePicker{
                self.present(actualPicker, animated:true, completion:nil)
            }
        }
    }

    var currentImageUrl:NSURL? = nil
    
    func loadLastImage(size: Float = 0, complete:@escaping ((_ size:Float,_ image:UIImage)->Void)) {
        
        var fetchResult:PHFetchResult<AnyObject>
        
        if let url = currentImageUrl {
            fetchResult = PHAsset.fetchAssets(withALAssetURLs: [url as URL], options: nil) as! PHFetchResult<AnyObject>
            
        }
        else {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            fetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions) as! PHFetchResult<AnyObject>
        }
        
        if let lastAsset: PHAsset = fetchResult.lastObject as? PHAsset {
            let manager = PHImageManager.default()
            let imageRequestOptions = PHImageRequestOptions()
            imageRequestOptions.isNetworkAccessAllowed = true
            imageRequestOptions.resizeMode = .exact
            
            func progress(percent: Double, _ error: Error?, _ obj:UnsafeMutablePointer<ObjCBool>, _ options: [AnyHashable : Any]?) {
                print("image loading progress = \(percent, error, obj, options)")
            }
            
            imageRequestOptions.progressHandler = progress
            
            manager.requestImageData(for: lastAsset, options: imageRequestOptions, resultHandler: {
                (imageData, dataUTI, orientation, info) in
                if let imageDataUnwrapped = imageData, let image = UIImage(data: imageDataUnwrapped) {
                    // do stuff with image
                    complete(size, image)
                }
            })
        }
    }
    
    lazy var downScaleFilter:DownScaleFilter = DownScaleFilter(context: self.context)
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let chosenImage:UIImage? = info[UIImagePickerControllerOriginalImage] as? UIImage
        currentImageUrl = info[UIImagePickerControllerReferenceURL] as? NSURL
        
        if let actualImage = chosenImage{
            let bounds = UIScreen.main.bounds
            let screensize = max(bounds.size.width, bounds.size.height) * UIScreen.main.scale
            
            let source = IMPImage(context: context, image: actualImage, maxSize: 0)
        
            NSLog(" start set source with size \(actualImage.size) scaled size = \(screensize) source.size = \(source.image?.extent)")

            imageView.filter?.source = source
        }
        
        picker.dismiss(animated: true, completion: nil)
    }

    lazy var mps:MPSImageGaussianBlur = MPSImageGaussianBlur(device: self.context.device, sigma: 100)
    lazy var blur:CIFilter =  CIFilter(name: "CIGaussianBlur")!
    
    lazy var testFilter:TestFilter = TestFilter(context: self.context)
    
    lazy var vibrance:IMPFilter = {
        let f = IMPFilter(context: self.context)
        if let v = CIFilter(name:"CIVibrance"){
            v.setValue(10, forKey: "inputAmount")
            f.add(filter:v){ (destination) in
                print(" function CIVibrance destination = \(destination)")
            }
        }
        if let i = CIFilter(name:"CIColorInvert"){
            f.add(filter:i){ (destination) in
                print(" function CIColorInvert destination = \(destination)")
            }
        }

        return f
    }()
    
    lazy var filter:IMPFilter = {
        let f = IMPFilter(context: self.context)
        
        f.add(function: IMPFunction(context: self.context, name: "kernel_view")){ (destination) in
            print(" function kernel_view destination = \(destination)")
        }

        f.add(function: "kernel_red")
        
        f.add(function: "kernel_red", fail: { (error) in
            print("error = \(error)")
        })
        
        f.add(function: "kernel_green"){ (destination) in
            print(" function kernel_green destination = \(destination)")
        }
        
        f.add(filter: self.blur)
        f.add(mps:self.mps, withName:"MPSGaussianBlur")
        
        f.remove(filter:self.blur)
        f.remove(filter:"kernel_red")
        
        f.insert(function:"kernel_red", after:"MPSGaussianBlur", fail: { (error) in
            print(" function kernel_red error = \(error)")
        }){ (destination) in
            print(" function kernel_red destination = \(destination)")
        }
        
        f.insert(filter:self.vibrance, before: "kernel_view")
        
        f.remove(filter:self.vibrance)
        
        return f
    }()
}
