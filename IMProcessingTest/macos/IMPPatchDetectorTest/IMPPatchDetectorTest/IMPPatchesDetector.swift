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

public struct IMPPatch:Equatable {
    
    init() {}
    
    public static func ==(lhs: IMPPatch, rhs: IMPPatch) -> Bool {
        if let c0 = lhs.center, let c1 = rhs.center {
            return (abs(c0.point.x-c1.point.x) < 0.01) && (abs(c0.point.y-c1.point.y) < 0.01)
        }
        return false
    }
    
    
    public var lt:IMPCorner? {didSet{ vertices[0] = lt } }
    public var rt:IMPCorner? {didSet{ vertices[1] = rt } }
    public var rb:IMPCorner? {didSet{ vertices[2] = rb } }
    public var lb:IMPCorner? {didSet{ vertices[3] = lb } }
    
    private func angle(_ pt1:float2, _ pt2:float2, _ pt0:float2 ) -> Float {
        let dx1 = pt1.x - pt0.x
        let dy1 = pt1.y - pt0.y
        let dx2 = pt2.x - pt0.x
        let dy2 = pt2.y - pt0.y
        return acos((dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10)).degrees
    }

    public var vertices:[IMPCorner?] = [IMPCorner?](repeating:nil, count:4) {
        didSet{
            var sumOfR = float2(0)
            var count = 0
            var col = float4(0)
            for i in 0..<4 {
                let v = vertices[i]
                
                if v != nil {
                    sumOfR += v!.point
                    count += 1
                    col += v!.color
                }
            }
            
            if count == 4 {
                
                var minCosine:Float = Float.greatestFiniteMagnitude //FLT_MAX
                //var aSum:Float = 0
                for i in 0..<4 {
                    let a = fabs(angle(vertices[i]!.point, vertices[(i+2)%4]!.point, vertices[(i+1)%4]!.point))
                    //print(" angle = [\(i%4) = \(a)]")
                    minCosine = fmin(minCosine, a)
                }
                
                if( abs(minCosine-90) <= 10 ) {
                    center = IMPCorner()
                    center?.point = sumOfR/float2(4)
                    center?.color = col/(float4(4))
                }
            }
        }
    }
    
    public mutating func tryReconstract() {
        
        if lt == nil {
            if let rt = self.rt,
                let rb = self.rb,
                let lb = self.lb {
                var c = IMPCorner()
                c.point.x = rt.point.x - abs(rb.point.x - lb.point.x)
                c.point.y = lb.point.y - abs(rt.point.y - rb.point.y)
                c.color = rt.color
                lt = c
            }
        }

        if lb == nil {
            if let rt = self.rt,
                let rb = self.rb,
                let lt = self.lt {
                var c = IMPCorner()
                c.point.x = rb.point.x - abs(lt.point.x - rt.point.x)
                c.point.y = lt.point.y + abs(rt.point.y - rb.point.y)
                c.color = lt.color
                lb = c
            }
        }
        
        if rt == nil {
            if let lb = self.lb,
                let rb = self.rb,
                let lt = self.lt {
                var c = IMPCorner()
                c.point.x = lt.point.x + abs(lb.point.x - rb.point.x)
                c.point.y = rb.point.y - abs(lt.point.y - lb.point.y)
                c.color = lt.color
                rt = c
            }
        }
        
        if rb == nil {
            if let lb = self.lb,
                let rt = self.rt,
                let lt = self.lt {
                var c = IMPCorner()
                c.point.x = lb.point.x + abs(lt.point.x - rt.point.x)
                c.point.y = rt.point.y + abs(lt.point.y - lb.point.y)
                c.color = lt.color
                rb = c
            }
        }

    }
    
    var center:IMPCorner?
}

public struct IMPPatchesGrid {
    
    public typealias Patch = IMPPatch
    
    public struct Dimension {
        let width:Int
        let height:Int
    }
    
    public let dimension:Dimension
    public let colors:[[uint3]]
    public var locations = [[Patch?]]()
    public var patches = [Patch]()
    
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
    
    func findCheckerIndex(color:float3, minDistance:Float = 20) -> (Int,Int)? {
        for i in 0..<dimension.height {
            let row  = colors[i]
            for j in 0..<dimension.width {
                let c = row[j]
                let cc = float3(Float(c.x),Float(c.y),Float(c.z))/float3(255)
                let ed = cc.euclidean_distance_lab(to: color)
                //print("find \(cc.rgb2lab()) -- \(color.rgb2lab()) ed = \(ed)")
                if  ed < minDistance {
                    return (j,i)
                }
            }
        }
        return nil
    }
    
    mutating func match(minDistance:Float = 5) {
        
        patches.removeAll()
        
        for (ci,current) in corners.enumerated() {
            
            if current.slops.w <= 0 && current.slops.z <= 0 {
                //continue
            }
            
            if current.color.a < 0.1 {continue}
            
            let color = current.color.rgb
            
            var patch = Patch()
            
            //patch.lt = current
            
            if current.slops.w > 0 && current.slops.z > 0 {
                // rb
                patch.lt = current
            }
            else if current.slops.x > 0 && current.slops.y > 0 {
                // rb
                patch.rb = current
            }
            else if current.slops.x > 0 && current.slops.z > 0 {
                // rt
                patch.rt = current
            }
            else if current.slops.y > 0 && current.slops.w > 0 {
                // lb
                patch.lb = current
            }
        

            print("corner ===== [\(ci)] patch = \(patch.lt?.point, patch.rt?.point, patch.lb?.point, patch.rb?.point)")

            for (i,next) in corners.enumerated() {
                
                if next.point == current.point { continue }

                if next.color.a < 0.1 { continue }

                //if next.slops == current.slops { continue }

                let next_color = next.color.rgb
                let ed = color.euclidean_distance_lab(to: next_color)
                
                let dist = distance(next.point, current.point)

                if ci == 22{
                    print("new dist[\(i)] [\(next.point)] = \(dist)) slops = \(next.slops) cc = \(current.color.rgb.rgb2lab()) nc = \(next.color.rgb.rgb2lab()) ed = \(ed))")
                }

                if ed <= minDistance {

                    if current.slops.w > 0 && current.slops.z > 0 {
                        // lt
                        if patch.lt == nil {
                            patch.lt = next
                        }
                        else if distance(patch.lt!.point, current.point) > dist{
                            patch.lt = next
                        }
                    }
                    
                    if next.slops.x > 0 && next.slops.y > 0 {
                        // rb
                        if patch.rb == nil {
                            patch.rb = next
                        }
                        else if distance(patch.rb!.point, current.point) > dist{
                            patch.rb = next
                        }
                    }
                    if next.slops.x > 0 && next.slops.z > 0 {
                        // rt
                        if patch.rt == nil {
                            patch.rt = next
                        }
                        else if distance(patch.rt!.point, current.point) > dist{
                            patch.rt = next
                        }

                    }
                    if next.slops.y > 0 && next.slops.w > 0 {
                        // lb
                        if patch.lb == nil {
                            patch.lb = next
                        }
                        else if distance(patch.lb!.point, current.point) > dist{
                            patch.lb = next
                        }
                    }
                    
                    if patch.center != nil {
                        break
                    }
                }
            }
            
            if patch.center == nil {
                patch.tryReconstract()
            }
            
            if patch.center != nil && !patches.contains(patch) {
                patches.append(patch)
            }

        }
        
        
//        for (j,l) in locations.enumerated() {
//            for (i,ll) in l.enumerated() {
//                if let rgb = ll?.lt?.color.rgb, let p = ll?.lt?.point {
//                    print("l[\(j,i)] = \(p, rgb * float3(255))")
//                }
//            }
//        }
    }
    
    func aproxymate()  {
        
        let xSorted = patches.sorted { (p0, p1) -> Bool in
            guard let c0=p0.center?.point, let c1=p1.center?.point else { return false }
            return c0.x < c1.x
        }
        let ySorted = patches.sorted { (p0, p1) -> Bool in
            guard let c0=p0.center?.point, let c1=p1.center?.point else { return false }
            return c0.y < c1.y
        }
        
        var prevDist:Float = Float.greatestFiniteMagnitude
        var distSumm:Float  = 0
        
        guard var prev = xSorted.first?.center?.point else { return }
        var count:Float = 0
        
        for i in 1..<xSorted.count {
            if var current = xSorted[i].center?.point {
                var curDist:Float = 0
                if abs(current.x - prev.x) < 0.01 {
                    current.x = (current.x + prev.x)/2
                }
                else {
                    curDist = min(current.x - prev.x, prevDist)
                    distSumm += curDist
                    count += 1
                    prevDist = curDist
                    prev = current
                }
            }
        }
        
        let avrgX = distSumm/count
        
        prevDist = Float.greatestFiniteMagnitude
        
        guard let prevY = ySorted.first?.center?.point else { return }
        
        prev = prevY
        
        distSumm = 0
        count = 0
        for i in 1..<ySorted.count {
            if var current = ySorted[i].center?.point {
                var curDist:Float = 0
                if abs(current.y - prev.y) < 0.01 {
                    current.y = (current.y + prev.y)/2
                }
                else {
                    curDist = min(current.y - prev.y, prevDist)
                    distSumm += curDist
                    count += 1
                    prevDist = curDist
                    prev = current
                }
            }
        }
        
        let avrgY = distSumm/count
        
        if let startPointX  = xSorted.first?.center?.point.x,
            let startPointY = ySorted.first?.center?.point.y,
            let endPointX = xSorted.last?.center?.point.x,
            let endPointY = ySorted.last?.center?.point.y {
            
            let leftTop     = float2(startPointX,startPointY)
            let rightBottom = float2(endPointX,endPointY)
            
            print("Grid: avrgx = \(avrgX) avrgy = \(avrgY)  coords = \(leftTop, rightBottom) ")
        }
    }
    
}

public class IMPPatchesDetector: IMPDetector {
    
    public var radius  = 4 {
        didSet{
            opening.dimensions = (radius,radius)
        }
    }
    public var corners = [IMPCorner]()
    public var patchGrid:IMPPatchesGrid = IMPPatchesGrid(colors:PassportCC24)
    
    var oppositThreshold:Float = 0.5
    var nonOrientedThreshold:Float = 0.4
    
    var t = Date()

    private lazy var opening:IMPErosion = IMPOpening(context: self.context)
    
    public override func configure(complete: IMPFilterProtocol.CompleteHandler?) {
        
        extendName(suffix: "PatchesDetector")
        
        harrisCornerDetector.pointsMax = 2048
        radius = 1
        
        super.configure()
//            { (source) in
//            self.sourceImage = source
//            self.harrisCornerDetector.source = source
//        }                
        
        add(filter: opening) { (source) in
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

            var sorted = filtered.sorted { (c0, c1) -> Bool in
                
                var pi0 = c0.point * float2(w,h)
                var pi1 = c1.point * float2(w,h)
                
                pi0 = floor(pi0/float2(prec)) * float2(prec)
                pi1 = floor(pi1/float2(prec)) * float2(prec)
                
                let i0 = pi0.x  + (pi0.y) * w
                let i1 = pi1.x  + (pi1.y) * w
                
                return i0<i1
            }
            
//            var sorted = filtered.sorted(by: { (c0, c1) -> Bool in
//                return c0.point.x<c1.point.x
//            })
            
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
        length: MemoryLayout<IMPPatchesGrid.Patch>.size * self.patchGrid.dimension.width * self.patchGrid.dimension.height,
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
            self.patchGrid.aproxymate()
        }

        return f
    }()
}
