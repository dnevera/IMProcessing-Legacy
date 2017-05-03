//
//  IMProcessing-Bridg-Lib.m
//  Pods
//
//  Created by denis svinarchuk on 03.05.17.
//
//

#import "IMProcessing-Bridging-Lib.h"
#import "IMPOperations-Bridging-Metal.h"

@implementation IMPBridg
+ (float3) xyz_2_luv:(float3)xyz {
    return xyz_2_luv(xyz);
}
+ (float3) luv_2_xyz:(float3) luv{
    return luv_2_xyz(luv);
}

@end
