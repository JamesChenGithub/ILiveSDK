//
//  TCILivePushRequest.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/10/8.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/IMSdkComm.h>

@class TCILiveRoom;

@interface TCILivePushRequest : NSObject

@property (nonatomic, strong) OMAVRoomInfo *roomInfo;   // 房间信息

@property (nonatomic, strong) AVStreamInfo *pushParam;  // 推流参数

@property (nonatomic, strong) AVStreamerResp *pushResp; // 推流返回的结果

- (instancetype)initWith:(TCILiveRoom *)room type:(AVEncodeType)type;
- (instancetype)initWith:(TCILiveRoom *)room channelName:(NSString *)channelName type:(AVEncodeType)type;
- (instancetype)initWith:(TCILiveRoom *)room channelName:(NSString *)channelName channelDesc:(NSString *)channelDesc type:(AVEncodeType)type;

- (NSString *)getHLSPushUrl;
- (NSString *)getRTMPPushUrl;

// type暂只支持HLS, RTMP
- (NSString *)getPushUrl:(AVEncodeType)type;

@end
