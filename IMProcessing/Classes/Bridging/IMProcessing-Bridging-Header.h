//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//


#ifndef IMProcessing_Bridging_Metal_h
#define IMProcessing_Bridging_Metal_h

#import "IMPTypes-Bridging-Metal.h"
#import "IMPConstants-Bridging-Metal.h"
#import "IMPOperations-Bridgin-Metal.h"
#import "IMPHistogramTypes-Bridging-Metal.h"

#ifndef __METAL_VERSION__

#import "IMPExif.h"
//#import "IMPJpegturbo.h"

#endif

#endif //IMProcessing_Bridging_Metal_h
