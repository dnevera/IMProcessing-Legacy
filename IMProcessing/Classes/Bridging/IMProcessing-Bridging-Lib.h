//
//  IMProcessing-Bridg-Lib.h
//  Pods
//
//  Created by denis svinarchuk on 03.05.17.
//
//

#import <Foundation/Foundation.h>
#include "IMPConstants-Bridging-Metal.h"
#import <simd/simd.h>

@interface IMPBridg : NSObject
+ (float3) xyz_2_luv:(float3)xyz;
+ (float3) luv_2_xyz:(float3)luv;
@end
