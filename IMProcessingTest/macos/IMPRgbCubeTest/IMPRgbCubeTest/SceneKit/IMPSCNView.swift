//
//  IMPScnView.swift
//  IMPRgbCubeTest
//
//  Created by Denis Svinarchuk on 11/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import SceneKit

public class IMPSCNView: NSView {
    
    public var padding:CGFloat = 10
    public var viewPortAspect:CGFloat = 1
    
    var originalFrame:NSRect {
        let size = originalBounds.size
        let x    = (frame.size.width - size.width)/2
        let y    = (frame.size.height - size.height)/2
        return NSRect(x:x, y:y, width:size.width, height:size.height)
    }
    
    var originalBounds:NSRect {
        get{
            let w = bounds.height * viewPortAspect
            let h = bounds.height
            let scaleX = w / maxCanvasSize.width
            let scaleY = h / maxCanvasSize.height
            let scale = max(scaleX, scaleY)
            return NSRect(x:0, y:0,
                          width:  w / scale,
                          height: h / scale)
        }
    }
    
    var maxCanvasSize:NSSize {
        return NSSize(width:bounds.size.width - padding,
                      height:bounds.size.height - padding)
    }
    
    public override func layout() {
        super.layout()
        sceneView.frame = originalFrame
    }
    
    var fov:CGFloat = 35 {
        didSet{
            camera.xFov = Double(fov)
            camera.yFov = Double(fov)
        }
    }
    
    lazy var camera:SCNCamera = {
        let c = SCNCamera()
        c.xFov = Double(self.fov)
        c.yFov = Double(self.fov)
        return c
    }()
    
    var lastWidthRatio: CGFloat = 0
    var lastHeightRatio: CGFloat = 0
    
    open func constraintNode() -> SCNNode {
        return SCNNode()
    }
    
    lazy var cameraNode:SCNNode = {
        let n = SCNNode()
        n.camera = self.camera
        
        //initial camera setup
        n.position = SCNVector3(x: 0, y: 0, z: 3.0)
        n.eulerAngles.y = -2 * CGFloat.pi * self.lastWidthRatio
        n.eulerAngles.x = -CGFloat.pi * self.lastHeightRatio
        
        let constraint = SCNLookAtConstraint(target: self.constraintNode())
        n.constraints = [constraint]
        
        return n
    }()
    
    lazy var lightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.directional
        light.castsShadow = true
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 1, y: 1, z: 1)
        return n
    }()
    
    
    lazy var originLightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.directional
        light.castsShadow = true
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: -0.5, y: -0.5, z: -0.5)
        return n
    }()
    
    lazy var centerLightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.omni
        light.castsShadow = true
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
        return n
    }()
    
    lazy var sceneView:SCNView = {
        let f = SCNView(frame:self.bounds)
        f.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        f.allowsCameraControl = false
        
        if let cam = f.pointOfView?.camera {
            cam.xFov = 0
            cam.yFov = 0
        }
        
        return f
    }()
    
    public let scene = SCNScene()
    
    open func configure(frame: CGRect){
        sceneView.frame = originalFrame
        addSubview(sceneView)
        sceneView.scene = scene
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(originLightNode)
        
        let pan = NSPanGestureRecognizer(target: self, action: #selector(panGesture(recognizer:)))
        pan.buttonMask = 1
        sceneView.addGestureRecognizer(pan)
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure(frame: self.frame)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(frame: self.frame)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        let f = fov - event.deltaY
        if f < 10 {
            fov = 10
        }
        else if f > 45 {
            fov = 45
        }
        else {
            fov = f
        }
    }
    
    func panGesture(recognizer: NSPanGestureRecognizer){
        
        let translation = recognizer.translation(in: recognizer.view!)
        
        let x = translation.x
        let y = -translation.y
        
        let anglePan = sqrt(pow(x,2)+pow(y,2))*CGFloat.pi/180.0
        
        var rotationVector = SCNVector4()
        rotationVector.x = y
        rotationVector.y = x
        rotationVector.z = 0
        rotationVector.w = anglePan
        
        constraintNode().rotation = rotationVector
        
        if(recognizer.state == .ended) {
            //
            let currentPivot = constraintNode().pivot
            let changePivot = SCNMatrix4Invert( constraintNode().transform)
            let pivot = SCNMatrix4Mult(changePivot, currentPivot)
            constraintNode().pivot = pivot
            constraintNode().transform = SCNMatrix4Identity
        }
    }
    
    func cameraPanHandler(recognizer: NSPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view!)
        let widthRatio = translation.x / recognizer.view!.frame.size.width + lastWidthRatio
        let heightRatio = translation.y / recognizer.view!.frame.size.height + lastHeightRatio
        cameraNode.eulerAngles.y =  CGFloat.pi * widthRatio
        cameraNode.eulerAngles.x = -CGFloat.pi * heightRatio
        
        if (recognizer.state == .ended) {
            lastWidthRatio = widthRatio.truncatingRemainder(dividingBy: 1)
            lastHeightRatio = heightRatio.truncatingRemainder(dividingBy: 1)
        }
    }
}
