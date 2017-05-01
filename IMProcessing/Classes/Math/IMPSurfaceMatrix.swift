//
//  IMPMatrix3D.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 14.04.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Surge

public struct IMPSurfaceMatrix{
    
    public let columns:[Float]
    public let rows:[Float]
    
    public var weights:Matrix<Float> {
        return _weights
    }
    
    private var _weights:Matrix<Float>
    
    public func column(_ index:Int) -> [Float] {
        return _weights[column:index]
    }
    
    public func row(_ index:Int) -> [Float] {
        return _weights[row:index]
    }
    
    public subscript(_ y:Int, _ x:Int) -> Float {
        get{
            return _weights[y,x]
        }
        set{
            _weights[y,x] = newValue
        }
    }
    
    public init(controls:[float3], xMin:Float = 0, xMax:Float=255, yMin:Float = 0, yMax:Float=255){
        
        let xSorted =  controls.sorted{ return $0.x<$1.x }
        let ySorted =  controls.sorted{ return $0.y<$1.y }
        
        columns = xSorted.map{ return $0.x }
        rows = ySorted.map{ return $0.y }
        
        _weights = Matrix<Float>(rows:controls.count, columns:controls.count, repeatedValue:Float.nan)
        
        for p in controls{
            if let ix = xSorted.index(where: { return p.x == $0.x && p.y == $0.y }),
                let iy = ySorted.index(where: { return p.x == $0.x && p.y == $0.y }){
                _weights[iy,ix] = p.z
            }
        }
        
        for r in 0..<controls.count {
            _weights[row:r] = approx(vector: _weights[row:r], resetZero: true)
        }
        
        for r in 0..<controls.count {
            _weights[column:r] = approx(vector: _weights[column:r], resetZero: false)
        }
    }
    
    public init(columns:[Float], rows:[(y:Float,z:[Float])]){
        self.columns = columns
        self.rows    = rows.map{ return $0.0 }
        _weights = Matrix<Float>(rows: self.rows.count, columns: columns.count, repeatedValue: 0)
        for yi in 0..<rows.count {
            for xi in 0 ..< columns.count {
                _weights[yi,xi] =   rows[yi].z[xi]
            }
        }
    }
    
    public init(xy points:[[Float]], weights:[Float]){
        
        if points.count != 2 {
            fatalError("IMPMatrix3D xy must have 2 dimension Float array with X-points and Y-points lists...")
        }
        
        columns = points[0]
        rows    = points[1]
        _weights = Matrix<Float>(rows: self.rows.count, columns: columns.count, repeatedValue: 0)
        
        for yi in 0..<rows.count {
            for xi in 0 ..< columns.count {
                _weights[yi,xi] = weights[xi + yi * columns.count]
            }
        }
    }
    
    public var description:String{
        get{
            var c = "x = ["
            for i in 0..<columns.count {
                c += String(format: "%2.4f ", columns[i])
            }
            c += "]; "
            var r = "y = ["
            for i in 0..<rows.count {
                r += String(format: "%2.4f ", rows[i])
            }
            r += "]; \n"
            var s = "z = ["
            var i=0
            for yi in 0..<rows.count {
                var ci = 0
                for xi in 0..<columns.count {
                    let obj = _weights[yi,xi]
                    if i>0 {
                        s += ""
                    }
                    i += 1
                    s += String(format: "%2.4f", obj)
                    if i<rows.count*columns.count {
                        if ci<self.columns.count-1 {
                            s += ","
                        }
                        else{
                            s += ";"
                        }
                    }
                    ci += 1
                }
                if (yi<rows.count-1){
                    s += "\n"
                }
            }
            s += "];"
            return c+r+s
        }
    }
    
    
    func approx(vector:[Float], resetZero:Bool ) -> [Float] {
        var result = [Float]()
        result.append(contentsOf: vector)
        var indices = [Int]()
        
        if result.first!.isNaN {
            result[0] = 0
        }
        
        if result.last!.isNaN {
            result[result.count-1] = 0
        }
        
        for i in 0..<result.count{
            if result[i].isFinite {
                indices.append(i)
            }
        }
        
        for i in 0..<indices.count-1 {
            let k = indices[i]
            let n = indices[i+1]
            let v0 = result[k]
            let v1 = result[n]
            let count = n+1
            for j in k..<count{
                let t = Float(j-k)/Float(n-k)
                result[j] = v0.lerp(final: v1, t: t)
            }
        }
        
        if resetZero {
            for i in 0..<result.count{
                if result[i]==0{
                    result[i] = Float.nan
                }
            }
        }
        
        return result
    }
    
}

//public struct IMPMatrix3D{
//    
//    public var columns:[Float]
//    public var rows:   [(y:Float,z:[Float])]
//    
//    public func column(index:Int) -> [Float] {
//        var c = [Float]()
//        for i in rows {
//            c.append(i.z[index])
//        }
//        return c
//    }
//    
//    public func row(index:Int) -> [Float] {
//        return rows[index].z
//    }
//    
//    public init(columns:[Float], rows:[(y:Float,z:[Float])]){
//        self.columns = columns
//        self.rows = rows
//    }
//    
//    public init(xy points:[[Float]], zMatrix:[Float]){
//        if points.count != 2 {
//            fatalError("IMPMatrix3D xy must have 2 dimension Float array with X-points and Y-points lists...")
//        }
//        columns = points[0]
//        rows = [(y:Float,z:[Float])]()
//        var yi = 0
//        for y in points[1] {
//            var row = (y,z:[Float]())
//            for _ in 0 ..< columns.count {
//                row.z.append(zMatrix[yi])
//                yi += 1
//            }
//            rows.append(row)
//        }
//    }
//    
//    public var description:String{
//        get{
//            var s = "["
//            var i=0
//            for yi in 0 ..< rows.count {
//                let row = rows[yi]
//                var ci = 0
//                for obj in row.z {
//                    if i>0 {
//                        s += ""
//                    }
//                    i += 1
//                    s += String(format: "%2.4f", obj)
//                    if i<rows.count*columns.count {
//                        if ci<self.columns.count-1 {
//                            s += ","
//                        }
//                        else{
//                            s += ";"
//                        }
//                    }
//                    ci += 1
//                }
//                if (yi<rows.count-1){
//                    s += "\n"
//                }
//            }
//            s += "]"
//            return s
//        }
//    }
//}
//
