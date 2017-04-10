//
//  IMPRgbCubeView.swift
//  IMPRgbCubeTest
//
//  Created by denis svinarchuk on 09.04.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import SceneKit
import SnapKit
import IMProcessing

public class IMPRgbCubePoint {

    public var color:NSColor {
        set{
            let c = newValue.rgb
            let p = SCNVector3(x:CGFloat(c.x-1/2),y:CGFloat(c.y-1/2),z:CGFloat(c.z-1/2))
            _node.position = p
            material.diffuse.contents = newValue
        }
        get {
            return material.diffuse.contents as! NSColor
        }
    }
    
    public var position:SCNVector3 {
        get {
            return _node.position
        }
    }
    
    public init(color:NSColor = NSColor.gray) {
        self.color = color
    }
    
    public func add(to scene: SCNScene, color:NSColor? = nil)  -> SCNNode {
        return add(to: scene.rootNode, color: color)
    }
    
    public func add(to node: SCNNode, color:NSColor? = nil) -> SCNNode {
        node.addChildNode(_node)
        if let c = color {
            self.color = c
        }
        return _node
    }
    
    private lazy var _node:SCNNode = {
        let n = SCNNode(geometry: self.sphereGeometry)
        let shape = SCNPhysicsShape(geometry: self.sphereGeometry, options: nil)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        n.physicsBody = body
        return n
    }()
    
    
    private lazy var material:SCNMaterial = {
        let m = SCNMaterial()
        return m
    }()

    private lazy var sphereGeometry:SCNSphere = {
        let s  = SCNSphere(radius: 0.02)
        s.materials = [self.material]
        return s
    }()

}

 class IMPRgbCubeView: NSView {
    
    let cornerColors:[NSColor] = [
        NSColor(red: 1, green: 0, blue: 0, alpha: 1),
        NSColor(red: 0, green: 1, blue: 0, alpha: 1),
        NSColor(red: 0, green: 0, blue: 1, alpha: 1),
        
        NSColor(red: 1, green: 1, blue: 0, alpha: 1),
        NSColor(red: 0, green: 1, blue: 1, alpha: 1),
        NSColor(red: 1, green: 0, blue: 1, alpha: 1),
        
        NSColor(red: 1, green: 1, blue: 1, alpha: 1),
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),
        NSColor(red: 0, green: 0, blue: 0, alpha: 1)
    ]
    
    public var grid = IMPPatchesGrid() {
        didSet {
            
            for n in targetNodes {
                n.removeFromParentNode()
            }
            
            targetNodes = [SCNNode]()
            for i in 0..<grid.target.count {
                let p = grid.target[i]
                let n = IMPRgbCubePoint(color: NSColor(rgb: p.color))
                targetNodes.append(n.add(to: cubeNode))
            }
            
            for c in cornerColors {
                let n = IMPRgbCubePoint(color: c)
                targetNodes.append(n.add(to: cubeNode))
            }
        }
    }

    var targetNodes = [SCNNode]()
    
    var padding:CGFloat = 10
    var viewPortAspect:CGFloat = 4/3

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

    lazy var cameraNode:SCNNode = {
        let n = SCNNode()
        n.camera = self.camera

        //initial camera setup
        n.position = SCNVector3(x: 0, y: 0, z: 3.0)
        n.eulerAngles.y = -2 * CGFloat.pi * self.lastWidthRatio
        n.eulerAngles.x = -CGFloat.pi * self.lastHeightRatio

        let constraint = SCNLookAtConstraint(target: self.cubeNode)
        n.constraints = [constraint]
        
        return n
    }()

    lazy var lightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.omni
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 1.5, y: 1.5, z: 1.5)
        return n
    }()

    
    lazy var centerLightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.ambient
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 0, y: 0, z: 0)
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
    
    let scene = SCNScene()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        __init__(frame: self.frame)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
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
    
    func __init__(frame: CGRect){
                
        sceneView.frame = originalFrame

        addSubview(sceneView)
        sceneView.scene = scene
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(lightNode)
        scene.rootNode.addChildNode(centerLightNode)
        scene.rootNode.addChildNode(cubeNode)
        
        let pan = NSPanGestureRecognizer(target: self, action: #selector(panGesture(recognizer:)))
        pan.buttonMask = 1
        sceneView.addGestureRecognizer(pan)
    }

    var lastWidthRatio: CGFloat = 0
    var lastHeightRatio: CGFloat = 0

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
        
        cubeNode.rotation = rotationVector
        
        if(recognizer.state == .ended) {
            //
            let currentPivot = cubeNode.pivot
            let changePivot = SCNMatrix4Invert( cubeNode.transform)
            let pivot = SCNMatrix4Mult(changePivot, currentPivot)
            cubeNode.pivot = pivot
            cubeNode.transform = SCNMatrix4Identity
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
    
    public override func scrollWheel(with event: NSEvent) {
        fov = fov - event.deltaY
    }
    
    let cubeGeometry:SCNBox = {
        let g = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: 1, green: 1, blue: 1, alpha: 0.1)
        g.materials = [m]

        return g
    }()
    
    lazy var cubeNode:SCNNode = {
        let c = SCNNode(geometry: self.cubeGeometry)
        c.position = SCNVector3(x: 0, y: 0, z: 0)
        return c
    }()
    
    lazy var centerSphereGeometry:SCNSphere = {
        let s  = SCNSphere(radius: 0.02)
        let m = SCNMaterial()
        m.diffuse.contents = NSColor.gray
        s.materials = [m]
        return s
    }()
    
    lazy var centerSphere:SCNNode = {
        let n = SCNNode(geometry: self.centerSphereGeometry)
        
        let shape = SCNPhysicsShape(geometry: self.centerSphereGeometry, options: nil)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        
        n.position = SCNVector3(x: 0, y: 0, z: 0)
        n.physicsBody = body

        return n
    }()
}
