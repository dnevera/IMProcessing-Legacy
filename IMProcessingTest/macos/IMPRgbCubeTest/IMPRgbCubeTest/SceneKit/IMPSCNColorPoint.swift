//
//  IMPSCNColorPoint.swift
//  IMPRgbCubeTest
//
//  Created by Denis Svinarchuk on 12/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

import SceneKit

public extension SCNNode {
    public func attach(to node: SCNNode) -> SCNNode {
        node.addChildNode(self)
        return self
    }
}

public class IMPSCNColorPoint:SCNNode{
    
    public enum PointType{
        case sphere
        case cube
    }
    
    public var pointType:PointType
    
    public var radius:CGFloat {
        set {
            sphereGeometry.radius = newValue
            boxGeometry.height = newValue
            boxGeometry.width = newValue
            boxGeometry.length = newValue
        }
        get {
            return  sphereGeometry.radius
        }
    }
    
    open func colorPosition(color newValue:NSColor) -> SCNVector3 {
        let c = newValue.rgb
        return SCNVector3(x:CGFloat(c.x-1/2),y:CGFloat(c.y-1/2),z:CGFloat(c.z-1/2))
    }
    
    public var color:NSColor {
        set{
            position = colorPosition(color: newValue)
            material.diffuse.contents = newValue
        }
        get {
            return material.diffuse.contents as! NSColor
        }
    }
    
    
    public init(color:NSColor = NSColor.gray, radius:CGFloat = 0.02, type: PointType = .sphere) {
        self.pointType = type
        super.init()
        self.geometry = (self.pointType == .sphere ? self.sphereGeometry : self.boxGeometry)
        self.color = color
        self.radius = radius
    }
    
    required convenience public init?(coder aDecoder: NSCoder) {
        self.init(color: NSColor.gray, radius: 0.02, type: .sphere)
    }    
    
    private lazy var _node:SCNNode = {
        let n = SCNNode(geometry: self.pointType == .sphere ? self.sphereGeometry : self.boxGeometry)
        let shape = SCNPhysicsShape(geometry: self.pointType == .sphere ? self.sphereGeometry : self.boxGeometry,
                                    options: nil)
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
    
    private lazy var boxGeometry:SCNBox = {
        let s  = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
        s.materials = [self.material]
        return s
    }()
    
}
