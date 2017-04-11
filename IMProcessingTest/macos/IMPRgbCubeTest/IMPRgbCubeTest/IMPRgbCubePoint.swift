//
//  IMPRgbCubePoint.swift
//  IMPRgbCubeTest
//
//  Created by Denis Svinarchuk on 11/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import SceneKit

public class IMPRgbCubePoint:Equatable {
    
    
    public static func ==(lhs: IMPRgbCubePoint, rhs: IMPRgbCubePoint) -> Bool {
        return lhs.color == rhs.color &&
            lhs.position.x == lhs.position.x &&
            lhs.position.y == lhs.position.y &&
            lhs.position.z == lhs.position.z
    }

    public var radius:CGFloat {
        set {
            sphereGeometry.radius = newValue
        }
        get {
            return  sphereGeometry.radius
        }
    }
    
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
    
    public init(color:NSColor = NSColor.gray, radius:CGFloat = 0.02) {
        self.color = color
        self.radius = radius
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
        let shape = SCNPhysicsShape(geometry: self.sphereGeometry,
                                    options: nil /*[SCNPhysicsShape.Option.type:SCNPhysicsShape.ShapeType.boundingBox]*/)
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
