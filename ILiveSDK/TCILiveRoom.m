//
//  TCILiveRoom.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveRoom.h"
#import "TCILiveConst.h"

@implementation TCILiveRoomConfig

- (instancetype)init
{
    if (self = [super init])
    {
        _roomControlRole = nil;
        
        _isSupportIM = YES;
        
        _isFixAVRoomIDAsChatRoomID = YES;
        
        _imChatRoomType = @"AVChatRoom";
        
        _autoEnableMic = NO;
        _autoEnableCamera = YES;
        _autoEnableSpeaker = YES;
        _autoCameraId = CameraPosFront;
        _autoRequestView = YES;
        _isVoiceCall = NO;
        
        _autoRequestView = YES;
//        _autoMonitorNetwork = YES;
        _autoMonitorCall = YES;
//        _autoMonitorKiekedOffline = YES;
        _autoMonitorForeBackgroundSwitch = YES;
        _autoHandleLiveMsg = YES;
        _isNeedExitIMChatRoom = YES;
        
        _enterRoomAuth = QAV_AUTH_BITS_DEFAULT;
        
    }
    return self;
}

- (instancetype)initC2CCall
{
    if (self = [super init])
    {
        _roomControlRole = nil;
        
        _isSupportIM = NO;
        
        _isFixAVRoomIDAsChatRoomID = NO;
        
        _imChatRoomType = nil;
        
        _autoEnableMic = YES;
        _autoEnableCamera = YES;
        _autoEnableSpeaker = YES;
        _autoCameraId = CameraPosFront;
        _autoRequestView = YES;
        
        _autoRequestView = YES;
//        _autoMonitorNetwork = YES;
        _autoMonitorCall = YES;
//        _autoMonitorKiekedOffline = YES;
        _autoMonitorForeBackgroundSwitch = YES;
        _autoHandleLiveMsg = NO;
        _isNeedExitIMChatRoom = NO;
        
        _enterRoomAuth = QAV_AUTH_BITS_DEFAULT;
    }
    return self;
}

- (instancetype)initGroupCall
{
    if (self = [super init])
    {
        _roomControlRole = nil;
        
        _isSupportIM = NO;
        
        _isFixAVRoomIDAsChatRoomID = NO;
        
        _imChatRoomType = @"Private";
        
        _autoEnableMic = YES;
        _autoEnableCamera = YES;
        _autoEnableSpeaker = YES;
        _autoCameraId = CameraPosFront;
        _autoRequestView = YES;
        
        _autoRequestView = YES;
//        _autoMonitorNetwork = YES;
        _autoMonitorCall = YES;
//        _autoMonitorKiekedOffline = YES;
        _autoMonitorForeBackgroundSwitch = YES;
        _autoHandleLiveMsg = NO;
        _isNeedExitIMChatRoom = NO;
        
        _enterRoomAuth = QAV_AUTH_BITS_DEFAULT;
    }
    return self;
}

- (void)setImChatRoomType:(NSString *)imCharRoomType
{
    if ([imCharRoomType isEqualToString:@"Private"] || [imCharRoomType isEqualToString:@"Public"] ||  [imCharRoomType isEqualToString:@"ChatRoom"] || [imCharRoomType isEqualToString:@"AVChatRoom"])
    {
        _imChatRoomType = imCharRoomType;
    }
    else
    {
        TCILDebugLog(@"imCharRoomType (%@) 为不支持的类型", imCharRoomType);
    }
}
@end


@interface TCILiveRoom ()
{
    BOOL _isHostLive;
}

@end
@implementation TCILiveRoom

- (instancetype)init
{
    TCILDebugLog(@"iLiveSDK不建议使用该方法构建房间，请使用其他的init方法构造");
    return nil;
}

- (instancetype)initLiveWith:(int)avRoomID liveHost:(NSString *)liveHostID curUserID:(NSString *)curID roomControlRole:(NSString *)role;
{
    return [self initLiveWith:avRoomID liveHost:liveHostID chatRoomID:nil curUserID:curID roomControlRole:role];
}

- (instancetype)initLiveWith:(int)avRoomID liveHost:(NSString *)liveHostID chatRoomID:(NSString *)chatRoomID curUserID:(NSString *)curID roomControlRole:(NSString *)role
{
    if (self = [super init])
    {
        _isHostLive = [liveHostID isEqualToString:curID];
        _avRoomID = avRoomID;
        _liveHostID = liveHostID;
        _chatRoomID = chatRoomID;
        
        _config = [[TCILiveRoomConfig alloc] init];
        _config.autoEnableCamera = _isHostLive;
        _config.autoEnableMic = _isHostLive;
        _config.roomControlRole = role;
        
        _config.enterRoomAuth = _isHostLive ? QAV_AUTH_BITS_DEFAULT : QAV_AUTH_BITS_JOIN_ROOM | QAV_AUTH_BITS_RECV_AUDIO | QAV_AUTH_BITS_RECV_VIDEO | QAV_AUTH_BITS_RECV_SUB;;
    }
    return self;

}

- (instancetype)initC2CCallWith:(int)avRoomID liveHost:(NSString *)liveHostID curUserID:(NSString *)curID callType:(BOOL)isVoiceCall
{
    if (self = [super init])
    {
        _isHostLive = [liveHostID isEqualToString:curID];
        _avRoomID = avRoomID;
        _liveHostID = liveHostID;
        
        _config = [[TCILiveRoomConfig alloc] initC2CCall];
        _config.autoEnableCamera = !isVoiceCall;
        _config.autoEnableMic = YES;
        _config.isVoiceCall = isVoiceCall;
    }
    return self;
}

- (instancetype)initGroupCallWith:(int)avRoomID liveHost:(NSString *)liveHostID groupID:(NSString *)chatRoomID groupType:(NSString *)groupType curUserID:(NSString *)curID callType:(BOOL)isVoiceCall;
{
    if (self = [super init])
    {
        _isHostLive = [liveHostID isEqualToString:curID];
        _avRoomID = avRoomID;
        _liveHostID = liveHostID;
        _chatRoomID = chatRoomID;
        
        _config = [[TCILiveRoomConfig alloc] initGroupCall];
        _config.autoEnableCamera = !isVoiceCall;
        _config.autoEnableMic = YES;
        _config.isVoiceCall = isVoiceCall;
    }
    return self;
}

- (BOOL)isHostLive
{
    return _isHostLive;
}

@end
