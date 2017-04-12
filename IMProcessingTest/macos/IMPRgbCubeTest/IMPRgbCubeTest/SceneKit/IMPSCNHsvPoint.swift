//
//  IMPSCNHsvPoint.swift
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

public class IMPSCNHsvPoint:IMPSCNColorPoint{
    public override func colorPosition(color newValue: NSColor) -> SCNVector3 {
        let hsv = newValue.rgb.rgb2hsv()
        let y     = hsv.value
        let theta = hsv.hue * Float.pi * 2
        let z     = hsv.saturation * cos(theta) / 2
        let x     = hsv.saturation * sin(theta) / 2
        
        return SCNVector3(x:CGFloat(x),y:CGFloat(y-0.5),z:CGFloat(z))
    }
}
