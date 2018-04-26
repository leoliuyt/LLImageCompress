//
//  ViewController.m
//  LLImageCompress
//
//  Created by leoliu on 2018/4/26.
//  Copyright © 2018年 leoliu. All rights reserved.
//

#import "ViewController.h"
#import "LLImageCompressManager.h"
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)clickAction:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    __weak typeof(self)weakSelf = self;
    
    //允许选中的文件类型
    panel.allowedFileTypes = @[@"png",@"jpg",@"jpeg"];
    //是否可以创建文件夹
    panel.canCreateDirectories = NO;
    //是否可以选择文件夹
    panel.canChooseDirectories = NO;
    //是否可以选择文件
    panel.canChooseFiles = YES;
    //是否可以多选
    panel.allowsMultipleSelection = YES;
    //显示
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        //是否点击open 按钮
        if (result == NSModalResponseOK) {
            NSArray <NSString *>*array = [panel.URLs valueForKeyPath:@"path"];
            [weakSelf testCompressManager:array];
        }
    }];
}


- (void)testCompressManager:(NSArray *)array
{
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[LLImageCompressManager shared] compressImageWithAsset:obj completed:^(NSData *data, NSSize size) {
            NSLog(@"index = %tu,data = %lu,size = %@",idx,data.length,NSStringFromSize(size));
        }];
    }];
}

@end
