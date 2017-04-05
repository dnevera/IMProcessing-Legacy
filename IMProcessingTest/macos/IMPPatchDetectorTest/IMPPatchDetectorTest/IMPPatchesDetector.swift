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
    
    public var left:float2  { return float2(-slope.x,0) }
    public var top:float2   { return float2(0,slope.y)  }
    public var right:float2 { return float2(slope.w,0)  }
    public var bottom:float2{ return float2(0,-slope.z) }
    
    
    public var direction:float2 {
        return left + top + right + bottom
    }
    
    public mutating func clampDirection(threshold:Float = 0.1) {
        // x - left, y - top, z - bottom, w - right
        
        let d = direction
        
        if d.x>0 && d.y<0 && length(d)>=threshold {
            slope.y = 0 //           __
            slope.x = 0 // left top |
            slope.w = 1
            slope.z = 1
        }
        if d.x<0 && d.y<0 && length(d)>=threshold {
            slope.y = 0 //           __
            slope.w = 0 // right top   |
            slope.x = 1
            slope.z = 1
        }
        if d.x<0 && d.y>0 && length(d)>=threshold {
            slope.w = 0 //
            slope.z = 0 // right bottom  __|
            slope.y = 1
            slope.x = 1
        }
        if d.x>0 && d.y>0 && length(d)>=threshold {
            slope.x = 0 //
            slope.z = 0 // left bottom |__
            slope.y = 1
            slope.w = 1
        }
    }
}

public struct IMPPatch:Equatable {
    
    public init() {}
    
    public static func ==(lhs: IMPPatch, rhs: IMPPatch) -> Bool {
        if let c0 = lhs.center, let c1 = rhs.center {
            return (abs(c0.point.x-c1.point.x) < 0.01) && (abs(c0.point.y-c1.point.y) < 0.01)
        }
        return false
    }
    
    
    public var center:IMPCorner? {
        return _center
    }

    public var horizon:IMPLineSegment? {
        return _horizon
    }

    public var vertical:IMPLineSegment? {
        return _vertical
    }

    public var lt:IMPCorner? {didSet{ vertices[0] = lt } }
    public var rt:IMPCorner? {didSet{ vertices[1] = rt } }
    public var rb:IMPCorner? {didSet{ vertices[2] = rb } }
    public var lb:IMPCorner? {didSet{ vertices[3] = lb } }
    
    private var _horizon: IMPLineSegment?
    private var _vertical: IMPLineSegment?
    
    private var _center:IMPCorner? {
        didSet{
            if let lt = self.lt,
                let rt = self.rt,
                let lb = self.lb,
                let rb = self.rb {
                _horizon = IMPLineSegment(p0: centerOf(lt, lb), p1: centerOf(rt, rb))
                _vertical = IMPLineSegment(p0: centerOf(lt, rt), p1: centerOf(lb, rb))
            }
        }
    }
    
    private func centerOf(_ c0:IMPCorner, _ c1:IMPCorner) -> float2 {
        return (c0.point+c1.point)/float2(2)
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
    
    private func angle(_ pt1:float2, _ pt2:float2, _ pt0:float2 ) -> Float {
        let dx1 = pt1.x - pt0.x
        let dy1 = pt1.y - pt0.y
        let dx2 = pt2.x - pt0.x
        let dy2 = pt2.y - pt0.y
        return acos((dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10)).degrees
    }
    
    private var vertices:[IMPCorner?] = [IMPCorner?](repeating:nil, count:4) {
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
                for i in 0..<4 {
                    let a = fabs(angle(vertices[i]!.point, vertices[(i+2)%4]!.point, vertices[(i+1)%4]!.point))
                    minCosine = fmin(minCosine, a)
                }
                
                if( abs(minCosine-90) <= 10 ) {
                    _center = IMPCorner(point: sumOfR/float2(4), slope: float4(1), color:  col/(float4(4)))
                }
            }
        }
    }
}

public struct IMPPatchesGrid {
    
    public struct PatchInfo {
        var center:float2
        var color:float3
    }
    
    public typealias Patch = IMPPatch
    
    public struct Dimension {
        let width:Int
        let height:Int
    }
    
    public let dimension:Dimension
    public let colors:[[uint3]]
    public var locations = [[PatchInfo?]]()
    public var patches = [Patch]()
    
    public init(colors: [[uint3]] = PassportCC24) {
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
                if  ed < minDistance {
                    return (j,i)
                }
            }
        }
        return nil
    }
    
    mutating func match(minDistance:Float = 5) {
        
        patches.removeAll()
        
        for current in corners {
            
            if current.color.a < 0.1 {continue}
            
            let color = current.color.rgb
            
            var patch = Patch()
            
            if current.slope.w > 0 && current.slope.z > 0 {
                // rb
                patch.lt = current
            }
            else if current.slope.x > 0 && current.slope.y > 0 {
                // rb
                patch.rb = current
            }
            else if current.slope.x > 0 && current.slope.z > 0 {
                // rt
                patch.rt = current
            }
            else if current.slope.y > 0 && current.slope.w > 0 {
                // lb
                patch.lb = current
            }
            
            for next in corners {
                
                if next.point == current.point { continue }
                
                if next.color.a < 0.1 { continue }
                
                let next_color = next.color.rgb
                let ed = color.euclidean_distance_lab(to: next_color)
                
                let dist = distance(next.point, current.point)
                
                
                if ed <= minDistance {
                    
                    if current.slope.w > 0 && current.slope.z > 0 {
                        // lt
                        if patch.lt == nil {
                            patch.lt = next
                        }
                        else if distance(patch.lt!.point, current.point) > dist{
                            patch.lt = next
                        }
                    }
                    
                    if next.slope.x > 0 && next.slope.y > 0 {
                        // rb
                        if patch.rb == nil {
                            patch.rb = next
                        }
                        else if distance(patch.rb!.point, current.point) > dist{
                            patch.rb = next
                        }
                    }
                    if next.slope.x > 0 && next.slope.z > 0 {
                        // rt
                        if patch.rt == nil {
                            patch.rt = next
                        }
                        else if distance(patch.rt!.point, current.point) > dist{
                            patch.rt = next
                        }
                        
                    }
                    if next.slope.y > 0 && next.slope.w > 0 {
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
    }
    
    
    func filterClosing(_ lines:[IMPPolarLine], threshold:Float) -> (line:[IMPPolarLine], rho:Float, theta:Float)? {
        
        guard let firstLine = lines.first else { return nil }
        var prev = firstLine
        var prevFirst:IMPPolarLine? = prev
        
        var result = [IMPPolarLine]()
        
        var minDist:Float = Float.greatestFiniteMagnitude
        
        for i in 1..<lines.count {
            
            let current = lines[i]

            if abs(current.rho - prev.rho) < threshold {
                current.rho = (current.rho + prev.rho)/2
                current.theta = (current.theta + prev.theta)/2
                prevFirst = current
                prev = current
            }
            else {
                
                minDist = min(abs(current.rho - prev.rho),minDist)
                
                if let l = prevFirst {
                    if !result.contains(where: { (p) -> Bool in
                        return abs(p.rho-l.rho)<threshold
                    }) {
                        result.append(l)
                    }
                    prevFirst = nil
                }
                else {
                    let c = current
                    if !result.contains(where: { (p) -> Bool in
                        
                        if sign(p.rho) == sign(c.rho) {
                            return abs(p.rho-c.rho)<threshold && abs(p.theta-c.theta)<Float.pi/45
                        }
                        else {
                            return abs(p.rho+c.rho)<threshold && abs(p.theta + c.theta - Float.pi)<Float.pi/45
                        }
                    }) {
                        result.append(current)
                    }
                }

                prev = current
            }
        }
        
        func getDist(from current:IMPPolarLine, to nextPrev:IMPPolarLine, with minDist:Float) -> Float {
            var dist:Float = minDist
            if sign(nextPrev.rho) == sign(current.rho) {
                if abs(nextPrev.theta-current.theta)<Float.pi/45 {
                    dist = abs(nextPrev.rho - current.rho)
                }
            }
            else {
                if abs(nextPrev.theta + current.theta - Float.pi)<Float.pi/45 {
                    dist = abs(nextPrev.rho + current.rho)
                }
            }
            
            return dist
        }
        
        if let l = prevFirst { result.append(l) }

        guard let nextPrevFirst = result.first else { return nil }
        var nextPrev = nextPrevFirst
        var avrgRho:Float = 0
        var avrgTheta:Float = 0
        var count:Float = 0
        for current in result.suffix(from: 1) {
            let dist:Float = getDist(from: current, to: nextPrev, with: minDist)
            if abs(dist-minDist) <= threshold * 2 {
                avrgRho += dist
                avrgTheta += current.theta
                count += 1
            }
            nextPrev = current
        }
        
        avrgRho /= count
        avrgTheta /= count
        
        nextPrev = nextPrevFirst
        var gaps = [IMPPolarLine]()
        for current in result.suffix(from: 1) {
            let dist:Float = getDist(from: current, to: nextPrev, with: avrgRho)
            if abs(dist-avrgRho) > threshold * 2 {
                for i in 0..<Int(dist/avrgRho) {
                    let l = IMPPolarLine(rho: nextPrev.rho + sign(nextPrev.rho) * avrgRho * (i.float+1), theta: avrgTheta)
                    gaps.append(l)
                }
            }
            nextPrev = current
        }
        
        result.append(contentsOf: gaps)
        result = result.sorted  { return abs($0.rho)<abs($1.rho) }
        
        return (result,avrgRho,avrgTheta)
    }
    
    mutating func approximate(withSize size:NSSize, threshold:Float = 16)
        -> (
        horizon:  [IMPPolarLine],
        vertical: [IMPPolarLine]
        )?
    {
        var horizons  = [IMPPolarLine]()
        var verticals = [IMPPolarLine]()
        
        for p in patches {
            if let h = p.horizon?.polarLine(size: size)  { horizons.append(h) }
            if let v = p.vertical?.polarLine(size: size) { verticals.append(v) }
        }
        
        let horizonSorted  = horizons.sorted  { return abs($0.rho)<abs($1.rho) }
        let vdrticalSorted = verticals.sorted { return abs($0.rho)<abs($1.rho) }
        
        guard let (h,hrho,htheta) = filterClosing(horizonSorted, threshold: threshold) else { return nil }
        //print(" -- -- - - - - - - - - - - - - - - - - - ")
        guard let (v,vrho,vtheta) = filterClosing(vdrticalSorted, threshold: threshold) else { return nil }
        
        let startVRho = v.first!.rho
        let startHRho = h.first!.rho
        let denom = float2(1)/float2(size.width.float,size.height.float)
        for y in 0..<dimension.height {
            var hl = IMPPolarLine(rho: hrho * y.float + startHRho, theta: htheta)
            if h.count > y {
                hl = h[y]
            }
            for x in 0..<dimension.width {
                var vl = IMPPolarLine(rho: vrho * x.float + startVRho, theta: vtheta)
                if v.count > x {
                    vl = v[x]
                }
                let center = vl.intersect(with: hl) * denom
                print(" intersection point = \(center)")
                let info = PatchInfo(center: center, color: float3(0))
                locations[y][x] = info
            }
        }
        
        return (h,v)
    }
    
    //func alignGrid(h:[IMPPolarLine],v:[IMPPolarLine])  {
    //
    //}
    
}

public class IMPPatchesDetector: IMPDetector {
    
    public var radius  = 4 {
        didSet{
            opening.dimensions = (radius,radius)
        }
    }
    public var corners = [IMPCorner]()
    public var hLines = [IMPPolarLine]()
    public var vLines = [IMPPolarLine]()
    public var patchGrid:IMPPatchesGrid = IMPPatchesGrid(colors:PassportCC24)
    
    var oppositThreshold:Float = 0.5
    var nonOrientedThreshold:Float = 0.4
    
    var t = Date()
    
    
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
                    if corner.slope[i] >= self.nonOrientedThreshold{
                        count += 1
                    }
                }
                
                if count > 2 {
                    return false
                }
                
                if corner.slope.x>=self.oppositThreshold &&
                    corner.slope.y>=self.oppositThreshold { return true }
                
                if corner.slope.y>=self.oppositThreshold &&
                    corner.slope.w>=self.oppositThreshold { return true }
                
                if corner.slope.w>=self.oppositThreshold &&
                    corner.slope.z>=self.oppositThreshold { return true }
                
                if corner.slope.z>=self.oppositThreshold &&
                    corner.slope.x>=self.oppositThreshold { return true }
                
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
                
                let i0 = pi0.x  + (pi0.y) * w
                let i1 = pi1.x  + (pi1.y) * w
                
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
        length: MemoryLayout<IMPPatchesGrid.Patch>.size * self.patchGrid.dimension.width * self.patchGrid.dimension.height,
        options: [])
    
    fileprivate lazy var pacthColorsCountBuffer:MTLBuffer = self.context.makeBuffer(from: self.patchGrid.dimension)
    
    private lazy var harrisCornerDetector:IMPHarrisCornerDetector = IMPHarrisCornerDetector(context:  IMPContext())
    private lazy var opening:IMPErosion = IMPOpening(context: self.context)
    
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
    
    private lazy var patchDetector:IMPFilter = {
        let f = IMPFilter(context:self.context)
        f.add(function: self.patchDetectorKernel){ (source) in
            
            guard let size = source.size else {return}
            
            print(" patch detector time = \(-self.t.timeIntervalSinceNow) ")
            memcpy(&self.corners, self.cornersBuffer.contents(), MemoryLayout<IMPCorner>.size * self.corners.count)
            self.patchGrid.corners = self.corners
            if let r = self.patchGrid.approximate(withSize: size){
                (self.hLines, self.vLines) = r
            }
        }
        
        return f
    }()
}

