//
//  ViewController.m
//  TestReadAndWriter
//
//  Created by 刘东旭 on 2018/9/26.
//  Copyright © 2018年 刘东旭. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (nonatomic, strong) AVAssetReader *assetReader;
//@property (nonatomic, strong) AVAssetReaderTrackOutput *assetReaderOutput;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"abc.mp4"];
    NSLog(@"%@",path);
    [fm removeItemAtPath:path error:nil];
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"IMG_1770" ofType:@"MP4"];
    //初始化AVAssetReader
    NSError *outError;
    AVAsset *someAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    self.assetReader = [AVAssetReader assetReaderWithAsset:someAsset error:&outError];
    BOOL success = (self.assetReader != nil);
    if (!success) {
        NSLog(@"AVAssetReader 创建失败！");
    }
    
    AVAsset *localAsset = self.assetReader.asset;
    // Get the audio track to read.
    AVAssetTrack *audioTrack = [[localAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    // Decompression settings for Linear PCM
    NSDictionary *decompressionAudioSettings = @{ AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM] };
    // Create the output with the audio track and decompression settings.
    AVAssetReaderTrackOutput *audioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:decompressionAudioSettings];
    // Add the output to the reader if possible.
//    if ([self.assetReader canAddOutput:audioTrackOutput]) {
//        [self.assetReader addOutput:audioTrackOutput];
//    }
    
    // Get the video tracks to read.
    AVAssetTrack *videoTrack = [localAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    // Decompression settings for ARGB.
    NSDictionary *decompressionVideoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary] };
    // Create the video composition output with the video tracks and decompression setttings.
    AVAssetReaderTrackOutput *videoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:decompressionVideoSettings];
    // Add the output to the reader if possible.
    if ([self.assetReader canAddOutput:videoTrackOutput])
        [self.assetReader addOutput:videoTrackOutput];
    
    //开始读数据
    // Start the asset reader up.
    [self.assetReader startReading];
    
    //初始化AVAssetWriter
    NSError *outErrorWriter;
    NSURL *outputURL = [NSURL fileURLWithPath:path];
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:outputURL
                                                          fileType:AVFileTypeMPEG4
                                                             error:&outErrorWriter];
    BOOL successWriter = (assetWriter != nil);
    if (!successWriter) {
        NSLog(@"AVAssetWriter 创建失败！");
    }

    //配置写数据，设置比特率，帧率等
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(1.38*1024*1024),
                                             AVVideoExpectedSourceFrameRateKey: @(30),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel };
    //配置编码器宽高等
    NSDictionary *compressionVideoSetting = @{
                                              AVVideoCodecKey                   : AVVideoCodecTypeH264,
                                              AVVideoWidthKey                   : @540,
                                              AVVideoHeightKey                  : @960,
                                              AVVideoCompressionPropertiesKey   : compressionProperties
                                              };

    // Create the asset writer input and add it to the asset writer.
    AVAssetWriterInput *assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:compressionVideoSetting];
    [assetWriter addInput:assetWriterVideoInput];
    
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];
    dispatch_queue_t videoqueue = dispatch_queue_create("videoqueue", DISPATCH_QUEUE_SERIAL);
    __weak typeof(self)weakSelf = self;
    [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:videoqueue usingBlock:^{
        __weak typeof(weakSelf)self = weakSelf;
        
        BOOL done = NO;
        while ([assetWriterVideoInput isReadyForMoreMediaData] && !done)
        {
            // Copy the next sample buffer from the reader output.
            CMSampleBufferRef sampleBuffer = [videoTrackOutput copyNextSampleBuffer];
            if (sampleBuffer)
            {
                // Do something with sampleBuffer here.
                [assetWriterVideoInput appendSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
                sampleBuffer = NULL;
            }
            else
            {
                // Find out why the asset reader output couldn't copy another sample buffer.
                if (self.assetReader.status == AVAssetReaderStatusFailed)
                {
                    NSError *failureError = self.assetReader.error;
                    // Handle the error here.
                }
                else
                {
                    // The asset reader output has read all of its samples.
                    done = YES;
                }
            }
        }
        if (done) {
            [assetWriterVideoInput markAsFinished];
        }
        
        
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [assetWriter finishWritingWithCompletionHandler:^{
            AVAssetWriterStatus status = assetWriter.status;
            if (status == AVAssetWriterStatusCompleted) {
                NSLog(@"video finsished");
                [self.assetReader cancelReading];
                [assetWriter cancelWriting];
            } else {
                NSLog(@"video failure");
                NSLog(@"%@",assetWriter.error);
            }
            
        }];
    });
    

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
