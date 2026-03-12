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

//+ (CVPixelBufferRef)unwrapCircularText:(CVPixelBufferRef)pixelBuffer {
//
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//
//    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
//    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
//    unsigned char *base = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
//
//    cv::Mat mat(height, width, CV_8UC4, base);
//
//    // Convert to grayscale
//    cv::Mat gray;
//    cvtColor(mat, gray, cv::COLOR_BGRA2GRAY);
//
//    GaussianBlur(gray, gray, cv::Size(9,9), 2);
//
//    // Detect circle
//    std::vector<cv::Vec3f> circles;
//    HoughCircles(gray, circles, cv::HOUGH_GRADIENT, 1.2, 200, 120, 40, 100, 600);
//
//    if (circles.empty()) {
//        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//        return pixelBuffer;
//    }
//
//    cv::Vec3f c = circles[0];
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
//        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//        return pixelBuffer;
//    }
//
//    cv::Mat cropped = mat(roi);
//
//    cv::Mat polar;
//
//    warpPolar(
//        cropped,
//        polar,
//        cv::Size(800,800),
//        cv::Point2f(dr,dr),
//        dr,
//        cv::WARP_POLAR_LINEAR
//    );
//
//    int bandTop = polar.rows * 0.60;
//    int bandHeight = polar.rows * 0.25;
//
//    cv::Rect band(0, bandTop, polar.cols, bandHeight);
//    cv::Mat textOnly = polar(band);
//    rotate(textOnly, textOnly, ROTATE_90_COUNTERCLOCKWISE);
//
////    rotate(polar, polar, cv::ROTATE_90_COUNTERCLOCKWISE);
//
//    // Create new pixel buffer
//    CVPixelBufferRef outputBuffer = NULL;
//
//    NSDictionary *attrs = @{
//        (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
//        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
//    };
//
//    CVPixelBufferCreate(kCFAllocatorDefault,
//                        polar.cols,
//                        polar.rows,
//                        kCVPixelFormatType_32BGRA,
//                        (__bridge CFDictionaryRef)attrs,
//                        &outputBuffer);
//
//    CVPixelBufferLockBaseAddress(outputBuffer, 0);
//
//    void *dest = CVPixelBufferGetBaseAddress(outputBuffer);
//
//    memcpy(dest, polar.data, polar.total() * polar.elemSize());
//
//    CVPixelBufferUnlockBaseAddress(outputBuffer, 0);
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//
//    return outputBuffer;
//}

+ (CVPixelBufferRef)unwrapCircularText:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int width  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);

    unsigned char *base =
    (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    cv::Mat frame(height, width, CV_8UC4, base);

    //-----------------------------------
    // Convert to grayscale
    //-----------------------------------

    cv::Mat gray;
    cv::cvtColor(frame, gray, cv::COLOR_BGRA2GRAY);

    //-----------------------------------
    // Normalize lighting
    //-----------------------------------

    cv::Mat norm;
    cv::normalize(gray, norm, 0, 255, cv::NORM_MINMAX);

    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(6.0);
    clahe->apply(norm, norm);

    cv::GaussianBlur(norm, norm, cv::Size(5,5), 1.5);

    //-----------------------------------
    // Edge detection
    //-----------------------------------

    cv::Mat edges;
    cv::Canny(norm, edges, 60, 140);

    //-----------------------------------
    // Circle detection
    //-----------------------------------

    std::vector<cv::Vec3f> circles;

    cv::HoughCircles(
        edges,
        circles,
        cv::HOUGH_GRADIENT,
        1.2,
        norm.rows/4,
        120,
        40,
        norm.rows/6,
        norm.rows/2
    );

    if(circles.empty())
    {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return pixelBuffer;
    }

    cv::Vec3f c = circles[0];

    float cx = c[0];
    float cy = c[1];
    float r  = c[2];

    //-----------------------------------
    // Define ring region
    //-----------------------------------

    float rInner = r * 0.75;
    float rOuter = r * 1.05;

    int unwrapHeight = 120;
    int unwrapWidth  = 1000;

    //-----------------------------------
    // Build remap grids
    //-----------------------------------

    cv::Mat mapX(unwrapHeight, unwrapWidth, CV_32F);
    cv::Mat mapY(unwrapHeight, unwrapWidth, CV_32F);

    for(int y=0; y<unwrapHeight; y++)
    {
        float radius =
        rInner + (rOuter - rInner) * (float)y / unwrapHeight;

        for(int x=0; x<unwrapWidth; x++)
        {
            float theta =
            2.0f * CV_PI * (float)x / unwrapWidth;

            mapX.at<float>(y,x) =
            cx + radius * cos(theta);

            mapY.at<float>(y,x) =
            cy + radius * sin(theta);
        }
    }

    //-----------------------------------
    // Perform polar remap
    //-----------------------------------

    cv::Mat unwrapped;

    cv::remap(
        frame,
        unwrapped,
        mapX,
        mapY,
        cv::INTER_LINEAR,
        cv::BORDER_CONSTANT
    );

    //-----------------------------------
    // Convert to grayscale
    //-----------------------------------

    cv::Mat grayBand;
    cv::cvtColor(unwrapped, grayBand, cv::COLOR_BGRA2GRAY);

    //-----------------------------------
    // Enhance engraved characters
    //-----------------------------------

    cv::Mat blackhat;

    cv::Mat kernel =
    cv::getStructuringElement(
        cv::MORPH_RECT,
        cv::Size(21,7)
    );

    cv::morphologyEx(
        grayBand,
        blackhat,
        cv::MORPH_BLACKHAT,
        kernel
    );

    //-----------------------------------
    // Threshold
    //-----------------------------------

    cv::Mat thresh;

    cv::adaptiveThreshold(
        blackhat,
        thresh,
        255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
        cv::THRESH_BINARY,
        15,
        -2
    );

    //-----------------------------------
    // Output CVPixelBuffer
    //-----------------------------------

    CVPixelBufferRef outputBuffer = NULL;

    NSDictionary *attrs = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey:@YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES
    };

    CVPixelBufferCreate(
        kCFAllocatorDefault,
        thresh.cols,
        thresh.rows,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)attrs,
        &outputBuffer
    );

    CVPixelBufferLockBaseAddress(outputBuffer,0);

    void *dest =
    CVPixelBufferGetBaseAddress(outputBuffer);

    cv::Mat outMat(
        thresh.rows,
        thresh.cols,
        CV_8UC4,
        dest
    );

    cv::cvtColor(thresh, outMat, cv::COLOR_GRAY2BGRA);

    CVPixelBufferUnlockBaseAddress(outputBuffer,0);
    CVPixelBufferUnlockBaseAddress(pixelBuffer,0);

    return outputBuffer;
}

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
