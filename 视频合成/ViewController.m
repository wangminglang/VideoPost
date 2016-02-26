//
//  ViewController.m
//  视频合成
//
//  Created by WangMinglang on 15/12/28.
//  Copyright © 2015年 好价. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Availability.h>

#define WIDTH [UIScreen mainScreen].bounds.size.width

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    NSURL *videoURL;
    AVURLAsset *firstAsset;
    AVURLAsset *secondAsset;
    AVMutableVideoComposition *mainComposition;
    AVMutableComposition *mixComposition;

}
@property (nonatomic, strong) UIButton *selectButton;
@property (nonatomic, strong) UIButton *mergeButton;
@property (nonatomic, strong) UIImagePickerController *pickerController;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    [self makeTwoButton];

}

- (void)makeTwoButton {
    //选择视频
    self.selectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.selectButton.frame = CGRectMake(0, 0, 100, 100);
    self.selectButton.center = CGPointMake(WIDTH/2, 200);
    [self.selectButton setTitle:@"选择视频" forState:UIControlStateNormal];
    self.selectButton.backgroundColor = [UIColor grayColor];
    [self.selectButton addTarget:self action:@selector(selectVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectButton];
    //合成
    self.mergeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.mergeButton.frame = CGRectMake(0, 0, 100, 100);
    self.mergeButton.center = CGPointMake(WIDTH/2, 400);
    [self.mergeButton setTitle:@"合成" forState:UIControlStateNormal];
    self.mergeButton.backgroundColor = [UIColor grayColor];
    [self.mergeButton addTarget:self action:@selector(mergeVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.mergeButton];

}
//选择视频
- (void)selectVideo {
    self.pickerController = [[UIImagePickerController alloc] init];
    self.pickerController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    self.pickerController.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    self.pickerController.allowsEditing = YES;
    self.pickerController.delegate = self;
    [self presentViewController:self.pickerController animated:YES completion:nil];
}
//合成视频
- (void)mergeVideo {
    if (videoURL != nil) {
        //获取视频信息
        firstAsset = [AVURLAsset assetWithURL:videoURL];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"rain" ofType:@"mp4"];
        secondAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
        if (firstAsset != nil && secondAsset != nil) {
            //调度每个视频的次序
            mixComposition = [[AVMutableComposition alloc] init];
            //加载视频的容器
            AVMutableCompositionTrack *firstTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            
            //视频时长、视频来源、视频合并之后放在第几秒
            [firstTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, firstAsset.duration) ofTrack:[[firstAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
            
            AVMutableCompositionTrack *secondTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [secondTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, secondAsset.duration) ofTrack:[[secondAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
            
            AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            CMTime finalDuration;
            CMTime result;
            //判断时长
            if (CMTimeGetSeconds(firstAsset.duration) == CMTimeGetSeconds(secondAsset.duration)) {
                finalDuration = firstAsset.duration;
            }else if (CMTimeGetSeconds(firstAsset.duration) > CMTimeGetSeconds(secondAsset.duration)) {
                finalDuration = firstAsset.duration;
                result = CMTimeSubtract(firstAsset.duration, secondAsset.duration);
            }else {
                finalDuration = secondAsset.duration;
                result = CMTimeSubtract(secondAsset.duration, firstAsset.duration);
            }
            
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, finalDuration);
            
            //第一个视频架构层，规定视频的样式
            AVMutableVideoCompositionLayerInstruction *firstLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:firstTrack];
            [firstLayerInstruction setTransform:CGAffineTransformIdentity atTime:kCMTimeZero];
            //第二个视频架构层
            AVMutableVideoCompositionLayerInstruction *secondLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:secondTrack];
            [secondLayerInstruction setTransform:CGAffineTransformIdentity atTime:kCMTimeZero];
            [secondLayerInstruction setOpacityRampFromStartOpacity:0.4 toEndOpacity:0.4 timeRange:CMTimeRangeMake(kCMTimeZero, finalDuration)];
            
            //倒序
            mainInstruction.layerInstructions = [NSArray arrayWithObjects:secondLayerInstruction, firstLayerInstruction, nil];
            
            mainComposition = [AVMutableVideoComposition videoComposition];
            mainComposition.instructions = [NSArray arrayWithObjects:mainInstruction, nil];
            mainComposition.frameDuration = CMTimeMake(1, 20);
            mainComposition.renderSize = CGSizeMake(320, 480);
            
            //导出路径
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentPath = [paths firstObject];
            NSString *myDocumentPath = [documentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"mergeVideo.mov"]];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtPath:myDocumentPath error:NULL];
            
            NSURL *url = [NSURL fileURLWithPath:myDocumentPath];
            
            //导出
            AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
            export.outputURL = url;
            export.outputFileType = AVFileTypeQuickTimeMovie;
            export.shouldOptimizeForNetworkUse = YES;
            export.videoComposition = mainComposition;
            [export exportAsynchronouslyWithCompletionHandler:^{
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self exportDidFinish:export];
                    
                });
            }];
            
        }else {
            [self showAlertVC:@"请选择视频"];
        }
        
    }else {
        [self showAlertVC:@"请选择视频"];
    }
}

- (void)exportDidFinish:(AVAssetExportSession *)export {
    if (export.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputUrl = export.outputURL;
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputUrl]) {
            
            [library writeVideoAtPathToSavedPhotosAlbum:outputUrl completionBlock:^(NSURL *assetURL, NSError *error) {
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showAlertVC:@"存档失败"];
                    });

                }else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showAlertVC:@"存档成功"];
                    });
                }
            }];
        }
    }else {
        [self showAlertVC:@"存档失败"];
    }
}
- (void)showAlertVC:(NSString *)tips {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:tips message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    [alertVC addAction:action];
    [self presentViewController:alertVC animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
