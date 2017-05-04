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

@interface IMPBridge : NSObject
+ (float3) xyz_2_luv:(float3)xyz;
+ (float3) luv_2_xyz:(float3)luv;

+ (float3) rgb_2_hsv:(float3)rgb;
+ (float3) hsv_2_rgb:(float3)hsv;

+ (float3) rgb_2_xyz:(float3)rgb;
+ (float3) xyz_2_rgb:(float3)xyz;

+ (float3) lab_2_xyz:(float3)lab;
+ (float3) xyz_2_lab:(float3)xyz;

@end
