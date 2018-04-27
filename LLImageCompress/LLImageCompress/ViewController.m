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
    __weak typeof(self) weakSelf = self;
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[LLImageCompressManager shared] compressImageWithAsset:obj completed:^(NSData *data, NSSize size) {
            NSLog(@"index = %tu,data = %lu,size = %@",idx,data.length,NSStringFromSize(size));
            if (data) {
                NSString *fileName = [NSString stringWithFormat:@"aa_%tu.jpg",data.hash];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                NSLog(@"path = %@",path);
                [data writeToFile:path atomically:YES];
                [weakSelf filesizeForPath:path];
                
                NSData *adata = [NSData dataWithContentsOfFile:path];
                NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
                NSLog(@"data == %lu===%f;image == %lu==%f",adata.length,adata.length / 1000000.,[image TIFFRepresentation].length,([image TIFFRepresentation].length / (1000. * 1000.)));
//              LLImageCompress[18512:11943922] 6720957.000000==6.720957
//              LLImageCompress[18512:11943922] data == 6720957===6.720957;image == 29216750==29.216750
            }
        }];
    }];
}

- (void)filesizeForPath:(NSString *)aPath {
//    /var/folders/cf/2w9p9n251x9b1gvcyt1p8tbw0000gp/T/com.msb.test.LLImageCompress/aa_123191792.jpg
    NSDictionary *dic = [[NSFileManager defaultManager] attributesOfItemAtPath:aPath error:nil];
    CGFloat filesize = [dic[NSFileSize] floatValue];
    NSLog(@"%f==%f",filesize, filesize / 1000./1000.);
}

@end
