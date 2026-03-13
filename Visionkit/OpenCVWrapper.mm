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

static NSArray<NSNumber *> *_lastCircle = nil;

@implementation OpenCVWrapper

+ (NSArray<NSNumber *> *)lastDetectedCircle {
    return _lastCircle;
}

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

+ (void)detectCircle:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    int width  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *base = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    cv::Mat frame(height, width, CV_8UC4, base);
    cv::Mat gray;
    cv::cvtColor(frame, gray, cv::COLOR_BGRA2GRAY);

    cv::Mat norm;
    cv::normalize(gray, norm, 0, 255, cv::NORM_MINMAX);
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(6.0);
    clahe->apply(norm, norm);
    cv::GaussianBlur(norm, norm, cv::Size(5,5), 1.5);

    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        norm, circles, cv::HOUGH_GRADIENT,
        1.5, norm.rows / 3, 150, 80,
        norm.rows / 6, norm.rows / 2
    );

    if (circles.empty()) {
        _lastCircle = nil;
    } else {
        // Pick circle closest to frame center
        float fcx = width / 2.0f, fcy = height / 2.0f;
        cv::Vec3f best = circles[0];
        float bestD = hypotf(best[0] - fcx, best[1] - fcy);
        for (size_t i = 1; i < circles.size(); i++) {
            float d = hypotf(circles[i][0] - fcx, circles[i][1] - fcy);
            if (d < bestD) { best = circles[i]; bestD = d; }
        }
        _lastCircle = @[@(best[0]), @(best[1]), @(best[2])];
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

+ (CVPixelBufferRef)unwrapCircularText:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    int width  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);

    unsigned char *base =
    (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    cv::Mat frame(height, width, CV_8UC4, base);

    //-----------------------------------
    // Fixed center — user aligns object
    // to crosshair, no circle detection
    //-----------------------------------

    float cx = width  / 2.0f;
    float cy = height / 2.0f;
    float r  = MIN(width, height) * 0.40f;

    //-----------------------------------
    // Define ring region (wide band to
    // capture text at various positions)
    //-----------------------------------

    float rInner = r * 0.45;
    float rOuter = r * 1.10;

    int unwrapHeight = 400;
    int unwrapWidth  = 2400;

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
    // Flip horizontally (raw buffer is
    // mirrored vs preview) so text reads
    // correctly for Vision OCR
    //-----------------------------------

    cv::flip(unwrapped, unwrapped, 1);

    //-----------------------------------
    // Convert to grayscale + clean + enhance
    //-----------------------------------

    cv::Mat grayBand;
    cv::cvtColor(unwrapped, grayBand, cv::COLOR_BGRA2GRAY);

    // Mild blur to reduce noise without destroying text edges
    cv::GaussianBlur(grayBand, grayBand, cv::Size(3, 3), 0.5);

    // CLAHE — enhance local contrast (makes engravings stand out)
    cv::Ptr<cv::CLAHE> clahe2 = cv::createCLAHE(3.0, cv::Size(8, 8));
    clahe2->apply(grayBand, grayBand);

    // Adaptive threshold — binarize based on local contrast
    // Works well for engraved text (local dark marks on lighter metal)
    cv::Mat binary;
    cv::adaptiveThreshold(
        grayBand, binary, 255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
        cv::THRESH_BINARY,
        31,   // block size
        8     // C constant
    );

    // Small morphological close to fill gaps in thin text strokes
    cv::Mat kernel = cv::getStructuringElement(
        cv::MORPH_RECT, cv::Size(2, 2)
    );
    cv::morphologyEx(binary, binary, cv::MORPH_CLOSE, kernel);

    cv::Mat &sharpened = binary;

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
        sharpened.cols,
        sharpened.rows,
        kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)attrs,
        &outputBuffer
    );

    CVPixelBufferLockBaseAddress(outputBuffer,0);

    void *dest =
    CVPixelBufferGetBaseAddress(outputBuffer);

    cv::Mat outMat(
        sharpened.rows,
        sharpened.cols,
        CV_8UC4,
        dest
    );

    cv::cvtColor(sharpened, outMat, cv::COLOR_GRAY2BGRA);

    CVPixelBufferUnlockBaseAddress(outputBuffer,0);
    CVPixelBufferUnlockBaseAddress(pixelBuffer,0);

    return outputBuffer;
}

+ (CVPixelBufferRef)cleanForOCR:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    int width  = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *base = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bpr = CVPixelBufferGetBytesPerRow(pixelBuffer);

    cv::Mat bgra(height, width, CV_8UC4, base, bpr);

    cv::Mat gray;
    cv::cvtColor(bgra, gray, cv::COLOR_BGRA2GRAY);

    // Bilateral filter: smooth dirt while preserving text edges
    cv::Mat filtered;
    cv::bilateralFilter(gray, filtered, 9, 75, 75);

    // Morphological open+close: remove small dirt spots
    cv::Mat morphKernel = cv::getStructuringElement(
        cv::MORPH_ELLIPSE, cv::Size(3, 3)
    );
    cv::morphologyEx(filtered, filtered, cv::MORPH_OPEN, morphKernel);
    cv::morphologyEx(filtered, filtered, cv::MORPH_CLOSE, morphKernel);

    // CLAHE for contrast
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(4.0);
    clahe->apply(filtered, filtered);

    // Sharpen
    cv::Mat sharpK = (cv::Mat_<float>(3,3) <<
         0, -1,  0,
        -1,  5, -1,
         0, -1,  0);
    cv::Mat sharpened;
    cv::filter2D(filtered, sharpened, -1, sharpK);

    // Output to new pixel buffer
    CVPixelBufferRef outputBuffer = NULL;
    NSDictionary *attrs = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey:@YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES
    };
    CVPixelBufferCreate(kCFAllocatorDefault,
                        sharpened.cols, sharpened.rows,
                        kCVPixelFormatType_32BGRA,
                        (__bridge CFDictionaryRef)attrs,
                        &outputBuffer);

    CVPixelBufferLockBaseAddress(outputBuffer, 0);
    void *dest = CVPixelBufferGetBaseAddress(outputBuffer);
    cv::Mat outMat(sharpened.rows, sharpened.cols, CV_8UC4, dest);
    cv::cvtColor(sharpened, outMat, cv::COLOR_GRAY2BGRA);
    CVPixelBufferUnlockBaseAddress(outputBuffer, 0);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
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
