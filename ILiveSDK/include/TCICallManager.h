//
//  TCICallManager.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/12.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TCILiveManager.h"

#import "TCICallCMD.h"

typedef void (^TCICallBlock)(TCICallCMD *callCmd);
typedef void (^TCIAcceptCallBlock)(BOOL succ, NSError *err, TCILiveRoom *enterRoom);

// TCICallManager当在打电话或正在接听电话时，内部自动回绝此过程中非本次通话的命令
@interface TCICallManager : TCILiveManager


//// 默认30秒，只处理30秒内收到的消息
//@property (nonatomic, assign) NSInteger callTimeout;
// 全局监听来电回调
@property (nonatomic, copy) TCICallBlock incomingCallBlock;

// 进入房间后，再发送呼叫命令
- (void)makeC2CCall:(NSString *)recvID callCMD:(TCICallCMD *)callCmd completion:(TCIFinishBlock)completion;

- (void)makeGroupCall:(NSArray *)recvIDs callCMD:(TCICallCMD *)callCmd completion:(TCIFinishBlock)completion;

// 在电话界面，监听电话过程中的命令处理, endCall的时候，会自动注销此回调
- (void)registCallHandle:(TCICallBlock)handcall;

// 收到电话命令后，根据callCmd中的参数，并进入房间（内部自动EnterRoom）
- (void)acceptCall:(TCICallCMD *)callCmd completion:(TCIAcceptCallBlock)completion listener:(id<TCILiveManagerDelegate>)delegate;

// 收到电话命令后，但还未进入间视频房间，根据callCmd中的参数
- (void)rejectCallAt:(TCICallCMD *)callCmd completion:(TCIFinishBlock)completion;

// 已在直播间内挂断电话，并退出房间
- (void)endCallCompletion:(TCIRoomBlock)completion;

/*
 * @breif 电话场景内发送其他与电话无关的控制消息
 * @param cmd : 电话场景内的命令字
 * @param c2cid : 接收者ID，可为空。不为空时，指定对单个人发送C2C消息。为空时，如果当前是群电话，则会向群里每一个人发送消息，若为C2C电话，则向对方发送消息
 * @param json : 自带的命令参数，可为空，对应填入TCICallCMD.CustomParam
 * @param succ : 消息发送成功回调
 * @param fail : 消息发送失败回调
 */
- (void)sendCallCMD:(NSInteger)cmd to:(NSString *)c2cid param:(NSString *)json succ:(TIMSucc)succ fail:(TIMFail)fail;

// 在TIMMessageListener的onNewMessage中添加该方法，进行电话消息过滤（onNewMessage可提前过滤）
- (void)filterCallMessageInNewMessages:(NSArray *)messages;
- (BOOL)filterCallMessageNewMessage:(TIMMessage *)messages;


@end


@interface TCICallManager (ProtectedMethod)

@end
