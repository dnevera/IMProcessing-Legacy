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
#define EDGELSONLINE 5

//typedef struct{
//    IMPEdgel array[1024];
//}IMPEdgelList;

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
    
    LineSegment() : remove(false), start_corner(false), end_corner(false), start(Edgel()), end(Edgel()) {}
    
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
    
    uint currentIndex = 0;
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
                                    texture2d<float> source ,
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
    
    float2 slope = float2(gx, gy);
    
    if (gx!=0 && gy!=0){
        slope = normalize(float2(gx, gy));
    }
    
    return float3(0, slope);
}


//inline float hash( float n )
//{
//    return fract(sin(n)*43758.5453);
//}
//
//inline float rand( float3 x ) {
//    // The noise function returns a value in the range -1.0f -> 1.0f
//    
//    float3 p = floor(x);
//    float3 f = fract(x);
//    
//    f       = f*f*(3.0-2.0*f);
//    float n = p.x + p.y*57.0 + 113.0*p.z;
//    
//    return lerp(lerp(lerp( hash(n+0.0), hash(n+1.0),f.x),
//                     lerp( hash(n+57.0), hash(n+58.0),f.x),f.y),
//                lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
//                     lerp( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
//}


inline uint rand(uint xxx){
    
    float xx = float(xxx);
    
    half x0=floor(xx);
    half x1=x0+1;
    half v0 = fract(sin (x0*.014686)*31718.927+x0);
    half v1 = fract(sin (x1*.014686)*31718.927+x1);
    
    return uint( (v0*(1-fract(xx))+v1*(fract(xx)))*2-1*sin(xx) );
}

inline void findLineSegment(thread Edgel *edgels, uint count/*, device atomic_uint *indexSize*/) {
    constexpr uint maxLength = 1024;
    
    uint s = 0;
    thread LineSegment lineSegments[maxLength];
    thread Edgel       supportEdgels[maxLength];
    thread LineSegment lineSegmentInRun;

    Edgel start;
    Edgel end;
    
    
    uint countIn = count;
    
    thread Edgel edgelsIn[maxLength];
    
    for(uint i = 0; i<countIn && i<maxLength; i++){
        edgelsIn[i] = edgels[i];
    }
    
    
    do {
        lineSegmentInRun.currentIndex = 0;
        
        for (int i = 0; i < 25; i++) {
            thread Edgel r1;
            thread Edgel r2;
            
             int max_iterations = 100;
            int iteration = 0, ir1 = -1, ir2 = 0;

            do {
                ir1 += rand(countIn)%countIn;
                
                ir2 += rand(countIn+10)%countIn;
                
                ir1 %= countIn;
                ir2 %= countIn;
                
                r1 = edgelsIn[ir1];
                r2 = edgelsIn[ir2];
                iteration++;
            } while ( ( ir1 == ir2 || !r1.isOrientationCompatible( r2 ) ) && iteration < max_iterations );

            if( iteration < max_iterations ) {
                // 2 edgels gevonden!
                LineSegment lineSegment;
                lineSegment.start = r1;
                lineSegment.end = r2;
                lineSegment.slope = r1.slope;
                
                //check welke edgels op dezelfde line liggen en voeg deze toe als support
                for (unsigned int o = 0; o < count; o++) {
                    if ( lineSegment.atLine( edgels[o] ) ) {
                        lineSegment.addSupport( edgels[o] );
                    }
                }
                
                if( lineSegment.currentIndex > lineSegmentInRun.currentIndex ) {
                    lineSegmentInRun = lineSegment;
                }
            }
        }
        
        // slope van de line bepalen
        if( lineSegmentInRun.currentIndex >= EDGELSONLINE ) {
            float u1 = 0;
            float u2 = 50000;
            float2 slope = (lineSegmentInRun.start.position - lineSegmentInRun.end.position);
            //float2 orientation = float2( -start.slope.y, start.slope.x );
            
            if (abs (slope.x) <= abs(slope.y)) {
                
                for (uint i = 0; i<lineSegmentInRun.currentIndex; ++i) {

                    thread Edgel *it = &(lineSegmentInRun.supportEdgels[i]);

                    if (it->position.y > u1) {
                        u1 = it->position.y;
                        //lineSegmentInRun.start = it;
                        start = *it;
                    }
                    
                    if (it->position.y < u2) {
                        u2 = it->position.y;
                        end = *it;
                    }
                }
            }
            else {
                for (uint i = 0; i<lineSegmentInRun.currentIndex; ++i) {
                    
                    Edgel it = lineSegmentInRun.supportEdgels[i];
                    
                    if (it.position.x > u1) {
                        u1 = it.position.x;
                        start = it;
                    }
                    
                    if (it.position.x < u2) {
                        u2 = it.position.x;
                        end = it;
                    }
                }
            }

            // switch startpoint and endpoint according to orientation of edge
            
//            float2 p = end.position - start.position;
//            float  d = dot(p,orientation);
            
//            if( dot( end.position - start.position, orientation ) < 0.0f ) {
                //std::swap( lineSegmentInRun.start, lineSegmentInRun.end );
//                Edgel tmp = start;
//                start = end;
//                end = tmp;
//            }
//
//            
//            lineSegmentInRun.slope = normalize((lineSegmentInRun.end.position - lineSegmentInRun.start.position));
//            
//            // heeft de lineSegmentInRun voldoende dan toevoegen aan lineSegments,
//            // gebruikte edgels verwijderen..
//            
//            //lineSegments.push_back( lineSegmentInRun );
//            
//            //TODO: Dit moet sneller!
//            uint countInNew = 0;
//            for(unsigned int i=0; i<lineSegmentInRun.currentIndex; i++) {
//                
//                for (uint i = 0; i<countIn; i++) {
//                    
//                    Edgel it = edgelsIn[i];
//                    
//                    if( it.position.x == lineSegmentInRun.supportEdgels[i].position.x &&
//                       it.position.y == lineSegmentInRun.supportEdgels[i].position.y )
//                    {
//                        break;
//                    }
//                    else{
//                        edgelsIn[countInNew] = edgelsIn[i];
//                        countInNew++;
//                    }
//                }
//            }
//            
//            countIn = countInNew;
        }
        
    } while( lineSegmentInRun.currentIndex >= EDGELSONLINE && countIn >= EDGELSONLINE );
    
    ///return lineSegments;
}


kernel void kernel_edgels(
                          texture2d<float, access::sample> derivative  [[texture(0)]],
                          texture2d<float, access::write>  destination [[texture(1)]],
                          texture2d<float, access::sample> source      [[texture(2)]],
                          constant uint                   &rasterSize  [[buffer(0)]],
                          
                          device atomic_uint              *edgelSize   [[ buffer(1)]],
                          device IMPEdgelList             *edgelArray  [[ buffer(2)]],

                          uint2 groupId   [[threadgroup_position_in_grid]],
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
    
    thread Edgel edgels[1024];
    uint edgelsCount = 0;
    
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
                
                //uint index = atomic_fetch_add_explicit(edgelSize, 1, memory_order_relaxed);
                //edgelSize[rx + ry * gridSize.y] +=1;
                
                
                uint aid = groupId.x + groupId.y * gw;
                device atomic_uint *a = &edgelSize[aid];
                uint index = atomic_fetch_add_explicit(a, 1, memory_order_relaxed);

                if (index>maxLength) {
                    return;
                }

                IMPEdgel edgel;
                edgel.position = float2(rx, ry);
                edgel.slope = slope.yz;

                edgelArray[aid].array[index] = edgel;
                
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
                
                //uint index = atomic_fetch_add_explicit(edgelSize, 1, memory_order_relaxed);
                
                //uint index = edgelSize[rx + ry * gridSize.y];
                //edgelSize[rx + ry * gridSize.y] +=1;

                uint aid = groupId.x + groupId.y * gw;

                device atomic_uint *a = &edgelSize[aid];
                uint index = atomic_fetch_add_explicit(a, 1, memory_order_relaxed);

                if (index>maxLength) {
                    return;
                }
                
                IMPEdgel edgel;
                edgel.position = float2(rx, ry);
                edgel.slope = slope.yz;

                edgelArray[aid].array[index] = edgel;

                destination.write(float4(slope,1),gid-uint2(2));
            }
            prev2 = prev1;
            prev1 = current.r;
        }
    }
    
    //findLineSegment(edgels,edgelsCount);
}


#endif // __cplusplus
#endif // __METAL_VERSION__
#endif // IMPEdgelsDetector_metal_h
