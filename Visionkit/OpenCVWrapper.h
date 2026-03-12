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
+ (CVPixelBufferRef _Nullable)unwrapCircularText:(CVPixelBufferRef)pixelBuffer CF_RETURNS_NOT_RETAINED;

+ (CVPixelBufferRef _Nullable)preprocessPixelBuffer:(CVPixelBufferRef)pixelBuffer CF_RETURNS_NOT_RETAINED;


@end

NS_ASSUME_NONNULL_END
