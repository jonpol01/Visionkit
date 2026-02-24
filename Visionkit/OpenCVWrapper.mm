//
//  OpenCVWrapper.mm
//  Visionkit
//
//  Created by JOHN PAUL SOLIVA on 2026/02/24.
//

#import "OpenCVWrapper.h"

//#ifdef NO
//#undef NO
//#endif
//
//#ifdef YES
//#undef YES
//#endif

#pragma push_macro("NO")
#pragma push_macro("YES")

#undef NO
#undef YES



#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <opencv2/opencv.hpp>
//#include <opencv2/opencv.hpp>

#pragma pop_macro("YES")
#pragma pop_macro("NO")

using namespace cv;

@implementation OpenCVWrapper

//+ (UIImage *)unwrapCircularText:(UIImage *)image {
//
//    // Convert UIImage to cv::Mat
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    CGFloat cols = image.size.width;
//    CGFloat rows = image.size.height;
//
//    cv::Mat mat(rows, cols, CV_8UC4); // RGBA
//
//    CGContextRef contextRef = CGBitmapContextCreate(
//        mat.data,
//        cols,
//        rows,
//        8,
//        mat.step[0],
//        colorSpace,
//        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault
//    );
//
//    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
//    CGContextRelease(contextRef);
//    CGColorSpaceRelease(colorSpace);
//
//    // Convert to grayscale
//    cv::Mat gray;
//    cvtColor(mat, gray, COLOR_RGBA2GRAY);
//    cv::GaussianBlur(gray, gray, cv::Size(9,9), 2);
//
//    // Detect circle
//    std::vector<Vec3f> circles;
//    HoughCircles(gray, circles, HOUGH_GRADIENT, 1.2, 100, 150, 50, 100, 500);
//
//    if (circles.empty()) {
//        return image;
//    }
//
//    Vec3f c = circles[0];
//    int x = c[0];
//    int y = c[1];
//    int r = c[2];
//
//    int dr = r + 20;
//
//    cv::Rect roi(x-dr, y-dr, dr*2, dr*2);
//
//    if (roi.x < 0 || roi.y < 0 ||
//        roi.x+roi.width > mat.cols ||
//        roi.y+roi.height > mat.rows) {
//        return image;
//    }
//
//    cv::Mat cropped = mat(roi);
//
//    cv::Mat polar;
//    cv::warpPolar(
//        cropped,
//        polar,
//        cv::Size(800, 800),
//        Point2f(dr, dr),
//        dr,
//        WARP_POLAR_LINEAR
//    );
//
//    rotate(polar, polar, ROTATE_90_COUNTERCLOCKWISE);
//
//    // Convert back to UIImage
//    NSData *data = [NSData dataWithBytes:polar.data length:polar.elemSize()*polar.total()];
//    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
//
//    CGImageRef cgImage = CGImageCreate(
//        polar.cols,
//        polar.rows,
//        8,
//        8 * polar.elemSize(),
//        polar.step[0],
//        CGColorSpaceCreateDeviceRGB(),
//        kCGImageAlphaNoneSkipLast,
//        provider,
//        NULL,
//        false,
//        kCGRenderingIntentDefault
//    );
//
//    UIImage *result = [UIImage imageWithCGImage:cgImage];
//
//    CGImageRelease(cgImage);
//    CGDataProviderRelease(provider);
//
//    return result;
//}

+ (CVPixelBufferRef)preprocessPixelBuffer:(CVPixelBufferRef)pixelBuffer {

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    unsigned char *baseAddress = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    cv::Mat bgra((int)height,
                 (int)width,
                 CV_8UC4,
                 baseAddress,
                 bytesPerRow);

    cv::Mat gray;
    cv::cvtColor(bgra, gray, cv::COLOR_BGRA2GRAY);

    cv::Mat enhanced;
    cv::equalizeHist(gray, enhanced);

    cv::Mat backToBGRA;
    cv::cvtColor(enhanced, backToBGRA, cv::COLOR_GRAY2BGRA);

    memcpy(baseAddress, backToBGRA.data, height * bytesPerRow);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return pixelBuffer;
}


@end
