//
//  LLImageCompressOperation.m
//  DMMacImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import "LLImageCompressOperation.h"
#import "NSImage+DM.h"

#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {\
block();\
} else {\
dispatch_async(queue, block);\
}
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif

@interface LLImageCompressOperation()
{
    CGSize _maxSize;
    CGFloat _maxFileSize;
    NSImage *_targetImage;
}

@property (nonatomic, assign, getter = isExecuting) BOOL executing;
@property (nonatomic, assign, getter = isFinished) BOOL finished;

@property (strong, nonatomic, nonnull) dispatch_semaphore_t callbacksLock;

@property (nonatomic, strong) NSMutableArray *callbacks;

@end
@implementation LLImageCompressOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithImageAsset:(id)asset maxSize:(CGSize)maxSize maxFileSize:(CGFloat)maxFileSize
{
    if (self = [super init]) {
        _executing = NO;
        _finished = NO;
        _maxSize = maxSize;
        _maxFileSize = maxFileSize;
        if ([asset isKindOfClass:[NSString class]]) {
            _targetImage = [[NSImage alloc] initWithContentsOfFile:asset];
        } else if ([asset isKindOfClass:[NSURL class]]){
            _targetImage = [[NSImage alloc] initWithContentsOfURL:asset];
        } else {
            _targetImage = asset;
        }
        NSAssert(_targetImage != nil, @"资源有问题");
        _callbacksLock = dispatch_semaphore_create(1);
        _callbacks = [NSMutableArray array];
    }
    return self;
}

- (void)start
{
    NSLog(@"%@",[NSThread currentThread]);
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
        //修改状态 任务执行中
        self.executing = YES;
    }
    [self compressImage:_targetImage maxSize:_maxSize maxFileSize:_maxFileSize];
}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}

- (void)reset {
    LOCK(self.callbacksLock);
    [self.callbacks removeAllObjects];
    UNLOCK(self.callbacksLock);
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)addHandlersForCompleted:(LLCompressFinishedBlock)completedBlock
{
    LOCK(self.callbacksLock);
    //向同一个operation中添加了多个block
    if (completedBlock) {
        [self.callbacks addObject:[completedBlock copy]];
    }
    UNLOCK(self.callbacksLock);
}

//MARK: 压缩
- (void)compressImage:(NSImage *)aImage maxSize:(CGSize)aMaxSize maxFileSize:(CGFloat)maxFileSize
{
    //先调整分辨率
    CGSize maxSize = aMaxSize;
    if (CGSizeEqualToSize(aMaxSize, CGSizeZero)) {
        maxSize = CGSizeMake(4096, 4096);
    }
    
    NSImage *reSizeImage = aImage;
    if (reSizeImage.size.width > maxSize.width || reSizeImage.size.height > maxSize.height) {
        reSizeImage = [aImage scaleAspectFitToSize:maxSize transparent:NO];
    }
    
    NSData *originalData = [reSizeImage TIFFRepresentation];
    NSLog(@"🦋🦋🦋🦋🦋🦋🦋🦋🦋🦋 原始质量%fMB",originalData.length / (1024. * 1024.));
    NSUInteger sizeOrigin   = originalData.length;
    CGFloat sizeOriginMB = sizeOrigin / (1024. * 1024.);
    if (sizeOriginMB <= maxFileSize) {
        [self didFinishedWithData:originalData size:reSizeImage.size];
        return;
    }
    //思路：使用二分法搜索
    NSData *compressedData = [reSizeImage halfFuntionForMaxFileSize:maxFileSize];
    if (compressedData.length > 0) {
        [self didFinishedWithData:compressedData size:reSizeImage.size];
        return;
    }
    
    NSInteger loopCount = 0;
    NSData *tmpData = [originalData copy];
    CGSize imgSize = reSizeImage.size;
    //如果还是未能压缩到指定大小，则进行降分辨率
    while (compressedData.length == 0) {
        loopCount++;
        NSLog(@"😐😐😐😐😐😐😐😐😐😐已经缩减尺寸了%tu次",loopCount);
        //每次长的一边递减100分辨率，另一边以宽高比减少相应长度
        NSAssert(imgSize.height > 0, @"除数为0!");
        CGFloat delt = imgSize.width / imgSize.height;
        CGFloat deltWidth = imgSize.width;
        CGFloat deltHeight = imgSize.height;
        if(delt >= 1) {
            deltWidth -=  100;
            deltHeight -= deltWidth / delt;
        } else {
            deltHeight -= 100;
            deltWidth -=  delt * deltHeight;
        }
        if (deltWidth <= 0 || deltHeight <= 0) {
            compressedData = tmpData;
            break;
        }
        imgSize = CGSizeMake(deltWidth, deltHeight);
        NSImage *image = [aImage scaleAspectFitToSize:imgSize transparent:NO];
        if (!image) {
            compressedData = tmpData;
            break;
        } else {
            imgSize = image.size;
            compressedData = [image halfFuntionForMaxFileSize:maxFileSize];
        }
    }
    NSAssert(compressedData != nil,@"finallImageData为空了");
    if(compressedData.length / (1024. * 1024.) > maxFileSize){
        NSLog(@"未能压缩到指定大小");
        [self didFinishedWithData:nil size:CGSizeZero];
        return;
    }
    [self didFinishedWithData:compressedData size:imgSize];
}

- (void)didFinishedWithData:(NSData *)data size:(CGSize)size
{
    NSLog(@"🦋🦋🦋🦋🦋🦋🦋🦋🦋🦋 Bingo:质量%fMB",data.length / (1024. * 1024.));
    dispatch_main_async_safe(^{
        for(LLCompressFinishedBlock block in self.callbacks){
            block(data,size);
        }
        [self done];
    });
}

- (void)dealloc
{
    NSLog(@"%s",__func__);
}

@end
