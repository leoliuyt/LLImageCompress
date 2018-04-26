//
//  LLImageCompressManager.h
//  DMMacImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LLImageCompressOperation.h"

@interface LLImageCompressManager : NSObject

+ (nonnull instancetype)shared;

- (void)compressImageWithAsset:(id)asset
                     completed:(LLCompressFinishedBlock)completedBlock;

@end
