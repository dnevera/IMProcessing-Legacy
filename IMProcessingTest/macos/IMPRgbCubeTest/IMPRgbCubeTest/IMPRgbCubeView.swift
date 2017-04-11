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


class IMPRgbCubeView: NSView {
    
    public var padding:CGFloat = 10
    public var viewPortAspect:CGFloat = 1

    public var grid = IMPPatchesGrid() {
        didSet {
            
            for n in targetNodes {
                n.removeFromParentNode()
            }
            
            for n in sourceNodes {
                n.removeFromParentNode()
            }
            
            for n in lineNodes {
                n.removeFromParentNode()
            }
            
            lineNodes = [SCNNode]()
            sourceNodes = [SCNNode]()
            targetNodes = [SCNNode]()
            for i in 0..<grid.target.count {
                let p = grid.target[i]
                let n = IMPRgbCubePoint(color: NSColor(rgb: p.color), radius: 0.02)
                targetNodes.append(n.add(to: cubeNode))
            }
            
            var index = 0
            for y in 0..<grid.dimension.height {
                for x in 0..<grid.dimension.width {
                    let p = grid.source[y][x]
                    let t = grid.target[index]
                    let color = NSColor(rgba: float4(p.r,p.g,p.b,1))
                    let n = IMPRgbCubePoint(color: color, radius: 0.005 )
                    let node = n.add(to: cubeNode)
                    sourceNodes.append(node)
                    let tnode = targetNodes[index]
                    
                    let line = IMPCylinderLine(parent: cubeNode,
                                               v1: node.position,
                                               v2: tnode.position,
                                               color: color,
                                               endColor: NSColor(rgb: t.color))
                    
                    cubeNode.addChildNode(line)
                    lineNodes.append(line)
                    index += 1
                }
            }
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        __init__(frame: self.frame)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        __init__(frame: self.frame)
    }
    
    func __init__(frame: CGRect){
        
        sceneView.frame = originalFrame
        
        addSubview(sceneView)
        sceneView.scene = scene
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(lightNode)
        scene.rootNode.addChildNode(centerLightNode)
        scene.rootNode.addChildNode(originLightNode)
        scene.rootNode.addChildNode(cubeNode)
        
        
        for c in cornerColors {
            let n = IMPRgbCubePoint(color: c)
            facetCornerNodes.append(n)
            _ = n.add(to: cubeNode)
        }

        for f in facetColors {
            
            let p0 = IMPRgbCubePoint(color: f.0)
            let p1 = IMPRgbCubePoint(color: f.1)
            
            if let i0 = facetCornerNodes.index(of: p0),
                let i1 = facetCornerNodes.index(of: p1)
                {
                    let c0 = facetCornerNodes[i0]
                    let c1 = facetCornerNodes[i1]
                    let line = IMPCylinderLine(parent: cubeNode,
                                               v1: c0.position,
                                               v2: c1.position,
                                               color: f.0,
                                               endColor: f.1)
                    cubeNode.addChildNode(line)
            }
            
        }
        
        let pan = NSPanGestureRecognizer(target: self, action: #selector(panGesture(recognizer:)))
        pan.buttonMask = 1
        sceneView.addGestureRecognizer(pan)
    }

    let cornerColors:[NSColor] = [
        NSColor(red: 1, green: 0, blue: 0, alpha: 1), // 0
        NSColor(red: 0, green: 1, blue: 0, alpha: 1), // 1
        NSColor(red: 0, green: 0, blue: 1, alpha: 1), // 2
        
        NSColor(red: 1, green: 1, blue: 0, alpha: 1), // 3
        NSColor(red: 0, green: 1, blue: 1, alpha: 1), // 4
        NSColor(red: 1, green: 0, blue: 1, alpha: 1), // 5
        
        NSColor(red: 1, green: 1, blue: 1, alpha: 1), // 6
        NSColor(red: 0, green: 0, blue: 0, alpha: 1), // 7
        NSColor(red: 0, green: 0, blue: 0, alpha: 1)  // 8
    ]
    
    lazy var facetColors:[(NSColor,NSColor)] = [
        (self.cornerColors[8],self.cornerColors[0]), // black -> red
        (self.cornerColors[8],self.cornerColors[1]), // black -> green
        (self.cornerColors[2],self.cornerColors[8]), // black -> blue

        (self.cornerColors[0],self.cornerColors[3]), // red -> yellow
        (self.cornerColors[5],self.cornerColors[0]), // red -> purple

        (self.cornerColors[1],self.cornerColors[3]), // green -> yellow
        (self.cornerColors[4],self.cornerColors[1]), // green -> cyan

        (self.cornerColors[2],self.cornerColors[4]), // blue -> cyan
        (self.cornerColors[2],self.cornerColors[5]), // blue -> purple

        (self.cornerColors[6],self.cornerColors[3]), // yellow -> white
        (self.cornerColors[4],self.cornerColors[6]), // purple -> white
        (self.cornerColors[5],self.cornerColors[6]), // purple -> white

    ]
    
    var lineNodes = [SCNNode]()
    var facetCornerNodes = [IMPRgbCubePoint]()
    var sourceNodes = [SCNNode]()
    var targetNodes = [SCNNode]()
    
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
        light.type = SCNLight.LightType.ambient
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 1.5, y: 1.5, z: 1.5)
        return n
    }()
    
    
    lazy var originLightNode:SCNNode = {
        let light = SCNLight()
        light.type = SCNLight.LightType.ambient
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(x: 0, y: 0, z: 0)
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
    
    let scene = SCNScene()
    
    
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
    
    let cubeGeometry:SCNBox = {
        let g = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: 1, green: 1, blue: 1, alpha: 0.05)
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
