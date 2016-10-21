//
//  TCICallManager.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/12.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCICallManager.h"

#import <ImSDK/TIMMessage.h>
#import <ImSDK/TIMConversation.h>

@interface TCICallManager ()

@property (nonatomic, copy) NSString *recvID;           // 如果是C2C电话，则为对方的ID，如果为群电话，则为群ID
@property (nonatomic, copy) TCICallBlock callingBlock;

@end

@implementation TCICallManager

static TCICallManager *_sharedInstance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _sharedInstance = [[TCICallManager alloc] init];
    });
    
    return _sharedInstance;
}



- (QAVMultiParam *)createRoomParam:(TCILiveRoom *)room
{
    BOOL isHost =  [_curUserID isEqualToString:[room liveHostID]];
    QAVMultiParam *param = [[QAVMultiParam alloc] init];
    param.relationId = [room avRoomID];
    param.audioCategory = CATEGORY_MEDIA_PLAY_AND_RECORD;
    param.controlRole = [room.config roomControlRole];
    param.authBits = QAV_AUTH_BITS_DEFAULT;
    param.createRoom = isHost;
    param.videoRecvMode = VIDEO_RECV_MODE_SEMI_AUTO_RECV_CAMERA_VIDEO;
    param.enableMic = room.config.autoEnableMic;
    param.enableSpeaker = YES;
    param.enableHdAudio = YES;
    param.autoRotateVideo = YES;
    
    return param;
}
// 进入房间后，再发送呼叫命令
- (void)makeC2CCall:(NSString *)recvID callCMD:(TCICallCMD *)callCmd completion:(TCIFinishBlock)completion
{
    if ([self isLiving])
    {
        if (callCmd && ![callCmd isGroupCall])
        {
            if (recvID.length)
            {
                self.recvID = recvID;
                TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:recvID];
                
                TIMMessage *mess = [callCmd packToSendMessage];
                if (mess)
                {
                    [conv sendMessage:mess succ:^{
                        TCILDebugLog(@"回复成功[%@]", callCmd);
                        if (completion)
                        {
                            completion(YES);
                        }
                    } fail:^(int code, NSString *msg) {
                        TCILDebugLog(@"回复失败[%@] code : %d msg : %@", callCmd, code, msg);
                        if (completion)
                        {
                            completion(NO);
                        }
                    }];
                    return;
                }
                else
                {
                    TCILDebugLog(@"C2C电话命令格式有误：%@", callCmd);
                }
            }
            else
            {
                TCILDebugLog(@"接听者帐号为空");
            }
        }
        else
        {
            TCILDebugLog(@"不是C2C电话命令：%@", callCmd);
        }
    }
    else
    {
        TCILDebugLog(@"请先进入到直播间再调用此方法");
    }
    
    if (completion)
    {
        completion(NO);
    }
}

- (void)makeGroupCall:(NSArray *)recvIDs callCMD:(TCICallCMD *)callCmd completion:(TCIFinishBlock)completion
{
    if ([self isLiving])
    {
        if (callCmd && [callCmd isGroupCall])
        {
            NSString *recvID = callCmd.imGroupID;
            if (recvID.length)
            {
                self.recvID = recvID;
                TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:recvID];
                
                TIMMessage *mess = [callCmd packToSendMessage];
                if (mess)
                {
                    [conv sendMessage:mess succ:^{
                        TCILDebugLog(@"回复成功[%@]", callCmd);
                        if (completion)
                        {
                            completion(YES);
                        }
                    } fail:^(int code, NSString *msg) {
                        TCILDebugLog(@"回复失败[%@] code : %d msg : %@", callCmd, code, msg);
                        if (completion)
                        {
                            completion(NO);
                        }
                    }];
                    return;
                }
                else
                {
                    TCILDebugLog(@"C2C电话命令格式有误：%@", callCmd);
                }
            }
            else
            {
                TCILDebugLog(@"接听者帐号为空");
            }
        }
        else
        {
            TCILDebugLog(@"不是C2C电话命令：%@", callCmd);
        }
    }
    
    if (completion)
    {
        completion(NO);
    }
}

- (void)registCallHandle:(TCICallBlock)handcall
{
    self.callingBlock = handcall;
}

// 收到电话命令后，根据callCmd中的参数，创建房间，并进入
- (void)acceptCall:(TCICallCMD *)callCmd completion:(TCIAcceptCallBlock)completion listener:(id<TCILiveManagerDelegate>)delegate
{
    if (callCmd)
    {
        TCILiveRoom *room = [callCmd parseRoomInfo];
        
        if (callCmd.isGroupCall)
        {
            self.recvID = callCmd.imGroupID;
        }
        else
        {
            self.recvID = callCmd.callSponsor;
        }
        __weak typeof(self) ws = self;
        [self enterRoom:room imChatRoomBlock:nil avRoomCallBack:^(BOOL succ, NSError *err) {
            
            if (succ)
            {
                // 进入成功
                TCICallCMD *recmd = [[TCICallCMD alloc] initWithGroupCall:TCILiveCMD_Call_Connected avRoomID:callCmd.avRoomID sponsor:room.liveHostID group:callCmd.imGroupID groupType:callCmd.imGroupType type:callCmd.callType tip:@"连线成功"];
                [ws replyCallCMD:recmd onRecv:callCmd];
            }
            else
            {
                // 进入失败
                TCICallCMD *recmd = [[TCICallCMD alloc] initWithGroupCall:TCILiveCMD_Call_LineBusy avRoomID:callCmd.avRoomID sponsor:room.liveHostID group:callCmd.imGroupID groupType:callCmd.imGroupType type:callCmd.callType tip:@"连线不成功"];
                [ws replyCallCMD:recmd onRecv:callCmd];
                
            }
            
            if (completion)
            {
                completion(succ, err, succ ? room : nil);
            }
        } managerListener:delegate];
    }
    else
    {
        TCILDebugLog(@"callCmd 参数错误");
    }
}

// 收到电话命令后，根据callCmd中的参数，创建房间，并进入
- (void)rejectCallAt:(TCICallCMD *)recmd completion:(TCIFinishBlock)completion;
{
    if (recmd)
    {
        recmd.userAction = TCILiveCMD_Call_Disconnected;
        recmd.callTip = @"对方已挂断";
        
        TIMMessage *mess = [recmd packToSendMessage];
        
        if (recmd.isGroupCall)
        {
            
            NSString *recvID = [recmd imGroupID];
            TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:recvID];
            [conv sendMessage:mess succ:^{
                TCILDebugLog(@"回复成功[%@]", recmd);
                if (completion)
                {
                    completion(YES);
                }

            } fail:^(int code, NSString *msg) {
                TCILDebugLog(@"回复失败[%@] code : %d msg : %@", recmd, code, msg);
                if (completion)
                {
                    completion(NO);
                }
            }];
        }
        else
        {
            
            TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:recmd.callSponsor];
            [conv sendMessage:mess succ:^{
                TCILDebugLog(@"回复成功[%@]", recmd);
                if (completion)
                {
                    completion(YES);
                }
            } fail:^(int code, NSString *msg) {
                TCILDebugLog(@"回复失败[%@] code : %d msg : %@", recmd, code, msg);
                if (completion)
                {
                    completion(NO);
                }
            }];

        }
    }
}

// 挂断电话，并退出房间
- (void)endCallCompletion:(TCIRoomBlock)completion
{
    TCICallCMD *recmd = [TCICallCMD analysisCallCmdFrom:_room];
    
    if (recmd)
    {
        recmd.userAction = TCILiveCMD_Call_Disconnected;
        recmd.callTip = @"对方已挂断";
        
        TIMMessage *mess = [recmd packToSendMessage];
        
        if (recmd.isGroupCall)
        {
            NSString *recvID = [recmd imGroupID];
            TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:recvID];
            [conv sendMessage:mess succ:^{
                TCILDebugLog(@"回复成功[%@]", recmd);
            } fail:^(int code, NSString *msg) {
                TCILDebugLog(@"回复失败[%@] code : %d msg : %@", recmd, code, msg);
            }];
        }
        else
        {
            TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:self.recvID];
            [conv sendMessage:mess succ:^{
                TCILDebugLog(@"回复成功[%@]", recmd);
            } fail:^(int code, NSString *msg) {
                TCILDebugLog(@"回复失败[%@] code : %d msg : %@", recmd, code, msg);
            }];
            
        }
        
        [self exitRoom:completion];
    }
}

- (void)sendCallCMD:(NSInteger)cmd to:(NSString *)c2cid param:(NSString *)json succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (cmd > TCILiveCMD_Call && cmd < TCILiveCMD_Call_AllCount)
    {
        TCICallCMD *recmd = [TCICallCMD analysisCallCmdFrom:_room];
        
        if (recmd)
        {
            recmd.userAction = cmd;
            recmd.customParam = json;
            
            TIMMessage *mess = [recmd packToSendMessage];
            
            if (c2cid == nil)
            {
                if ([recmd isGroupCall])
                {
                    NSString *recvID = [recmd imGroupID];
                    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:recvID];
                    [conv sendMessage:mess succ:succ fail:fail];
                }
                else
                {
                    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:self.recvID];
                    [conv sendMessage:mess succ:succ fail:fail];
                }
            }
            else
            {
                if (c2cid.length > 0)
                {
                    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:c2cid];
                    [conv sendMessage:mess succ:succ fail:fail];
                }
                else
                {
                    TCILDebugLog(@"c2cid该命令不是电话命令，不建议在此发送");
                }
                
            }
        }
    }
    else
    {
        TCILDebugLog(@"该命令不是电话命令，不建议在此发送");
    }
}
- (void)exitRoom:(TCIRoomBlock)avBlock
{
    [super exitRoom:avBlock];
}

- (void)replyCallCMD:(TCICallCMD *)cmd onRecv:(TCICallCMD *)fromCMD
{
    TIMMessage *msg = [cmd packToSendMessage];
    if (cmd.isGroupCall)
    {
        NSString *recvID = [cmd imGroupID];
        TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:recvID];
        [conv sendMessage:msg succ:^{
            TCILDebugLog(@"回复成功[%@]", fromCMD);
        } fail:^(int code, NSString *msg) {
            TCILDebugLog(@"回复失败[%@] code : %d msg : %@", fromCMD, code, msg);
        }];
    }
    else
    {
        NSString *recvID = [fromCMD.sender identifier];
        if (recvID.length)
        {
            TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:recvID];
            [conv sendMessage:msg succ:^{
                TCILDebugLog(@"回复成功[%@]", fromCMD);
            } fail:^(int code, NSString *msg) {
                TCILDebugLog(@"回复失败[%@] code : %d msg : %@", fromCMD, code, msg);
            }];
        }
    }
}

- (void)handleCallCMD:(TCICallCMD *)cmd
{
    if (!cmd)
    {
        return;
    }
    // 说明正在通话中
    if ([self isLiving])
    {
        int oldAVroomID = [_room avRoomID];
        int newAVRoomID = [cmd avRoomID];
        if (oldAVroomID != newAVRoomID)
        {
            // 不是此房间的通话命令，直接回复占线
            
            TCICallCMD *busycmd = [[TCICallCMD alloc] initWithGroupCall:TCILiveCMD_Call_LineBusy avRoomID:[cmd avRoomID] sponsor:_room.liveHostID group:[cmd imGroupID] groupType:[cmd imGroupType] type:[cmd isVoiceCall] tip:@"对方占线，不方便接听"];
            [self replyCallCMD:busycmd onRecv:cmd];
            return;
        }
        else
        {
            // 同一房间的消息
            [self handleCallingCMD:cmd];
        }
    }
    else
    {
        if (cmd.userAction == TCILiveCMD_Call_Dialing || cmd.userAction == TCILiveCMD_Call_Invite || cmd.userAction == TCILiveCMD_Call_Disconnected)
        {
            if (self.incomingCallBlock)
            {
                self.incomingCallBlock(cmd);
            }
        }
        else
        {
            // TODO: 忽略其他消息
        }
        
    }
}

- (void)handleCallingCMD:(TCICallCMD *)cmd
{
    if (self.callingBlock)
    {
        self.callingBlock(cmd);
    }
}

- (void)filterCallMessageInNewMessages:(NSArray *)messages
{
    for (TIMMessage *msg in messages)
    {
        [self filterCallMessageNewMessage:msg];
    }
}

- (BOOL)filterCallMessageNewMessage:(TIMMessage *)msg
{
    if (msg.elemCount > 0)
    {
        TIMElem *ele = [msg getElem:0];
        if ([ele isKindOfClass:[TIMCustomElem class]])
        {
            TIMCustomElem *callelem = (TIMCustomElem *)ele;
            TCICallCMD *cmd = [TCICallCMD parseCustom:callelem inMessage:msg];
            if (cmd == nil) {
                return NO;
            }
            if (cmd && [cmd isTCAVCallCMD])
            {
                [self handleCallCMD:cmd];
            }
            return YES;
        }
        
    }
    return NO;
}


/*
 * @breif 向直播聊天室中发送文本消息
 * @param msg : 文本消息内容
 * @param succ : 发送成功回调，下同
 * @param failed : 发送失败回调，下同
 */
- (void)sendGroupTextMsg:(NSString *)msg succ:(TIMSucc)succ fail:(TIMFail)failed
{
    TCILDebugLog(@"电话场景下，不推荐使用该接口");
}


/*
 * @breif 向直播聊天室中发送群自定义消息
 * @param action : 自定义命令字段
 * @param action : 自定义消息参数字段
 */
- (void)sendGroupCustomMsg:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed
{
    TCILDebugLog(@"电话场景下，不推荐使用该接口");
}

/*
 * @breif 向单个用户发送自定义的消息
 * @param action : 单个用户的ID
 * @param action : 自定义命令字段
 * @param action : 自定义消息参数字段
 */
- (void)sendC2CCustomMsg:(NSString *)recvID action:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed
{
    TCILDebugLog(@"电话场景下，不推荐使用该接口");
}



@end


@implementation TCICallManager (ProtectedMethod)

- (void)onLogoutCompletion
{
    [super onLogoutCompletion];
    self.callingBlock = nil;
    self.incomingCallBlock = nil;
}


@end
