//
//  AGVideoPreProcessing.h
//  OpenVideoCall
//
//  Created by Alex Zheng on 7/28/16.
//  Copyright © 2016 Agora.io All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AGRenderManager.h"

@class AgoraRtcEngineKit;

@interface AGVideoPreProcessing : NSObject

//+ (void)changSticker:(NSInteger)StickerIndex;
//@property (nonatomic, strong) UIViewController *viewController;

+ (void)setViewControllerDelegate:(id)viewController;
+ (int) registerVideoPreprocessing:(AgoraRtcEngineKit*) kit;
+ (int) deregisterVideoPreprocessing:(AgoraRtcEngineKit*) kit;
@end
		
