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


public class IMPRgbCubeView: NSView {

    lazy var cameraNode:SCNNode = {
        let camera = SCNCamera()
        let n = SCNNode()
        n.camera = camera
        n.position = SCNVector3(x: 0.0, y: 0.0, z: 3.0)
        return n
    }()
    
    lazy var lightNode:SCNNode = {
        let n = SCNNode()
        n.light = self.light
        n.position = SCNVector3(x: 1.5, y: 1.5, z: 1.5)
        return n
    }()

    lazy var light:SCNLight = {
        let l = SCNLight()
        l.type = SCNLight.LightType.omni
        return l
    }()
    
    lazy var sceneView:SCNView = SCNView(frame:self.bounds)
    let scene = SCNScene()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        __init__(frame: self.frame)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func __init__(frame: CGRect){
        
        sceneView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]

        addSubview(sceneView)
        sceneView.scene = scene
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(lightNode)
        
        let sphereGeometry = SCNSphere(radius: 1.5)
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = NSColor.green
        sphereGeometry.materials = [sphereMaterial]
        
        var sphere1 = SCNNode(geometry: sphereGeometry)
        
        
        let shape = SCNPhysicsShape(geometry: sphereGeometry, options: nil)
        let sphere1Body = SCNPhysicsBody(type: .kinematic, shape: shape)
        sphere1.physicsBody = sphere1Body
        
        sphere1 = SCNNode(geometry: sphereGeometry)
        sphere1.position = SCNVector3(x: 2, y: 1, z: -1)
        
        
        let planeGeometry = SCNPlane(width: 40.0, height: 40.0)
        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.eulerAngles = SCNVector3(x: CGFloat(GLKMathDegreesToRadians(-90)), y: 0, z: 0)
        planeNode.position = SCNVector3(x: 0, y: -0.5, z: 0)

        scene.rootNode.addChildNode(sphere1)
        scene.rootNode.addChildNode(planeNode)
        
        let press = NSPressGestureRecognizer(target: self, action: #selector(scenePressed(recognizer:)))
        press.minimumPressDuration = 0.01
        press.buttonMask = 1
        addGestureRecognizer(press)

    }
    
    func scenePressed(recognizer: NSPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        let hitResults = sceneView.hitTest(location, options: nil)
        //NSLog("--> \(location, hitResults)")
        if hitResults.count > 0 {
            let result = hitResults[0]
            //let node = result.node
            //node.removeFromParentNode()
            NSLog("--> \(location, hitResults.count)")
        }
    }

}
