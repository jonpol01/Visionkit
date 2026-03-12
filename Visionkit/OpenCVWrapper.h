//
//  OpenCVWrapper.h
//  Visionkit
//
//  Created by JOHN PAUL SOLIVA on 2026/02/24.
//

#ifndef OpenCVWrapper_h
#define OpenCVWrapper_h


#endif /* OpenCVWrapper_h */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

//+ (UIImage *)unwrapCircu@interface OpenCVWrapper : NSObject
+ (CVPixelBufferRef _Nullable)unwrapCircularText:(CVPixelBufferRef)pixelBuffer CF_RETURNS_RETAINED;

/// Returns the last detected circle as [cx, cy, radius] in pixel coords, or nil if none.
+ (NSArray<NSNumber *> * _Nullable)lastDetectedCircle;

+ (CVPixelBufferRef _Nullable)preprocessPixelBuffer:(CVPixelBufferRef)pixelBuffer CF_RETURNS_NOT_RETAINED;

/// Clean frame for better OCR: bilateral filter, morphological cleanup, CLAHE, sharpen.
/// Returns a new buffer — Swift takes ownership and releases automatically.
+ (CVPixelBufferRef _Nullable)cleanForOCR:(CVPixelBufferRef)pixelBuffer CF_RETURNS_RETAINED;


@end

NS_ASSUME_NONNULL_END
