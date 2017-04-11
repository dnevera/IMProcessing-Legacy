//
//  IMPCylinderLine.swift
//  IMPRgbCubeTest
//
//  Created by Denis Svinarchuk on 11/04/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import SceneKit

private extension SCNVector3{
    func distance( _ receiver:SCNVector3) -> Float{
        let xd = receiver.x - self.x
        let yd = receiver.y - self.y
        let zd = receiver.z - self.z
        let distance = Float(sqrt(xd * xd + yd * yd + zd * zd))
        
        if (distance < 0){
            return (distance * -1)
        } else {
            return (distance)
        }
    }
}

//
// sources: http://stackoverflow.com/questions/35002232/draw-scenekit-object-between-two-points
//
public class   IMPCylinderLine: SCNNode
{
    public init(
        parent: SCNNode,      //Needed to add destination point of your line
        v1: SCNVector3,       //source
        v2: SCNVector3,       //destination
        color: NSColor,
        endColor: NSColor? = nil,
        radius: CGFloat = 0.001,
        radSegmentCount: Int = 48
        )
    {
        super.init()
        
        //Calcul the height of our line
        let  height = v1.distance(v2)
        
        //set position to v1 coordonate
        position = v1
        
        //Create the second node to draw direction vector
        let nodeV2 = SCNNode()
        
        //define his position
        nodeV2.position = v2
        //add it to parent
        parent.addChildNode(nodeV2)
        
        //Align Z axis
        let zAlign = SCNNode()
        zAlign.eulerAngles.x = CGFloat.pi/2
        
        //create our cylinder
        let cyl = SCNCylinder(radius: radius, height: CGFloat(height))
        cyl.radialSegmentCount = radSegmentCount
        
        if let e = endColor {
            let grad = NSGradient(starting: color, ending: e)
            let rect = NSRect(x:0,y:0,width: 100, height: 10)
            let image = NSImage(size: rect.size)
            let path = NSBezierPath(rect: rect)
            image.lockFocus()
            grad?.draw(in: path, angle: 270)
            image.unlockFocus()
            
            cyl.firstMaterial?.diffuse.contents = image
        }
        else {
            cyl.firstMaterial?.diffuse.contents = color
        }
        
        //Create node with cylinder
        let nodeCyl = SCNNode(geometry: cyl )
        nodeCyl.position.y = CGFloat(-1 * height / Float(2))
        zAlign.addChildNode(nodeCyl)
        
        //Add it to child
        addChildNode(zAlign)
        
        //set contrainte direction to our vector
        constraints = [SCNLookAtConstraint(target: nodeV2)]
    }
    
    public override init() {
        super.init()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
