//
//  IMPLchCilinderView.swift
//  IMPRgbCubeTest
//
//  Created by Denis Svinarchuk on 11/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import SceneKit
import SnapKit
import IMProcessing


public class IMPHsvPoint {
    
    public enum PointType{
        case sphere
        case cube
    }
    
    
//    public static func ==(lhs: IMPRgbCubePoint, rhs: IMPRgbCubePoint) -> Bool {
//        return lhs.color == rhs.color &&
//            lhs.position.x == lhs.position.x &&
//            lhs.position.y == lhs.position.y &&
//            lhs.position.z == lhs.position.z
//    }
    
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
    
    public var color:NSColor {
        set{
            let hsv = newValue.rgb.rgb2hsv()
            let y     = hsv.value
            let theta = hsv.hue * Float.pi * 2
            let z     = hsv.saturation * cos(theta) / 2
            let x     = hsv.saturation * sin(theta) / 2
            
            let p = SCNVector3(x:CGFloat(x),y:CGFloat(y-0.5),z:CGFloat(z))
            
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
    
    var pointType:PointType
    public init(color:NSColor = NSColor.gray, radius:CGFloat = 0.02, type: PointType = .sphere) {
        pointType = type
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


class IMPHsvCylinderView: IMPScnView {
    
    public var grid = IMPPatchesGrid() {
        didSet{
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
                let n = IMPHsvPoint(color: NSColor(rgb: p.color), radius: 0.02)
                targetNodes.append(n.add(to: cylinderNode))
            }
            
            var index = 0
            for y in 0..<grid.dimension.height {
                for x in 0..<grid.dimension.width {
                    let p = grid.source[y][x]
                    let t = grid.target[index]
                    let color = NSColor(rgba: float4(p.r,p.g,p.b,1))
                    
                    let n = IMPHsvPoint(color: color, radius: 0.005 )
                    
                    let node = n.add(to: cylinderNode)
                    sourceNodes.append(node)
                    let tnode = targetNodes[index]
                    
                    let line = IMPCylinderLine(parent: cylinderNode,
                                               v1: node.position,
                                               v2: tnode.position,
                                               color: color,
                                               endColor: NSColor(rgb: t.color))
                    
                    cylinderNode.addChildNode(line)
                    lineNodes.append(line)
                    index += 1
                }
            }

        }
    }
    
    var lineNodes = [SCNNode]()
    var sourceNodes = [SCNNode]()
    var targetNodes = [SCNNode]()

    override func configure(frame: CGRect) {
        super.configure(frame: frame)
        scene.rootNode.addChildNode(cylinderNode)
        
        let black = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
        let white = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        let n0 = IMPHsvPoint(color: black, radius:0.005, type: .cube)
        _ = n0.add(to: cylinderNode)
        
        let n1 = IMPHsvPoint(color: white, radius:0.005, type: .cube)
        _ = n1.add(to: cylinderNode)
        
        let line = IMPCylinderLine(parent: cylinderNode,
                                   v1: n0.position,
                                   v2: n1.position,
                                   color: black,
                                   endColor: white)
        cylinderNode.addChildNode(line)

        //drawCircle(circle: topCircle)
        //drawCircle(circle: midCircle)
        //drawCircle(circle: botCircle)
        
        cylinderNode.addChildNode(torNode(level: 1,  position: 0.5))
        cylinderNode.addChildNode(torNode(level: 0.5, position: 0))
        cylinderNode.addChildNode(torNode(level: 0.001, position: -0.5))
    }
    
    
    public override func constraintNode() -> SCNNode {
        return cylinderNode
    }
    
    
    func drawCircle(circle:[(float3,float3)])  {
        for c in circle  {
            let c0 = c.0
            let c1 = c.1
            let n0 = IMPHsvPoint(color: NSColor(rgb: c0), radius: 0.01, type: .cube)
            let n1 = IMPHsvPoint(color: NSColor(rgb: c1), radius: 0.01, type: .cube)
            _ = n0.add(to: cylinderNode)
            _ = n1.add(to: cylinderNode)
            
            let line = IMPCylinderLine(parent: cylinderNode,
                                       v1: n0.position,
                                       v2: n1.position,
                                       color: NSColor(rgb: c0),
                                       endColor: NSColor(rgb: c1))
            
            
            cylinderNode.addChildNode(line)
        }
    }
    
    let topCircle = [
        (float3(1,0,0),float3(1,1,0)),
        (float3(1,1,0),float3(0,1,0)),
        
        (float3(0,1,0),float3(0,1,1)),
        (float3(0,1,1),float3(0,0,1)),
        
        (float3(0,0,1),float3(1,0,1)),
        (float3(1,0,1),float3(1,0,0)),
        ]
    
    
    let midCircle = [
        (float3(0.5,0,0),float3(0.5,0.5,0)),
        (float3(0.5,0.5,0),float3(0,0.5,0)),
        
        (float3(0,0.5,0),float3(0,0.5,0.5)),
        (float3(0,0.5,0.5),float3(0,0,0.5)),
        
        (float3(0,0,0.5),float3(0.5,0,0.5)),
        (float3(0.5,0,0.5),float3(0.5,0,0)),
        ]

    let botCircle = [
        (float3(0.001,0,0),float3(0.001,0.001,0)),
        (float3(0.001,0.001,0),float3(0,0.001,0)),
        
        (float3(0,0.001,0),float3(0,0.001,0.001)),
        (float3(0,0.001,0.001),float3(0,0,0.001)),
        
        (float3(0,0,0.001),float3(0.001,0,0.001)),
        (float3(0.001,0,0.001),float3(0.001,0,0)),
        ]

    let cylinderGeometry:SCNCylinder = {
        let g =  SCNCylinder(radius: 0.5, height: 1)
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2)
        g.materials = [m]
        
        return g
    }()
    
    lazy var cylinderNode:SCNNode = {
        let c = SCNNode(geometry: self.cylinderGeometry)
        c.position = SCNVector3(x: 0, y: 0, z: 0)
        return c
    }()

    
    let hsvCircle = [
        float3(1,0,0),
        float3(1,1,0),
        float3(0,1,0),
        
        float3(0,1,1),
        float3(0,0,1),
        float3(1,0,1),
        float3(1,0,0)
        ]

    func gradients(colors:[float3], level:CGFloat = 1) -> NSGradient {
        var cs = [NSColor]()
        for c in colors {
            cs.append(NSColor(rgb: c * float3(level.float)))
        }
        return NSGradient(colors: cs)!
    }
    
    func torNode(level:CGFloat, position:CGFloat, radius:CGFloat = 0.002) -> SCNNode {
        let c = SCNNode(geometry: self.torGeometry(level:level, radius:radius))
        c.position = SCNVector3(x: 0, y: position, z: 0)
        c.eulerAngles =  SCNVector3(x: 0, y: CGFloat.pi, z: 0)
        return c
    }
    
    func torGeometry(level:CGFloat, radius:CGFloat) -> SCNTorus {
        let t = SCNTorus(ringRadius: 0.5, pipeRadius: radius)
        let m = SCNMaterial()
        
        let grad =  self.gradients(colors: self.hsvCircle, level: level)
        let rect = NSRect(x:0,y:0,width: 100, height: 10)
        let image = NSImage(size: rect.size)
        let path = NSBezierPath(rect: rect)
        image.lockFocus()
        grad.draw(in: path, angle: 0)
        image.unlockFocus()
        
        
        m.diffuse.contents = image
        t.materials = [m]
        return t
    }
}
