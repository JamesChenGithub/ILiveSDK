//
//  TCILivePushRequest.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/10/8.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILivePushRequest.h"
#import "TCILiveRoom.h"

@implementation TCILivePushRequest

- (instancetype)initWith:(TCILiveRoom *)room type:(AVEncodeType)type
{
    return [self initWith:room channelName:[NSString stringWithFormat:@"%d", [room avRoomID]] type:type];
}

- (instancetype)initWith:(TCILiveRoom *)room channelName:(NSString *)channelName type:(AVEncodeType)type
{
    return [self initWith:room channelName:channelName channelDesc:channelName type:type];
}

- (instancetype)initWith:(TCILiveRoom *)room channelName:(NSString *)channelName channelDesc:(NSString *)channelDesc type:(AVEncodeType)type
{
    if (self = [super init])
    {
        UInt32 roomid = (UInt32)[room avRoomID];
        OMAVRoomInfo *avRoomInfo = [[OMAVRoomInfo alloc] init];
        avRoomInfo.roomId = roomid;
        avRoomInfo.relationId = roomid;
        self.roomInfo = avRoomInfo;
        
        AVStreamInfo *avStreamInfo = [[AVStreamInfo alloc] init];
        avStreamInfo.encodeType = type;
        avStreamInfo.channelInfo = [[LVBChannelInfo alloc] init];
        avStreamInfo.channelInfo.channelName = channelName;
        avStreamInfo.channelInfo.channelDescribe = channelDesc;
        self.pushParam = avStreamInfo;
    }
    return self;
}
- (NSString *)getPushUrl:(AVEncodeType)type
{
    if (type == AV_ENCODE_HLS)
    {
        return [self getHLSPushUrl];
    }
    else if (type == AV_ENCODE_RTMP)
    {
        return [self getRTMPPushUrl];
    }
    return nil;
}


- (NSString *)getHLSPushUrl
{
    if (self.pushResp.urls.count)
    {
        for (AVLiveUrl *url in self.pushResp.urls)
        {
            if ([url.playUrl hasSuffix:@"m3u8"])
            {
                return url.playUrl;
            }
        }
    }
    
    return nil;
}

- (NSString *)getRTMPPushUrl
{
    if (self.pushResp.urls.count)
    {
        for (AVLiveUrl *url in self.pushResp.urls)
        {
            if ([url.playUrl hasPrefix:@"rtmp://"])
            {
                return url.playUrl;
            }
        }
    }
    
    return nil;
}

@end
