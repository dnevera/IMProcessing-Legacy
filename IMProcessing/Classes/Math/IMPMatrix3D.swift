//
//  IMPMatrix3D.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 14.04.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation

public struct IMPMatrix3D{
    
    public var columns:[Float]
    public var rows:   [(y:Float,z:[Float])]
    
    public func column(index:Int) -> [Float] {
        var c = [Float]()
        for i in rows {
            c.append(i.z[index])
        }
        return c
    }
    
    public func row(index:Int) -> [Float] {
        return rows[index].z
    }
    
    public init(columns:[Float], rows:[(y:Float,z:[Float])]){
        self.columns = columns
        self.rows = rows
    }
    
    public init(xy points:[[Float]], zMatrix:[Float]){
        if points.count != 2 {
            fatalError("IMPMatrix3D xy must have 2 dimension Float array with X-points and Y-points lists...")
        }
        columns = points[0]
        rows = [(y:Float,z:[Float])]()
        var yi = 0
        for y in points[1] {
            var row = (y,z:[Float]())
            for _ in 0 ..< columns.count {
                row.z.append(zMatrix[yi])
                yi += 1
            }
            rows.append(row)
        }
    }
    
    public var description:String{
        get{
            var s = "["
            var i=0
            for yi in 0 ..< rows.count {
                let row = rows[yi]
                var ci = 0
                for obj in row.z {
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
            s += "]"
            return s
        }
    }
}

