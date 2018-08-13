//
//  IMPTPSSolverBridge.m
//  IMProcessing
//
//  Created by denn on 19.07.2018.
//  Copyright © 2018 Dehancer. All rights reserved.
//

#import "IMPTpsSolverBridge.h"
#import "IMPTpsSolver.h"
#import "IMPConstants-Bridging-Metal.h"

@implementation IMPTpsSolverBridge
{
    IMProcessing::IMPTpsSolver<simd_float3,float,3> *solver;
}

-(instancetype) initWith:(simd_float3 *)source destination:(simd_float3 *)destination count:(int)count lambda:(float)lambda {
        
    self = [super init];
    
    if (self) {
        solver = new IMProcessing::IMPTpsSolver<simd_float3,float,3>(source, destination, count, lambda);
    }
    
    return self;
}

- (const simd_float3 *_Nonnull) weights {
    return solver->getWeights();
}

- (size_t) weightsCount {
    return solver->getWeightsCount();
}

- (simd_float3) value:(simd_float3)point {
    return solver->value(point);
}

- (void) dealloc {
   delete solver;
}
@end
