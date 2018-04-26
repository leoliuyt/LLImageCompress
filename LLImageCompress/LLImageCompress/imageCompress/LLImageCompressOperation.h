//
//  LLImageCompressOperation.h
//  DMMacImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

typedef void(^LLCompressFinishedBlock)(NSData *data, NSSize size);

@interface LLImageCompressOperation : NSOperation

- (instancetype)initWithImageAsset:(id)asset
                           maxSize:(CGSize)maxSize
                       maxFileSize:(CGFloat)maxFileSize;

- (void)addHandlersForCompleted:(LLCompressFinishedBlock)completedBlock;
@end
