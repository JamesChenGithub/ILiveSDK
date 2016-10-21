//
//  TCICallCMD.h
//  ILiveSDKDemos
//
//  Created by AlexiChen on 16/9/12.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveMsg.h"


@class TCILiveRoom;
// 电话中的消息
@interface TCICallCMD : TCILiveCMD

@property (nonatomic, assign) int avRoomID;                     // 房间号，必填（必须>0）
@property (nonatomic, copy) NSString *callSponsor;              // 电话发起者，创建电话的人（必填）
@property (nonatomic, copy) NSString *imGroupID;                // 群ID，与imGroupType同时为空时，表示C2C，同时不为空时，表示群组电话
@property (nonatomic, copy) NSString *imGroupType;              // 群类型，与imGroupID同时为空，表示C2C，同时不为空时，表示群组电话
@property (nonatomic, copy) NSString *callTip;                  // 呼叫提示，可为空
@property (nonatomic, assign) BOOL callType;                    // 呼叫类型 : YES:音频通话，NO：视频通话，（必填）
@property (nonatomic, strong) NSDate *callDate;                 // 呼叫时间：必传字段，外部不用处理，收到消息的时候才用，内部自动解析（收到命令时）与补齐（发送命令时自动添加）
@property (nonatomic, copy) NSString *customParam;              // 自定义参数字段，可为空

// 创建通话自定义命令
+ (instancetype)parseCustom:(TIMCustomElem *)elem inMessage:(TIMMessage *)msg;

// 主要用于本地解析,不会解析出userAction, 以及c2csender/groupSender, callTip, callDate
+ (TCICallCMD *)analysisCallCmdFrom:(TCILiveRoom *)room;
- (instancetype)initWithC2CCall:(NSInteger)command avRoomID:(int)roomid sponsor:(NSString *)sponsor type:(BOOL)isVoiceCall tip:(NSString *)tip;
- (instancetype)initWithGroupCall:(NSInteger)command avRoomID:(int)roomid sponsor:(NSString *)sponsor group:(NSString *)gid groupType:(NSString *)groupTpe type:(BOOL)isVoiceCall tip:(NSString *)tip;

- (BOOL)isVoiceCall;
- (BOOL)isTCAVCallCMD;
- (BOOL)isGroupCall;

// 是否是讨论组，讨论组才可以邀人进入
// 其他类型不支持邀请加入
- (BOOL)isChatGroup;
- (NSString *)callGroupType;

- (TIMMessage *)packToSendMessage;

// TCICallCMD为接收到的消息才行
- (TCILiveRoom *)parseRoomInfo;


@end
