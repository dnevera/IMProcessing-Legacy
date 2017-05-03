//
//  ViewController.swift
//  IMPColorSpacesTest
//
//  Created by Denis Svinarchuk on 03/05/2017.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Cocoa
import IMProcessing
import simd


extension String {
    
    func isFloat(_ range:float2) -> Bool {
        if let floatValue = Float(self) {
            if floatValue.isFinite {
                if floatValue >= range.x && floatValue <= range.y {
                    return true
                }
            }
        }
        return false
    }
    
    func numberOfCharacters() -> Int {
        return self.characters.count
    }
}


class FloatFormatter: NumberFormatter {
    
    var range:float2 = float2(0,1)
    
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        
        // Allow blank value
        if partialString.numberOfCharacters() == 0  {
            return true
        }
        
        // Validate string if it's an int
        if partialString.isFloat(range) {
            return true
        } else {
            NSBeep()
            return false
        }
    }
}

class ViewController: NSViewController {

    @IBAction func reset(_ sender: NSButton) {
        for f in sourceValues {
            f.floatValue = 0
        }
        for f in destinationValues {
            f.floatValue = 0
        }
        
        for f in matchingValues {
            f.floatValue = 0
        }
    }
    
    
    @IBOutlet weak var matchingXValue: NSTextField!
    @IBOutlet weak var matchingYValue: NSTextField!
    @IBOutlet weak var matchingZValue: NSTextField!
    
    lazy var matchingValues:[NSTextField]  = [self.matchingXValue, self.matchingYValue, self.matchingZValue]

    
    var sourceColorSpace:IMPColorSpace = .rgb
    var destinationColorSpace:IMPColorSpace = .rgb
    
    @IBOutlet weak var SourceSpaces: NSPopUpButton!
    
    @IBOutlet weak var DestinationSpaces: NSPopUpButton!
    
    @IBAction func sourceColorSpaceSelector(_ sender: NSPopUpButton) {
        sourceColorSpace = IMPColorSpace(index: sender.indexOfSelectedItem)
        updateNames(names: sourceNames, space: sourceColorSpace)
        updateSources()
    }
    
    @IBAction func destinationColorSpaceSelector(_ sender: NSPopUpButton) {
        destinationColorSpace = IMPColorSpace(index: sender.indexOfSelectedItem)
        updateNames(names: destinationNames, space: destinationColorSpace)
        updateDestinations()
    }
    
    
    func updateNames(names:[NSTextField], space:IMPColorSpace) {
        for (i,n) in space.channelNames.enumerated(){
            names[i].stringValue = n
        }
    }
    
    @IBOutlet weak var sourceXName: NSTextField!
    @IBOutlet weak var sourceYName: NSTextField!
    @IBOutlet weak var sourceZName: NSTextField!

    lazy var sourceNames:[NSTextField] = [self.sourceXName, self.sourceYName, self.sourceZName]
    
    @IBOutlet weak var destinationXName: NSTextField!
    @IBOutlet weak var destinationYName: NSTextField!
    @IBOutlet weak var destinationZName: NSTextField!

    lazy var destinationNames:[NSTextField]  = [self.destinationXName, self.destinationYName, self.destinationZName]

    
    @IBOutlet weak var sourceXValue: NSTextField!
    @IBOutlet weak var sourceYValue: NSTextField!
    @IBOutlet weak var sourceZValue: NSTextField!

    lazy var sourceValues:[NSTextField]  = [self.sourceXValue, self.sourceYValue, self.sourceZValue]

    @IBOutlet weak var destinationXValue: NSTextField!
    @IBOutlet weak var destinationYValue: NSTextField!
    @IBOutlet weak var destinationZValue: NSTextField!

    lazy var destinationValues:[NSTextField]  = [self.destinationXValue, self.destinationYValue, self.destinationZValue]

    @IBAction func valueUpdated(_ sender: NSTextField) {
        if sourceValues.index(of: sender) != nil {
            updateDestinations()
        }
        else {
            updateSources()
        }
    }

    func updateDestinations() {
        var c = float3(0)
        for (i,s) in sourceValues.enumerated() {
            let f = s.floatValue
            c[i] = f
        }
        var t = destinationColorSpace.from(sourceColorSpace, value: c)
        for (i,d) in destinationValues.enumerated() {
            d.floatValue =  t[i]
        }
        updateFormaters(sources: destinationValues, space: destinationColorSpace)
        updateMatching(fromValues: destinationValues, toValues: sourceValues, from: destinationColorSpace, to: sourceColorSpace)
    }

    func updateSources() {
        var c = float3(0)
        for (i,s) in destinationValues.enumerated() {
            let f = s.floatValue
            c[i] = f
        }
        var t = sourceColorSpace.from(destinationColorSpace, value: c)
        for (i,d) in sourceValues.enumerated() {
            d.floatValue =  t[i]
        }

        updateFormaters(sources: sourceValues, space: sourceColorSpace)
        updateMatching(fromValues: sourceValues, toValues: destinationValues, from: sourceColorSpace, to: destinationColorSpace)
    }

    func updateMatching(fromValues:[NSTextField], toValues:[NSTextField], from:IMPColorSpace, to:IMPColorSpace) {
        
        updateFormaters(sources: matchingValues, space: to)

        var c = float3(0)
        for (i,f) in fromValues.enumerated() {
            c[i] = f.floatValue
        }
        let t = from.to(to, value: c)
        for (i,_) in toValues.enumerated() {
            matchingValues[i].floatValue = t[i]
        }
    }
    
    let rgbColors = [
        float3(0,0,0),
        float3(1,1,1),
        float3(0.5,0.5,0.5),
        float3(1,0,0),
        float3(0,1,0),
        float3(0,0,1)
    ]
    
    func updateFormaters(sources:[NSTextField], space:IMPColorSpace) {
        let formatter = FloatFormatter()
        formatter.formatterBehavior = .behavior10_4
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = "."
        
        for (i,f) in sources.enumerated() {
            formatter.range = space.channelRanges[i]
            f.formatter = formatter
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        updateFormaters(sources: sourceValues, space: sourceColorSpace)
        updateFormaters(sources: destinationValues, space: destinationColorSpace)
        updateFormaters(sources: matchingValues, space: sourceColorSpace)
        
        updateNames(names: sourceNames, space: sourceColorSpace)
        updateNames(names: destinationNames, space: destinationColorSpace)

        SourceSpaces.removeAllItems()
        DestinationSpaces.removeAllItems()
        
        for i in IMPColorSpace.list {
            SourceSpaces.addItem(withTitle: i.rawValue)
        }

        for i in IMPColorSpace.list {
            DestinationSpaces.addItem(withTitle: i.rawValue)
        }

        updateMatching(fromValues: sourceValues, toValues: destinationValues, from: sourceColorSpace, to: destinationColorSpace)

        for c in rgbColors {
            Swift.print("\(c) rgb -> hsv \(c.rgb2hsv()) -> lab \(c.rgb2hsv().hsv2lab()) -> luv \(c.rgb2hsv().hsv2lab().lab2luv()) -> rgb \(c.rgb2hsv().hsv2lab().lab2luv().luv2rgb())")
        }
        
        Swift.print(" --- ")

        for c in rgbColors {
            Swift.print("\(c) rgb -> xyz \(c.rgb2xyz()) -> luv \(c.rgb2xyz().xyz2luv()) -> rgb \(c.rgb2xyz().xyz2luv().luv2rgb())")
        }
        
    }

}

