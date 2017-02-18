//
//  IMPDistribution.swift
//  Pods
//
//  Created by denis svinarchuk on 18.02.17.
//
//

import Foundation

import Foundation
import Accelerate

public extension Int {
    ///  Create gaussian kernel distribution with kernel size in pixels
    ///
    ///  - parameter size:  kernel size
    ///
    ///  - returns: gaussian kernel piecewise distribution
    public var gaussianKernel:[Float]{
        get{
            let size = self % 2 == 1 ? self : self + 1
            
            let epsilon:Float    = 2e-2 / size.float
            var searchStep:Float = 1.0
            var sigma:Float      = 1.0
            while( true )
            {
                
                let kernel = sigma.gaussianKernel(size: size)
                if kernel[0] > epsilon {
                    
                    if searchStep > 0.02  {
                        sigma -= searchStep
                        searchStep *= 0.1
                        sigma += searchStep
                        continue
                    }
                    
                    var retVal = [Float]()
                    
                    for i in 0 ..< size {
                        retVal.append(kernel[i])
                    }
                    return retVal
                }
                
                sigma += searchStep
                
                if sigma > 1000.0{
                    return [0]
                }
            }
        }
    }
}

// MARK: - Gaussian kernel distribution
public extension Float {
    
    ///  Create gaussian kernel distribution with sigma and kernel size
    ///
    ///  - parameter sigma: kernel sigma
    ///  - parameter size:  kernel size, must be odd number
    ///
    ///  - returns: gaussian kernel piecewise distribution
    ///
    public static func gaussianKernel(sigma sigma:Float, size:Int) -> [Float] {
        
        assert(size%2==1, "gaussian kernel size must be odd number...")
        
        var kernel    = [Float](repeating: 0, count: size)
        let mean      = Float(size/2)
        var sum:Float = 0.0
        
        for x in 0..<size {
            kernel[x] = sqrt( exp( -0.5 * (pow((x.float-mean)/sigma, 2.0) + pow((mean)/sigma,2.0)) )
                / (M_2_PI.float * sigma * sigma) )
            sum += kernel[x]
        }
        
        vDSP_vsdiv(kernel, 1, &sum, &kernel, 1, vDSP_Length(kernel.count))
        return kernel
    }
    
    ///  Create gaussian kernel distribution from sigma value with kernel size
    ///
    ///  - parameter size:  kernel size, must be odd number
    ///
    ///  - returns: gaussian kernel piecewise distribution
    ///
    public func gaussianKernel(size size:Int) -> [Float] {
        return Float.gaussianKernel(sigma: self, size: size)
    }
}
