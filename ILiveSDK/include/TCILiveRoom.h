//
//  TCILiveRoom.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <QAVSDK/QAVVideoCtrl.h>

@interface TCILiveRoomConfig : NSObject

// 外部根据Spear配置指定，不指定则创建房时时为空，使用默认角色进入
@property (nonatomic, copy) NSString *roomControlRole;

// 直播时使用该权限，电话场景下不使用
@property (nonatomic, assign) unsigned long long enterRoomAuth;

// 是否支持IM消息，默认为YES(支持)
@property (nonatomic, assign) BOOL isSupportIM;

// 是否固定AVRoomID作为IM聊天室ID，默认为YES
@property (nonatomic, assign) BOOL isFixAVRoomIDAsChatRoomID;

// IM聊天室类型，默认为AVChatRoom, 只能为Private,Public,ChatRoom,AVChatRoom
@property (nonatomic, copy) NSString  *imChatRoomType;

// 是否支持后台模式: 默认自动检查info.plist中后台模式配置。
// 若要支持后台发声，显示进入设置为NO，并在target->capabilities->Background Modes勾选 "Audio, AirPlay and Picture in Picture"
@property (nonatomic, assign) BOOL isSupportBackgroudMode;

// 进入房间默认开mic
@property (nonatomic, assign) BOOL autoEnableMic;

// 进入房间相机操作，主播默认打开
@property (nonatomic, assign) BOOL autoEnableCamera;

// 所有场景下，默认打开:YES
@property (nonatomic, assign) BOOL autoEnableSpeaker;

// 进入房间默认打开的摄像头，默认前置
@property (nonatomic, assign) cameraPos autoCameraId;

// 是否自动请求画面
@property (nonatomic, assign) BOOL autoRequestView;

//// 自动监听直播中（进入音视频房间后）的网络变化，默认YES(自动监听)
//@property (nonatomic, assign) BOOL autoMonitorNetwork;

// 自动监听直播中（进入音视频房间后）的外部电话处理，默认YES(自动监听)
@property (nonatomic, assign) BOOL autoMonitorCall;

// 自动监听直播中（进入音视频房间后）的音频中断处理，默认YES(自动监听)
@property (nonatomic, assign) BOOL autoMonitorAudioInterupt;

// 自动监听直播中（进入音视频房间后）的前后台切换逻辑，默认YES(自动监听)
// 如果己监听前后台切换逻辑，建议为NO
@property (nonatomic, assign) BOOL autoMonitorForeBackgroundSwitch;

// 因在直播时，对IM消息处理不当，极易出现卡顿
// 主要原因是：在线直播时，会有大量用户同时发消息，而IM消息回调到主线程，如果主播端在主线程中处理返回的消息，那么极易造成IM消息抢占采集线程，
//           导致上行数据减少，其他观众收下的下行数据也会减少，从而出现卡顿
// 所以我们要减少直播间中渲染IM消息渲染的频率
// 自动处理直播间中的IM消息（内部转到子线程中解析消息，然后用户在了线程中处理渲染计算，处理完之后，抛出给用户）
// 直播场景下，默认为YES
// 电话场景下，消息不是那么频繁，所有默认为NO
@property (nonatomic, assign) BOOL autoHandleLiveMsg;

// 退出时，是否要退出IM群，直播下默认为YES, 电话场景默认为NO
@property (nonatomic, assign) BOOL isNeedExitIMChatRoom;

// 电话场景下使用
@property (nonatomic, assign) BOOL isVoiceCall;


@end


// 直播/互动直播房间
@interface TCILiveRoom : NSObject
{
@protected
    int         _avRoomID;
    NSString    *_chatRoomID;
}

// 直播音视频房间号
@property (nonatomic, readonly) int avRoomID;

// 音视频房间号
@property (nonatomic, copy) NSString *chatRoomID;

// 不能为空
@property (nonatomic, readonly) NSString *liveHostID;

// 建入房间后，外部不要轻易修改里面的值
@property (nonatomic, strong) TCILiveRoomConfig *config;

// 直播场景：主播调用
- (instancetype)initLiveWith:(int)avRoomID liveHost:(NSString *)liveHostID curUserID:(NSString *)curID roomControlRole:(NSString *)role;

// 直播场景：观众调用
- (instancetype)initLiveWith:(int)avRoomID liveHost:(NSString *)liveHostID chatRoomID:(NSString *)chatRoomID curUserID:(NSString *)curID roomControlRole:(NSString *)role;

// 电话场景：C2C电话
- (instancetype)initC2CCallWith:(int)avRoomID liveHost:(NSString *)liveHostID curUserID:(NSString *)curID callType:(BOOL)isVoiceCall;

// 电话场景：Group电话
- (instancetype)initGroupCallWith:(int)avRoomID liveHost:(NSString *)liveHostID groupID:(NSString *)chatRoomID groupType:(NSString *)groupType curUserID:(NSString *)curID callType:(BOOL)isVoiceCall;

- (BOOL)isHostLive;
@end
