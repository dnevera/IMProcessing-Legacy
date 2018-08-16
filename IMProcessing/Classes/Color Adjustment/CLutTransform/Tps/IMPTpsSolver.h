//
//  IMPTPSSolver.h
//  IMProcessing
//
//  Created by denn on 19.07.2018.
//  Copyright © 2018 Dehancer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface IMPTpsSolver: NSObject

- (instancetype _Nonnull) initWith:(simd_float3*)source
              destination:(simd_float3*)destination
                    count:(int)count
                    lambda:(float)lambda;

- (simd_float3) value:(simd_float3)point;

@property(readonly) const simd_float3 *_Nonnull weights;
@property(readonly) size_t weightsCount;

@end

NS_ASSUME_NONNULL_END
