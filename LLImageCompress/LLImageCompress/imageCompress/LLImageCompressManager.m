//
//  LLImageCompressManager.m
//  DMMacImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import "LLImageCompressManager.h"
#import "LLImageCompressOperation.h"

@interface LLImageCompressManager()

@property (strong, nonatomic, nonnull) NSOperationQueue *compressQueue;
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSNumber *, LLImageCompressOperation *> *assetOperations;//每个asset对应一个operation

@property (nonatomic, strong) dispatch_semaphore_t operationsLock;

@property (nonatomic, assign) CGSize maxSize;
@property (nonatomic, assign) CGFloat maxFileSize;

@end
@implementation LLImageCompressManager

+ (nonnull instancetype)shared {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithMxSize:CGSizeZero maxFileSize:0];
}

- (instancetype)initWithMxSize:(CGSize)maxSize maxFileSize:(CGFloat)maxFileSize
{
    if (self = [super init]) {
        _maxSize = CGSizeEqualToSize(maxSize, CGSizeZero) ? CGSizeMake(2048*2, 2048*2) : maxSize;
        _maxFileSize = maxFileSize == 0 ? 20 : 0;
        _compressQueue = [NSOperationQueue new];
        _compressQueue.maxConcurrentOperationCount = 6;
        _compressQueue.name = @"com.imagecompress";
        _assetOperations = [NSMutableDictionary dictionary];
        _operationsLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)compressImageWithAsset:(id)asset
                   completed:(LLCompressFinishedBlock)completedBlock
{
    __weak typeof(self) weakSelf = self;
    [self addCompletedBlock:completedBlock
                   forAsset:asset
             createCallback:^LLImageCompressOperation *{
                 LLImageCompressOperation *op = [[LLImageCompressOperation alloc] initWithImageAsset:asset maxSize:weakSelf.maxSize maxFileSize:weakSelf.maxFileSize];
                 [op addHandlersForCompleted:completedBlock];
                 return op;
    }];
}

- (void)addCompletedBlock:(LLCompressFinishedBlock)completedBlock
                 forAsset:(id)asset
           createCallback:(LLImageCompressOperation *(^)(void))createCallback {
    if (asset == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, NSZeroSize);
        }
        return;
    }
    
    NSNumber *key = [NSNumber numberWithUnsignedInteger:[asset hash]];
    LOCK(self.operationsLock);
    LLImageCompressOperation *operation = [self.assetOperations objectForKey:key];
    if (!operation) {
        operation = createCallback();
        __weak typeof(self) wself = self;
        operation.completionBlock = ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            LOCK(sself.operationsLock);
            [sself.assetOperations removeObjectForKey:key];
            UNLOCK(sself.operationsLock);
        };
        [self.assetOperations setObject:operation forKey:key];
        [self.compressQueue addOperation:operation];
    }
    UNLOCK(self.operationsLock);
}
@end
