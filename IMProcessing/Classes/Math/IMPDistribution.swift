//
//  IMPDistribution.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 22.12.15.
//  Copyright © 2015 Dehancer.photo. All rights reserved.
//

import Foundation
import Accelerate

// MARK: - Gaussian value in certain point of x
public extension Float{
    
    ///  Get gaussian Y point from distripbution of X in certain point
    ///
    ///  - parameter fi:    ƒ
    ///  - parameter mu:    µ
    ///  - parameter sigma: ß
    ///
    ///  - returns: Y value
    public func gaussianPoint(fi fi:Float, mu:Float, sigma:Float) -> Float {
        return fi * exp( -(pow(( self - mu ),2)) / (2*pow(sigma, 2)) )
    }
    
    ///  Get double pointed gaussian Y point from distripbution of two X points
    ///
    ///  - parameter fi:    float2(ƒ1,ƒ2)
    ///  - parameter mu:    float2(µ1,µ2)
    ///  - parameter sigma: float2(ß1,ß2)
    ///
    ///  - returns: y value
    public func gaussianPoint(fi fi:float2, mu:float2, sigma:float2) -> Float {
        
        let c1 = self <= mu.x ? 1.float : 0.float
        let c2 = self >= mu.y ? 1.float : 0.float
        
        let y1 = self.gaussianPoint(fi: fi.x, mu: mu.x, sigma: sigma.x) * c1 + (1.0-c1)
        let y2 = self.gaussianPoint(fi: fi.y, mu: mu.y, sigma: sigma.y) * c2 + (1.0-c2)
        
        return y1 * y2
    }
    
    ///  Get normalized gaussian Y point from distripbution of two X points
    ///
    ///  - parameter fi:    ƒ
    ///  - parameter mu:    µ
    ///  - parameter sigma: ß
    ///
    ///  - returns: y value
    public func gaussianPoint(mu:Float, sigma:Float) -> Float {
        return self.gaussianPoint(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    ///  Get double normalized gaussian Y point from distripbution of two X points
    ///
    ///  - parameter fi:    float2(ƒ1,ƒ2)
    ///  - parameter mu:    float2(µ1,µ2)
    ///  - parameter sigma: float2(ß1,ß2)
    ///
    ///  - returns: Y value
    public func gaussianPoint(mu:float2, sigma:float2) -> Float {
        return self.gaussianPoint(fi:float2(1), mu: mu, sigma: sigma)
    }
    
    ///  Create linear range X points within range
    ///
    ///  - parameter r: range
    ///
    ///  - returns: X list
    static func range(r:Range<Int>) -> [Float]{
        return range(start: Float(r.startIndex), step: 1, end: Float(r.endIndex))
    }
    
    
    ///  Create linear range X points within range scaled to particular value
    ///
    ///  - parameter r: range
    ///
    ///  - returns: X list
    static func range(r:Range<Int>, scale:Float) -> [Float]{
        var r = range(start: Float(r.startIndex), step: 1, end: Float(r.endIndex))
        var denom:Float = 0
        vDSP_maxv(r, 1, &denom, vDSP_Length(r.count))
        denom /= scale
        vDSP_vsdiv(r, 1, &denom, &r, 1, vDSP_Length(r.count))
        return r
    }
    
    
    ///  Create linear range X points within range of start/end with certain step
    ///
    ///  - parameter start: start value
    ///  - parameter step:  step, must be less then end-start
    ///  - parameter end:   end, must be great the start
    ///
    ///  - returns: X list
    static func range(start start:Float, step:Float, end:Float) -> [Float] {
        let size       = Int((end-start)/step)
        
        var h:[Float]  = [Float](count: size, repeatedValue: 0)
        var zero:Float = start
        var v:Float    = step
        
        vDSP_vramp(&zero, &v, &h, 1, vDSP_Length(size))
        
        return h
        
    }
}

// MARK: - Gaussian distribution
public extension SequenceType where Generator.Element == Float {
    
    ///  Create gaussian distribution of discrete values of Y's from mean parameters
    ///
    ///  - parameter fi:    ƒ
    ///  - parameter mu:    µ
    ///  - parameter sigma: ß
    ///
    ///  - returns: discrete gaussian distribution
    public func gaussianDistribution(fi fi:Float, mu:Float, sigma:Float) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    ///  Create gaussian distribution of discrete values of Y points from two points of means
    ///
    ///  - parameter fi:    float2(ƒ1,ƒ2)
    ///  - parameter mu:    float2(µ1,µ2)
    ///  - parameter sigma: float2(ß1,ß2)
    ///
    ///  - returns: discrete gaussian distribution
    public func gaussianDistribution(fi fi:float2, mu:float2, sigma:float2) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    ///  Create normalized gaussian distribution of discrete values of Y's from mean parameters
    ///
    ///  - parameter fi:    ƒ
    ///  - parameter mu:    µ
    ///  - parameter sigma: ß
    ///
    ///  - returns: discrete gaussian distribution
    public func gaussianDistribution(mu mu:Float, sigma:Float) -> [Float]{
        return self.gaussianDistribution(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    ///  Create normalized gaussian distribution of discrete values of Y points from two points of means
    ///
    ///  - parameter fi:    float2(ƒ1,ƒ2)
    ///  - parameter mu:    float2(µ1,µ2)
    ///  - parameter sigma: float2(ß1,ß2)
    ///
    ///  - returns: discrete gaussian distribution
    public func gaussianDistribution(mu mu:float2, sigma:float2) -> [Float]{
        return self.gaussianDistribution(fi: float2(1), mu: mu, sigma: sigma)
    }
    
//    
//    public static func range(r:Range<Int>) -> [Float]{ return Float.range(r) }
//    
//    public static func range(start start:Float, step:Float, end:Float) -> [Float] {
//        return Float.range(start: start, step: step, end: end)
//    }
}