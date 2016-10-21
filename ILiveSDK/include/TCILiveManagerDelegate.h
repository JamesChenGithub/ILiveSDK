//
//  TCILiveManagerDelegate.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/12.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QALSDK/QalSDKProxy.h>

@protocol TCILiveManagerDelegate <NSObject>

@optional

// AVSDK接口回调
// 返回没有自动处理(registerRenderMemo外部用户可在每次enterRoom之前，添加要渲染的画面的identifier以及对应的无域，详见registerRenderMemo的法)的无程视频处理流程identifier
// 当内部收到AVSDK- (void)OnSemiAutoRecvCameraVideo:(NSArray *)identifierList回调时
- (void)onRecvSemiAutoCameraVideo:(NSArray *)identifierList;

// 将AVSDK抛出的-(void)OnEndpointsUpdateInfo:(QAVUpdateEvent)eventID endpointlist:(NSArray *)endpoints，在内部记录状态后，原样抛出给上层处理，详见AVSDK回调说明
// endpoints : 为QAVEndpoint类型，用户此在回调中注意，不要做长时或异步处理
- (void)onEndpointsUpdateInfo:(QAVUpdateEvent)eventID endpointlist:(NSArray *)endpoints;

// 将AVSDK内部异常退房回调抛出给外部处理，ILiveSDK内部在收到AVSDK的-(void)OnRoomDisconnect:(int)reason回调时，内部已释放相关资源，外部不需要再调用exitRoom进行退房
// result为异常断开的错误码
- (void)onRoomDisconnected:(int)result;

@optional

// 互动直播相关的接口回调
// 外部分配user窗口位置，此处可在界面显示相应的小窗口
// inviteOrAuto : YES, 主动邀请的, NO: 收到邀请主动创建的
- (void)onAssignWindowResourceTo:(NSString *)user isInvite:(BOOL)inviteOrAuto;

// 外部界面切换到请求画面操作
//- (void)onRequestViewComplete:(BOOL)succ;

// 外部回收user窗口资源信息
- (void)onRecycleWindowResourceOf:(NSString *)user;


//=======================================
// deprecated call back
//@optional
//
//// TIMUserStatusListener 回调监听
//// 直播过程中被踢下线，如果直播中，当前用户用同一帐号在其他手机上登录并进行直播间，会影响直播
//- (void)onKickedOfflineWhenLive;
//
//// TIMUserStatusListener 重连失败返回
//- (void)onReConnFailedWhenLiveWithError:(NSError *)error;
//
//// 直播过程中sig过期
//- (void)onCurrentUserSigExpiredWhenLive;
//
//
//@optional
//
//// 网络连上（YES）/断开(NO) 处理
//// type 为此时的网络类型: ILiveSDK内部只返回内部过滤不常用的，只返回以下四种
//// EQALNetworkType_Undefine = -1,
//// EQALNetworkType_NotReachable = 0,
//// EQALNetworkType_ReachableViaWiFi = 1,
//// EQALNetworkType_ReachableViaWWAN = 2,
//- (void)onNetworkConnected:(BOOL)connect networkType:(EQALNetworkType)type;


@optional




@end
