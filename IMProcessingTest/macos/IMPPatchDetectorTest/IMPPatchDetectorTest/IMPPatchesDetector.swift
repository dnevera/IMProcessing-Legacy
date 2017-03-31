//
//  IMPPatchesDetector.swift
//  IMPPatchDetectorTest
//
//  Created by denis svinarchuk on 31.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

import Foundation
import Metal
import simd


extension float3 {
    func euclidean_distance(to p_2: float3) -> Float {
        var sum:Float = 0
        for i in 0..<3 {
            sum += pow(self[i]-p_2[i],2.0)
        }
        return sqrt(sum)
    }
    
    func euclidean_distance_lab(to p_2: float3) -> Float {
        let c0 = self.rgb2lab()
        let c1 = p_2.rgb2lab()
        return c0.euclidean_distance(to:c1)
    }
    
}


extension IMPCorner: Equatable {
    
    public static func ==(lhs: IMPCorner, rhs: IMPCorner) -> Bool {
        return (abs(lhs.point.x-rhs.point.x) < 0.1) && (abs(lhs.point.y-rhs.point.y) < 0.1)
    }
    
    
    var left:float2  { return float2(-slops.x,0) }
    var top:float2   { return float2(0,slops.y)  }
    var right:float2 { return float2(slops.w,0)  }
    var bottom:float2{ return float2(0,-slops.z) }
    
    
    var direction:float2 {
        return left + top + right + bottom
    }
    
    mutating func clampDirection(threshold:Float = 0.1) {
        // x - left, y - top, z - bottom, w - right
        
        let d = direction
        
        if d.x>0 && d.y<0 && length(d)>=threshold {
            slops.y = 0 //           __
            slops.x = 0 // left top |
            slops.w = 1
            slops.z = 1
        }
        if d.x<0 && d.y<0 && length(d)>=threshold {
            slops.y = 0 //           __
            slops.w = 0 // right top   |
            slops.x = 1
            slops.z = 1
        }
        if d.x<0 && d.y>0 && length(d)>=threshold {
            slops.w = 0 //
            slops.z = 0 // right bottom  __|
            slops.y = 1
            slops.x = 1
        }
        if d.x>0 && d.y>0 && length(d)>=threshold {
            slops.x = 0 //
            slops.z = 0 // left bottom |__
            slops.y = 1
            slops.w = 1
        }
    }
}


//
// http://xritephoto.com/ph_product_overview.aspx?ID=824&Action=Support&SupportID=5159
//
public let PassportCC24:[[uint3]] = [
    [
        uint3(115,82,68),   // dark skin
        uint3(194,150,130), // light skin
        uint3(98,122,157),  // blue sky
        uint3(87,108,67),   // foliage
        uint3(133,128,177), // blue flower
        uint3(103,189,170)  // bluish flower
    ],

    [
        uint3(214,126,44), // orange
        uint3(80,91,166),  // purplish blue
        uint3(193,90,99),  // moderate red
        uint3(94,60,108),  // purple
        uint3(157,188,64), // yellow green
        uint3(224,163,46)  // orange yellow
    ],

    [
        uint3(56,61,150),  // blue
        uint3(79,148,73),  // green
        uint3(175,54,60),  // red
        uint3(231,199,31), // yellow
        uint3(187,86,149), // magenta
        uint3(8,133,161),  // cyan
    ],

    [
        uint3(243,243,242), // white
        uint3(200,200,200), // neutral 8
        uint3(160,160,160), // neutral 6,5
        uint3(122,122,121), // neutral 5
        uint3(85,85,85),    // neutral 3.5
        uint3(52,52,52)     // black
    ]
]

public struct IMPPatchesGrid {
    
    public struct Dimension {
        let width:Int
        let height:Int
    }
    
    public struct Location {
        var lt:IMPCorner?
        var rt:IMPCorner?
        var lb:IMPCorner?
        var rb:IMPCorner?
        
        var center:IMPCorner {
            get{
                var v = IMPCorner()
                if rb != nil {
                    
                }
                return v
            }
        }
    }
    
    public let dimension:Dimension
    public let colors:[[uint3]]
    public var locations = [[Location?]]()
    
    public init(colors: [[uint3]]) {
        dimension = Dimension(width: colors[0].count, height: colors.count)
        self.colors = colors
        for y in 0..<dimension.height {
            locations.insert([], at: y)
            for x in 0..<dimension.width {
                locations[y].insert(nil, at: x)
            }
        }
    }
    
    public var corners = [IMPCorner]() { didSet{ match() } }
    
    func findCheckerIndex(color:float3, minDistance:Float = 0.1) -> (Int,Int)? {
        for i in 0..<dimension.height {
            let row  = colors[i]
            for j in 0..<dimension.width {
                let c = row[j]
                let cc = float3(Float(c.x),Float(c.y),Float(c.z))/float3(255)
                if cc.euclidean_distance(to: color) < minDistance {
                    return (j,i)
                }
            }
        }
        return nil
    }
    
    mutating func match(minDistance:Float = 0.1) {
        for current in corners {
            
            if current.slops.w <= 0 && current.slops.z <= 0 {
                continue
            }
            
            if current.color.a < 0.1 {continue}
            
            let color = current.color.rgb
            
            var location = Location()
            
            location.lt = current
            
            var locationIndex:(Int,Int)? = nil
            
            for next in corners {
                
                if next == current { continue }

                if next.color.a < 0.1 {continue}

                let next_color = next.color.rgb
                let ed = color.euclidean_distance(to: next_color)
                if ed <= minDistance {
                    
                    if let index =  findCheckerIndex(color: color){
                        
                        if next.slops.x > 0 && next.slops.y > 0 {
                            // rb
                            location.rb = next
                        }
                        if next.slops.w > 0 && next.slops.w > 0 {
                            // rt
                            location.rt = next
                        }
                        if next.slops.y > 0 && next.slops.x > 0 {
                            // lb
                            location.lb = next
                        }
                        
                        locationIndex = index
                        
                        break
                    }
                }
            }
            
            if let p = locationIndex {
                locations[p.1][p.0] = location
            }
        }
        
        for (j,l) in locations.enumerated() {
            for (i,ll) in l.enumerated() {
                if let rgb = ll?.lt?.color.rgb, let p = ll?.lt?.point {
                    print("l[\(j,i)] = \(p, rgb * float3(255))")
                }
            }
        }
    }
    
}

public class IMPPatchesDetector: IMPDetector {
    
    public var corners = [IMPCorner]()
    public var patchGrid:IMPPatchesGrid = IMPPatchesGrid(colors:PassportCC24)
    
    var oppositThreshold:Float = 0.5
    var nonOrientedThreshold:Float = 0.4
    
    var t = Date()

    public override func configure(complete: IMPFilterProtocol.CompleteHandler?) {
        
        extendName(suffix: "PatchesDetector")
        
        harrisCornerDetector.pointsMax = 2048
        
        super.configure(){ (source) in
            self.sourceImage = source
            self.harrisCornerDetector.source = source
        }
        
        patchDetectorKernel.threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        
        harrisCornerDetector.addObserver { (corners:[IMPCorner], size:NSSize) in
            self.t = Date()

            var filtered = corners.filter { (corner) -> Bool in
                
                var count = 0
                for i in 0..<4 {
                    if corner.slops[i] >= self.nonOrientedThreshold{
                        count += 1
                    }
                }
                
                if count > 2 {
                    return false
                }
                
                if corner.slops.x>=self.oppositThreshold &&
                    corner.slops.y>=self.oppositThreshold { return true }
                
                if corner.slops.y>=self.oppositThreshold &&
                    corner.slops.w>=self.oppositThreshold { return true }
                
                if corner.slops.w>=self.oppositThreshold &&
                    corner.slops.z>=self.oppositThreshold { return true }
                
                if corner.slops.z>=self.oppositThreshold &&
                    corner.slops.x>=self.oppositThreshold { return true }
                
                return false
            }
            
            filtered = filtered.map({ ( c) -> IMPCorner in
                var c = c
                c.clampDirection()
                return c
            })
            
            let w = Float(size.width)
            let h = Float(size.height)

            let prec:Float = 8

            let sorted = filtered.sorted { (c0, c1) -> Bool in
                
                var pi0 = c0.point * float2(w,h)
                var pi1 = c1.point * float2(w,h)
                
                pi0 = floor(pi0/float2(prec)) * float2(prec)
                pi1 = floor(pi1/float2(prec)) * float2(prec)
                
                let i0 = pi0.x  + pi0.y * w
                let i1 = pi1.x  + pi1.y * w
                
                return i0<i1
            }
            
            self.corners = sorted
            
            self.patchDetectorKernel.preferedDimension =  MTLSize(width: self.corners.count, height: 1, depth: 1)
            
            self.cornersCountBuffer <- self.corners.count
            
            memcpy(self.cornersBuffer.contents(), self.corners, self.corners.count * MemoryLayout<IMPCorner>.size)
            
            self.patchDetector.source = self.harrisCornerDetector.source
            self.patchDetector.process()
        }
    }
    
    var sourceImage:IMPImageProvider?
    
    fileprivate lazy var cornersBuffer:MTLBuffer = self.context.device.makeBuffer(
        length: MemoryLayout<IMPCorner>.size * Int(self.harrisCornerDetector.pointsMax),
        options: .storageModeShared)

    fileprivate lazy var cornersCountBuffer:MTLBuffer = self.context.makeBuffer(from: self.harrisCornerDetector.pointsMax)
    
    fileprivate lazy var pacthColorsBuffer:MTLBuffer = self.context.device.makeBuffer(
        bytes:  self.patchGrid.colors,
        length: MemoryLayout<IMPPatchesGrid.Location>.size * self.patchGrid.dimension.width * self.patchGrid.dimension.height,
        options: [])
        
    fileprivate lazy var pacthColorsCountBuffer:MTLBuffer = self.context.makeBuffer(from: self.patchGrid.dimension)

    private lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())
    
    private lazy var patchDetectorKernel:IMPFunction = {
        let f = IMPFunction(context: self.context, kernelName: "kernel_patchScanner")
        f.optionsHandler = { (function,command,source,destination) in
            
            if let texture = self.sourceImage?.texture {
                command.setTexture(texture, at: 2)
            }

            command.setBuffer(self.cornersBuffer,          offset: 0, at: 0)
            command.setBuffer(self.cornersCountBuffer,     offset: 0, at: 1)
            command.setBuffer(self.pacthColorsBuffer,      offset: 0, at: 2)
            command.setBuffer(self.pacthColorsCountBuffer, offset: 0, at: 3)
        }
        return f
    }()

    lazy var patchDetector:IMPFilter = {
        let f = IMPFilter(context:self.context)
        f.add(function: self.patchDetectorKernel){ (source) in
            print(" patch detector time = \(-self.t.timeIntervalSinceNow) ")
            memcpy(&self.corners, self.cornersBuffer.contents(), MemoryLayout<IMPCorner>.size * self.corners.count)
            self.patchGrid.corners = self.corners
        }

        return f
    }()
}
