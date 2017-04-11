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

public class IMPRgbCubeView: IMPScnView {
    
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
    
    open override func configure(frame: CGRect){

        super.configure(frame: frame)

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
    
    public override func constraintNode() -> SCNNode {
        return cubeNode
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
}
