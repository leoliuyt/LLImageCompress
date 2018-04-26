//
//  NSImage+DM.m
//  DMMacImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import "NSImage+DM.h"

@implementation NSImage (DM)


/**
 类似UIImage contentMode 的AspectFit 的效果
 
 @param targetSize 目标限定区域
 @param transparent 带有透明背景 YES时 图片的size == targetsize 带有透明背景
 NO 时 图片的size不一定等于targetsize 不会带多余的透明背景
 @return 裁剪后的图片
 */
- (NSImage *)scaleAspectFitToSize:(CGSize)targetSize transparent:(BOOL)transparent
{
    if ([self isValid]) {
        NSSize imageSize = [self size];
        float width  = imageSize.width;
        float height = imageSize.height;
        float targetWidth  = targetSize.width;
        float targetHeight = targetSize.height;
        float scaleFactor  = 0.0;
        float scaledWidth  = targetWidth;
        float scaledHeight = targetHeight;
        
        NSPoint thumbnailPoint = NSZeroPoint;
        
        if (!NSEqualSizes(imageSize, targetSize))
        {
            float widthFactor  = targetWidth / width;
            float heightFactor = targetHeight / height;
            
            if (widthFactor < heightFactor)
            {
                scaleFactor = widthFactor;
            }
            else
            {
                scaleFactor = heightFactor;
            }
            
            scaledWidth  = width  * scaleFactor;
            scaledHeight = height * scaleFactor;
            
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
            }
            
            else if (widthFactor > heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
            
            
            // 等比缩放
            CGSize size = transparent ? targetSize : CGSizeMake(scaledWidth, scaledHeight);
            CGPoint point = transparent ? thumbnailPoint : CGPointZero;
            
            NSImage *newImage = [[NSImage alloc] initWithSize:size];
            
            [newImage lockFocus];
            
            NSRect thumbnailRect;
            thumbnailRect.origin = point;
            thumbnailRect.size.width = scaledWidth;
            thumbnailRect.size.height = scaledHeight;
            
            [self drawInRect:thumbnailRect
                    fromRect:NSZeroRect
                   operation:NSCompositeSourceOver
                    fraction:1.0];
            
            [newImage unlockFocus];
            return newImage;
        }
        return self;
    }
    return nil;
}


/**
 类似UIImage contentMode 的AspectFill 的效果
 
 @param targetSize 目标限定区域
 @param clipsToBounds 返回的图片是否是裁剪过后的
 @return 裁剪后的图片
 */
- (NSImage *)scaleAspectFillToSize:(CGSize)targetSize clipsToBounds:(BOOL)clipsToBounds
{
    if ([self isValid]) {
        
        NSSize imageSize = [self size];
        float width  = imageSize.width;
        float height = imageSize.height;
        float targetWidth  = targetSize.width;
        float targetHeight = targetSize.height;
        float scaleFactor  = 1.0;
        NSRect targetFrame = NSMakeRect(0, 0, targetSize.width, targetSize.height);
        
        if (!NSEqualSizes(imageSize, targetSize))
        {
            float widthFactor  = targetWidth / width;
            float heightFactor = targetHeight / height;
            
            if (!clipsToBounds) {
                if (widthFactor < heightFactor)
                {
                    scaleFactor = heightFactor;
                }
                else
                {
                    scaleFactor = widthFactor;
                }
                
                CGSize scaleSize = CGSizeMake(width * scaleFactor, height * scaleFactor);
                return [self scaleAspectFitToSize:scaleSize transparent:NO];
            }
            
            NSRect cropRect = NSZeroRect;
            if (heightFactor >= widthFactor) {//放大过程中宽度先达到边界
                cropRect.size.width = floor (targetWidth / heightFactor);
                cropRect.size.height = height;
            } else {
                cropRect.size.width = width;
                cropRect.size.height = floor(targetHeight / widthFactor);
            }
            
            cropRect.origin.x = floor( (width - cropRect.size.width)/2 );
            cropRect.origin.y = floor( (height - cropRect.size.height)/2 );
            
            NSImage *targetImage = [[NSImage alloc] initWithSize:targetSize];
            
            [targetImage lockFocus];
            
            //从sourceImage上的fromRect位置处截取图片，绘制到targetFrame上
            [self drawInRect:targetFrame
                    fromRect:cropRect       //portion of source image to draw
                   operation:NSCompositeCopy  //compositing operation
                    fraction:1.0              //alpha (transparency) value
              respectFlipped:YES              //coordinate system
                       hints:@{NSImageHintInterpolation:
                                   [NSNumber numberWithInt:NSImageInterpolationLow]}];
            
            [targetImage unlockFocus];
            return targetImage;
        }
        return self;
    }
    return nil;
}

- (NSData *)compressFactor:(CGFloat)aFactor
{
    NSData *imgData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imgData];
    [imageRep setSize:self.size];
    NSDictionary *imgProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:aFactor] forKey:NSImageCompressionFactor];
    imgData = [imageRep representationUsingType:NSJPEGFileType properties:imgProps];
    return imgData;
}


- (NSData *)halfFuntionForMaxFileSize:(NSInteger)maxSize
{
    //保存压缩系数
    static dispatch_once_t onceToken;
    static NSArray *arr = nil;
    dispatch_once(&onceToken, ^{
        NSMutableArray *compressionQualityArr = [NSMutableArray array];
        CGFloat avg   = 1.0/100;
        CGFloat value = avg;
        for (int i = 100; i >= 1; i--) {
            value = i*avg;
            [compressionQualityArr addObject:@(value)];
        }
        arr = [compressionQualityArr copy];
    });
    
    
    NSData *finallImageData = [self TIFFRepresentation];
    NSData *tempData = [NSData data];
    NSUInteger start = 0;
    NSUInteger end = arr.count - 1;
    NSUInteger index = 0;
    
    NSUInteger difference = NSIntegerMax;
    while(start < end) {
        index = start + (end - start)/2;
        if(index >= arr.count) {
            tempData = [self TIFFRepresentation];
            return tempData;
        }
        finallImageData = [self compressFactor:[arr[index] floatValue]];
        
        NSUInteger sizeOrigin = finallImageData.length;
        CGFloat sizeOriginMB = sizeOrigin / (1024. * 1024.);
        NSLog(@"leoliu 当前降到的质量：%f", sizeOriginMB);
        NSLog(@"%lu----%lf", (unsigned long)index, [arr[index] floatValue]);
        
        if (sizeOriginMB > maxSize) {
            start = index + 1;
        } else if (sizeOriginMB < maxSize) {
            if (maxSize-sizeOriginMB < difference) {
                difference = maxSize-sizeOriginMB;
                tempData = finallImageData;
            }
            end = index - 1;
        } else {
            break;
        }
    }
    return tempData;
}

@end
