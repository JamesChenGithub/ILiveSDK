//
//  TCICallCMD.m
//  ILiveSDKDemos
//
//  Created by AlexiChen on 16/9/12.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCICallCMD.h"
#import "TCILiveConst.h"
#import "TCILiveRoom.h"
#import "TCICallManager.h"

#ifndef kTCAVCALL_UserAction
#define kTCAVCALL_UserAction        @"userAction"
#endif


#ifndef kTCAVCALL_ActionParam
#define kTCAVCALL_ActionParam       @"actionParam"
#endif




@implementation TCICallCMD

// 语音视频通话中用到的关键字
// int 类型
#define kTCAVCall_AVRoomID          @"AVRoomID"

// NSString, 群号可为空
#define kTCAVCall_IMGroupID         @"IMGroupID"

// 群类型
#define kTCAVCall_IMGroupType       @"IMGroupType"

// NSString, 呼叫提示
#define kTCAVCall_CallTip           @"CallTip"

// BOOL，YES:语音，NO，视频
#define kTCAVCall_CallType           @"CallType"

// Double, 呼叫时间
#define kTCAVCall_CallDate          @"CallDate"

#define kTCAVCall_CallSponsor       @"CallSponsor"

#define kTCAVCall_CustomParam       @"CustomParam"



- (NSDictionary *)packToSendDic
{
    NSMutableDictionary *post = [NSMutableDictionary dictionary];
    [post setObject:@(self.userAction) forKey:kTCAVCALL_UserAction];
    
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    
    [dic setObject:@(_avRoomID) forKey:kTCAVCall_AVRoomID];
    
    if (_callSponsor.length)
    {
        [dic setObject:_callSponsor forKey:kTCAVCall_CallSponsor];
    }
    
    if (_imGroupID.length)
    {
        [dic setObject:_imGroupID forKey:kTCAVCall_IMGroupID];
    }
    
    if (_imGroupType.length)
    {
        [dic setObject:_imGroupType forKey:kTCAVCall_IMGroupType];
    }
    
    if (_callTip.length)
    {
        [dic setObject:_callTip forKey:kTCAVCall_CallTip];
    }
    
   
    [dic setObject:@(_callType) forKey:kTCAVCall_CallType];
    
    
    [dic setObject:@([[NSDate date] timeIntervalSince1970]) forKey:kTCAVCall_CallDate];
    
    if (_customParam.length)
    {
        [dic setObject:_customParam forKey:kTCAVCall_CustomParam];
    }
    
    NSError *parseError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    
    NSString *actionString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [post setObject:actionString forKey:kTCAVCALL_ActionParam];
    
    return post;
}

- (NSData *)packToSendData
{
    
    NSDictionary *post = [self packToSendDic];
    
    if ([NSJSONSerialization isValidJSONObject:post])
    {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:post options:NSJSONWritingPrettyPrinted error:&error];
        if(error)
        {
            TCILDebugLog(@"[%@] Post Json Error: %@", [self class], post);
            return nil;
        }
        
        TCILDebugLog(@"AVIMCMD content is %@", post);
        return data;
    }
    else
    {
        TCILDebugLog(@"[%@] AVIMCMD is not valid: %@", [self class], post);
        return nil;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@", [self packToSendDic]];
}

- (TIMMessage *)packToSendMessage
{
    TIMMessage *msg = [[TIMMessage alloc] init];
    
    TIMCustomElem *elem = [[TIMCustomElem alloc] init];
    elem.data = [self packToSendData];
    
    [msg addElem:elem];
    
    
    
    return msg;
}



+ (instancetype)parseCustom:(TIMCustomElem *)elem inMessage:(TIMMessage *)msg
{
    NSData *data = elem.data;
    if (data)
    {
        
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        if (json)
        {
            if ([json isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *jd = (NSDictionary *)json;
                
                TCICallCMD *cmd = [[TCICallCMD alloc] init];
                
                cmd.sender = [msg GetSenderProfile];
                
                NSObject *actionNum = [jd objectForKey:kTCAVCALL_UserAction];
                if ([actionNum isKindOfClass:[NSNumber class]])
                {
                    cmd.userAction = [(NSNumber *)actionNum intValue];
                    
                    if (cmd.userAction >= TCILiveCMD_Call && cmd.userAction <= TCILiveCMD_Call_AllCount)
                    {
                        
                        NSObject *actionParamObj = jd[kTCAVCALL_ActionParam];
                        
                        if ([actionParamObj isKindOfClass:[NSString class]])
                        {
                            NSString *actionString = (NSString *)actionParamObj;
                            
                            NSData *jsonData = [actionString dataUsingEncoding:NSUTF8StringEncoding];
                            NSError *error = nil;
                            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
                            
                            if (error)
                            {
                                return nil;
                            }
                            
                            NSObject *avRoomIDobj = [dic objectForKey:kTCAVCall_AVRoomID];
                            NSObject *callSponsorObj = [dic objectForKey:kTCAVCall_CallSponsor];
                            NSObject *imGroupIDObj = [dic objectForKey:kTCAVCall_IMGroupID];
                            NSObject *imGroupTypeObj = [dic objectForKey:kTCAVCall_IMGroupType];
                            NSObject *callTipObj = [dic objectForKey:kTCAVCall_CallTip];
                            NSObject *callTypeObj = [dic objectForKey:kTCAVCall_CallType];
                            NSObject *dfObj = [dic objectForKey:kTCAVCall_CallType];
                            NSObject *customJsonObj = [dic objectForKey:kTCAVCall_CustomParam];
                            
                            if ([avRoomIDobj isKindOfClass:[NSNumber class]] && (!callSponsorObj || [callSponsorObj isKindOfClass:[NSString class]]) && ((!imGroupIDObj && !imGroupTypeObj) ||([imGroupIDObj isKindOfClass:[NSString class]] && [imGroupTypeObj isKindOfClass:[NSString class]])) && (!callTipObj || [callTipObj isKindOfClass:[NSString class]]) && (!callTypeObj || [callTypeObj isKindOfClass:[NSNumber class]]) && [dfObj isKindOfClass:[NSNumber class]] && (!customJsonObj || [customJsonObj isKindOfClass:[NSString class]]))
                            {
                                cmd.avRoomID = [(NSNumber *)avRoomIDobj intValue];
                                cmd.callSponsor = (NSString *)callSponsorObj;
                                cmd.imGroupID = (NSString *)imGroupIDObj;
                                cmd.imGroupType = (NSString *)imGroupTypeObj;
                                cmd.callTip = (NSString *)callTipObj;
                                cmd.callType = [(NSNumber *)callTypeObj boolValue];
                                double df = [(NSNumber *)[dic objectForKey:kTCAVCall_CallDate] doubleValue];
                                cmd.callDate = [NSDate dateWithTimeIntervalSince1970:df];
                                cmd.customParam = (NSString *)customJsonObj;
                                return cmd;
                            }
                            else
                            {
                                return nil;
                            }
                        }
                        else
                        {
                            return nil;
                        }
                        
                        
                    }
                    else
                    {
                        return nil;
                    }
                }
                else
                {
                    return nil;
                }
                
                
            }
        }
        
    }
    
    TCILDebugLog(@"自定义消息不是AVIMCMD类型");
    return nil;
    
}

+ (TCICallCMD *)analysisCallCmdFrom:(TCILiveRoom *)room
{
    if (room)
    {
        TCICallCMD *cmd = [[TCICallCMD alloc] init];
        
        cmd.callSponsor = room.liveHostID;
        cmd.avRoomID = room.avRoomID;
        cmd.imGroupID = room.chatRoomID;
        cmd.imGroupType = room.config.imChatRoomType;
        cmd.callType = room.config.isVoiceCall;
        return cmd;
    }
    return nil;
}

- (TCILiveRoom *)parseRoomInfo
{
    if (self.sender)
    {
        NSString *curid = [[TCICallManager sharedInstance] curUserID];
       
        if(self.imGroupID.length > 0)
        {
            TCILiveRoom *room = [[TCILiveRoom alloc] initGroupCallWith:self.avRoomID liveHost:self.callSponsor groupID:self.imGroupID groupType:self.imGroupType curUserID:curid callType:self.callType];
            return room;
        }
        else
        {
            TCILiveRoom *room = [[TCILiveRoom alloc] initC2CCallWith:self.avRoomID liveHost:self.callSponsor curUserID:curid callType:self.callType];
            return room;
        }
    }
    return nil;
}

- (instancetype)initWithC2CCall:(NSInteger)command avRoomID:(int)roomid sponsor:(NSString *)sponsor type:(BOOL)isVoiceCall tip:(NSString *)tip
{
    return [self initWithGroupCall:command avRoomID:roomid sponsor:sponsor group:nil groupType:nil type:isVoiceCall tip:tip];
}

- (instancetype)initWithGroupCall:(NSInteger)command avRoomID:(int)roomid sponsor:(NSString *)sponsor group:(NSString *)gid groupType:(NSString *)groupTpe type:(BOOL)isVoiceCall tip:(NSString *)tip
{
    if (roomid < 0)
    {
        TCILDebugLog(@"房间号参数不合法");
        return nil;
    }
    
    if (!((gid.length > 0 && groupTpe.length > 0) || (groupTpe.length == 0 && groupTpe.length == 0)))
    {
        TCILDebugLog(@"群号参数不合法");
        return nil;
    }
    
    if (sponsor.length == 0)
    {
        TCILDebugLog(@"群号参数不合法");
        return nil;
    }
    
    
    if (self = [super init])
    {
        self.userAction = command;
        self.avRoomID = roomid;
        self.callSponsor = sponsor;
        self.imGroupID = gid;
        self.imGroupType = groupTpe;
        self.callType = isVoiceCall;
        self.callTip = tip;
    }
    return self;
}

- (BOOL)isVoiceCall
{
    return self.callType;
}

- (BOOL)isGroupCall
{
    return self.imGroupID.length > 0;
}

- (BOOL)isChatGroup
{
    return [self.imGroupType isEqualToString:@"Private"];
}

- (NSString *)callGroupType
{
    return self.imGroupType;
}

- (BOOL)isTCAVCallCMD
{
    return self.userAction > TCILiveCMD_Call && self.userAction < TCILiveCMD_Call_AllCount;
}

@end
