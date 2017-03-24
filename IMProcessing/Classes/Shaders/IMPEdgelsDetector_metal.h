//
//  IMPEdgelsDetector_metal.h
//  IMPBaseOperations
//
//  Created by denis svinarchuk on 24.03.17.
//  Copyright © 2017 Dehancer. All rights reserved.
//

#ifndef IMPEdgelsDetector_metal_h
#define IMPEdgelsDetector_metal_h

#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

#include "IMPSwift-Bridging-Metal.h"
#include "IMPFlowControl_metal.h"
#include "IMPCommon_metal.h"
#include "IMPColorSpaces_metal.h"
#include "IMPBlending_metal.h"

using namespace metal;

#ifdef __cplusplus

#define THRESHOLD 1

class Edgel {
public:
    bool isOrientationCompatible( Edgel cmp );
    void setPosition(int x, int y);
    
    float2 position;
    float2 slope;
};

bool Edgel::isOrientationCompatible( Edgel cmp ) {
    //return fabs( cmp.orientation - orientation ) < 0.0675;
    
    return (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.38;
}

void Edgel::setPosition(int x, int y) {
    position = float2(x,y);
}


class LineSegment {
public:
    
    LineSegment() : remove(false), start_corner(false), end_corner(false) {}
    
    bool atLine( Edgel cmp ){
        if( !start.isOrientationCompatible( cmp ) ) return false;
        
        // distance to line: (AB x AC)/|AB|
        // A = r1
        // B = r2
        // C = cmp
        
        // AB ( r2.x - r1.x, r2.y - r1.y )
        // AC ( cmp.x - r1.x, cmp.y - r1.y )
        
        float cross_ = (float(end.position.x)-float(start.position.x)) *( float(cmp.position.y)-float(start.position.y));
        cross_ -= (float(end.position.y)-float(start.position.y)) *( float(cmp.position.x)-float(start.position.x));
        
        const float d1 = float(start.position.x)-float(end.position.x);
        const float d2 = float(start.position.y)-float(end.position.y);
        
        float distance_ = cross_ / length(float2(d1,d2));
        
        return fabs(distance_) < 0.75f;
    }
    
    void addSupport( Edgel cmp ){
        supportEdgels[currentIndex] = cmp;
        currentIndex++;
    }
 
    bool isOrientationCompatible( LineSegment cmp ){
        return  (slope.x * cmp.slope.x + slope.y * cmp.slope.y) > 0.92f;
    }
    
    float2 getIntersection( LineSegment b ) {
        float2 intersection;
        
        float denom = ((b.end.position.y - b.start.position.y)*(end.position.x - start.position.x)) -
        ((b.end.position.x - b.start.position.x)*(end.position.y - start.position.y));
        
        float nume_a = ((b.end.position.x - b.start.position.x)*(start.position.y - b.start.position.y)) -
        ((b.end.position.y - b.start.position.y)*(start.position.x - b.start.position.x));
        
        float ua = nume_a / denom;
        
        intersection.x = start.position.x + ua * (end.position.x - start.position.x);
        intersection.y = start.position.y + ua * (end.position.y - start.position.y);
        
        return intersection;
    }
    
    Edgel start, end;
    float2 slope;
    bool remove, start_corner, end_corner;
    
    int currentIndex = 0;
    Edgel supportEdgels[1024];
    
    bool operator==(const LineSegment rhs) const {
        return (start.position.x == rhs.start.position.x &&
                start.position.y == rhs.start.position.y &&
                end.position.x == rhs.end.position.x &&
                end.position.y == rhs.end.position.y
                );
    }
};

inline float3 edgeGradientIntensity(
                                    texture2d<float> source      [[texture(2)]],
                                    int x, int y
                                    )
{
    float gx =  source.read(uint2(x-1, y-1)).r;
    gx += 2 * source.read(uint2( x, y-1)).r;
    gx += source.read(uint2(x+1, y-1)).r;
    gx -= source.read(uint2(x-1, y+1)).r;
    gx -= 2 * source.read(uint2(x, y+1)).r;
    gx -= source.read(uint2(x+1, y+1)).r;
    
    float gy = source.read(uint2( x-1, y-1)).r;
    gy += 2 * source.read(uint2( x-1, y)).r;
    gy += source.read(uint2( x-1, y+1)).r;
    gy -= source.read(uint2( x+1, y-1)).r;
    gy -= 2 * source.read(uint2( x+1, y)).r;
    gy -= source.read(uint2( x+1, y+1)).r;
    
    return normalize(float3(0, gx, gy));
}
kernel void kernel_edgels(
                          texture2d<float, access::sample> derivative  [[texture(0)]],
                          texture2d<float, access::write>  destination [[texture(1)]],
                          texture2d<float, access::sample> source      [[texture(2)]],
                          constant uint                   &rasterSize  [[buffer(0)]],
                          
                          device atomic_uint              *edgelSize   [[ buffer(1)]],
                          device Edgel                    *edgelArray  [[ buffer(2)]],

                          uint2 groupId   [[threadgroup_position_in_grid]],
                          //uint2 groupSize [[threads_per_threadgroup]],
                          uint2 gridSize  [[threadgroups_per_grid]],
                          uint2 pid [[thread_position_in_grid]]
                          )
{
    constexpr uint maxLength = 64000;
    uint width  = destination.get_width();
    uint height = destination.get_height();    
    
    uint gw = (width+gridSize.x-1)/gridSize.x;
    uint gh = (height+gridSize.y-1)/gridSize.y;

    for (uint y=0; y<gh; y+=1){
        uint ry = y + groupId.y * gh;
        if (ry > height) break;
        for (uint x=0; x<gw; x+=1){
            uint rx = x + groupId.x * gw;
            if (rx > width) break;
            destination.write(float4(0), uint2(rx,ry));
        }
    }
    
    for (uint y=0; y<gh; y+=rasterSize){
        float prev1 =0.0, prev2 = 0.0;

        uint ry = y + groupId.y * gh;
        
        if (ry > height) break;
        
        for (uint x=0; x<gw; x+=1){
            
            uint rx = x + groupId.x * gw;
            
            if (rx > width) break;

            uint2 gid(rx,ry);
            
            float3 current = derivative.read(gid).rgb;

            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
                float3 slope = edgeGradientIntensity(derivative, rx, ry);
                Edgel edgel;
                edgel.setPosition(rx, ry);
                edgel.slope = slope.yz;
                
                uint index = atomic_fetch_add_explicit(edgelSize, 1, memory_order_relaxed);

                if (index>maxLength) {
                    return;
                }
                
                edgelArray[index] = edgel;

                destination.write(float4(slope,1),gid-uint2(2));
            }
            prev2 = prev1;
            prev1 = current.r;
        }
    }
    
    for (uint x=0; x<gw; x+=rasterSize){
        float prev1 =0.0, prev2 = 0.0;

        uint rx = x + groupId.x * gw;
        
        if (rx > width) break;
        
        for (uint y=0; y<gh; y+=1){
            
            uint ry = y + groupId.y * gh;
            
            if (ry > width) break;
            
            uint2 gid(rx,ry);
            
            float3 current = derivative.read(gid).rgb;
            
            if( prev1 > 0.0f && prev1 >= prev2 && prev1 >= current.r ) {
                float3 slope = edgeGradientIntensity(derivative, rx, ry);
                
                Edgel edgel;
                edgel.setPosition(rx, ry);
                edgel.slope = slope.yz;

                uint index = atomic_fetch_add_explicit(edgelSize, 1, memory_order_relaxed);
                if (index>maxLength) {
                    return;
                }
                edgelArray[index] = edgel;

                destination.write(float4(slope,1),gid-uint2(2));
            }
            prev2 = prev1;
            prev1 = current.r;
        }
    }

}

#endif // __cplusplus
#endif // __METAL_VERSION__
#endif // IMPEdgelsDetector_metal_h
