//
//  IMPSCNPatchesCylinderView.swift
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
import IMProcessing

class IMPSCNPatchesCylinderView: IMPSCNView {
    
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
                let n = IMPSCNHsvPoint(color: NSColor(rgb: p.color), radius: 0.02)
                targetNodes.append(n.attach(to: cylinderNode))
            }
            
            var index = 0
            for y in 0..<grid.dimension.height {
                for x in 0..<grid.dimension.width {
                    let p = grid.source[y][x]
                    let t = grid.target[index]
                    let color = NSColor(rgba: float4(p.r,p.g,p.b,1))
                    
                    let n = IMPSCNHsvPoint(color: color, radius: 0.005 )
                    sourceNodes.append(n.attach(to: cylinderNode))
                    
                    let tn = targetNodes[index]
                    
                    let line = IMPSCNLine(parent: cylinderNode,
                                          v1: n.position,
                                          v2: tn.position,
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
        
        let n0 = IMPSCNHsvPoint(color: black, radius:0.005, type: .cube)
        cylinderNode.addChildNode(n0)
        
        let n1 = IMPSCNHsvPoint(color: white, radius:0.005, type: .cube)
        cylinderNode.addChildNode(n1)
        
        let line = IMPSCNLine(parent: cylinderNode,
                              v1: n0.position,
                              v2: n1.position,
                              color: black,
                              endColor: white)
        cylinderNode.addChildNode(line)
        
        cylinderNode.addChildNode(torNode(level: 1,  position: 0.5))
        cylinderNode.addChildNode(torNode(level: 0.5, position: 0))
        cylinderNode.addChildNode(torNode(level: 0.001, position: -0.5))
    }
    
    
    public override func constraintNode() -> SCNNode {
        return cylinderNode
    }
    
    
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
