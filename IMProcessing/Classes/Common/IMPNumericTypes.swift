//
//  IMPNumericTypes.swift
//  IMPCoreImageMTLKernel
//
//  Created by denis svinarchuk on 11.02.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

public extension Double{
    
    public var int:Int{
        get{
            return Int(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
    
    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
}

public extension Float{
    
    public var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }
    public var int:Int{
        get{
            return self.isFinite ? Int(self):Int.max
        }
        set(newValue){
            self = Float(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }
}


public extension Float {
    /// Convert radians to degrees
    public var degrees:Float{
        return self * (180 / Float.pi)
    }
    /// Convert degrees to radians
    public var radians:Float{
        return self * (Float.pi / 180)
    }
}

public extension Int {
    
    public var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
    
    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
    public var cgfloat:CGFloat{
        get{
            return CGFloat(self)
        }
        set(newValue){
            self = Int(newValue)
        }
    }
}

public extension CGFloat{
    public var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = CGFloat(newValue)
        }
    }
}
