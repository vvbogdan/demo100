//
//  AGStickerDownloadManager.m
//  PLMediaStreamingKitDemo
//
//  Created by jacoy on 17/1/20.
//  Copyright © 2017年 0dayZh. All rights reserved.
//

#import "AGStickerDownloadManager.h"
#import "AGSticker.h"
#import "SSZipArchive.h"
#import "AGStickerManager.h"
#import "AGConst.h"

@interface AGStickerDownloader : NSObject <SSZipArchiveDelegate, NSURLSessionDelegate>
@property(nonatomic, strong) NSURLSession *session;

@property(nonatomic, copy) void (^successedBlock)(AGSticker *, NSInteger, AGStickerDownloader *);

@property(nonatomic, copy) void (^failedBlock)(AGSticker *, NSInteger, AGStickerDownloader *);

@property(nonatomic, strong) AGSticker *sticker;

@property(nonatomic, strong) NSURL *url;

@property(nonatomic, assign) NSInteger index;

- (instancetype)initWithSticker:(AGSticker *)sticker url:(NSURL *)url index:(NSInteger)index;

- (void)downloadSuccessed:(void (^)(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader))success failed:(void (^)(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader))failed;

@end

@implementation AGStickerDownloader

- (instancetype)initWithSticker:(AGSticker *)sticker url:(NSURL *)url index:(NSInteger)index {
    if (self = [super init]) {

        self.sticker = sticker;
        self.index = index;
        self.url = url;
    }

    return self;
}

- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session =
                [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[[NSOperationQueue alloc] init]];

    }
    return _session;
}

- (void)downloadSuccessed:(void (^)(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader))success failed:(void (^)(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader))failed {

    [[self.session downloadTaskWithURL:self.url completionHandler:^(NSURL *_Nullable location, NSURLResponse *_Nullable response, NSError *_Nullable error) {

        if (error) {
            failed(self.sticker, self.index, self);
        } else {
            self.successedBlock = success;
            self.failedBlock = failed;
            // unzip
            [SSZipArchive unzipFileAtPath:location.path toDestination:[[AGStickerManager sharedManager] getStickerPath] delegate:self];

        }
    }] resume];

}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *_Nullable))completionHandler {
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];

        if (credential) {
            disposition = NSURLSessionAuthChallengeUseCredential;
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    } else {
        disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark - Unzip complete callback

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath {
    // update sticker's download config
    [[AGStickerManager sharedManager] updateConfigJSON];

    NSString *dir =
            [NSString stringWithFormat:@"%@/%@/", [[AGStickerManager sharedManager] getStickerPath], self.sticker.stickerName];
    NSURL *url = [NSURL fileURLWithPath:dir];

    NSString *s =
            [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"img.jpeg"];

    [AGSticker updateStickerAfterDownload:self.sticker DirectoryURL:url sucess:^(AGSticker *sucessSticker) {

        self.successedBlock(sucessSticker, self.index, self);

    }                                fail:^(AGSticker *failSticker) {

        self.failedBlock(failSticker, self.index, self);

    }];

}

@end

@interface AGStickerDownloadManager ()

/**
 *   操作缓冲池
 */
@property(nonatomic, strong) NSMutableDictionary *downloadCache;

@end

@implementation AGStickerDownloadManager

+ (instancetype)sharedInstance {
    static id _sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [AGStickerDownloadManager new];
    });

    return _sharedManager;
}

- (NSMutableDictionary *)downloadCache {
    if (_downloadCache == nil) {
        _downloadCache = [[NSMutableDictionary alloc] init];
    }
    return _downloadCache;
}

- (void)downloadSticker:(AGSticker *)sticker index:(NSInteger)index withAnimation:(void (^)(NSInteger index))animating successed:(void (^)(AGSticker *sticker, NSInteger index))success failed:(void (^)(AGSticker *sticker, NSInteger index))failed {
    NSString *zipName = [NSString stringWithFormat:@"%@.zip", sticker.stickerName];

    NSURL *downloadUrl = sticker.downloadURL;

    if (sticker.sourceType == AGStickerSourceTypeFromKW) {

        downloadUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", AGStickerDownloadBaseURL, zipName]];
    }

    // 判断是否存在对应的下载操作
    if (self.downloadCache[downloadUrl] != nil) {
        return;
    }

    animating(index);

    AGStickerDownloader *downloader = [[AGStickerDownloader alloc] initWithSticker:sticker url:downloadUrl index:index];

    [self.downloadCache setObject:downloader forKey:downloadUrl];

    [downloader downloadSuccessed:^(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader) {

        [self.downloadCache removeObjectForKey:downloadUrl];
        downloader = nil;
        success(sticker, index);

    }                      failed:^(AGSticker *sticker, NSInteger index, AGStickerDownloader *downloader) {

        [self.downloadCache removeObjectForKey:downloadUrl];
        downloader = nil;
        failed(sticker, index);

    }];

}

- (void)downloadStickers:(NSArray *)stickers withAnimation:(void (^)(NSInteger index))animating successed:(void (^)(AGSticker *sticker, NSInteger index))success failed:(void (^)(AGSticker *sticker, NSInteger index))failed {

    for (AGSticker *sticker in stickers) {
        if (sticker.isDownload == NO && sticker.downloadState == AGStickerDownloadStateDownoadNot) {
            sticker.downloadState = AGStickerDownloadStateDownoading;
            dispatch_async(dispatch_get_main_queue(), ^{

                [self downloadSticker:sticker index:[stickers indexOfObject:sticker] withAnimation:^(NSInteger index) {

                    animating([stickers indexOfObject:sticker]);

                }           successed:^(AGSticker *sticker, NSInteger index) {
                    success(sticker, index);

                }              failed:^(AGSticker *sticker, NSInteger index) {
                    failed(sticker, index);

                }];

            });
        }
    }

}


@end
