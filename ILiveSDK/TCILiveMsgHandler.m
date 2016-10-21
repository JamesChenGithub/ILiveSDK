//
//  TCILiveMsgHandler.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/27.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveMsgHandler.h"

#import "TCILAVIMRunloop.h"

#import "TCILAVIMCache.h"

#import "TCICallCMD.h"

#import "TCILiveConst.h"


@interface TCILiveMsgHandler ()
{
@protected
    NSMutableDictionary *_cacheMapDictionary;
}
@end

@implementation TCILiveMsgHandler

- (void)dealloc
{
    TCILDebugLog(@"%@ [%@] Release", self, [_liveRoom chatRoomID]);
}


- (instancetype)initWith:(TCILiveRoom *)imRoom
{
    if (self = [super init])
    {
        NSString *cid = [imRoom chatRoomID];
        TCILDebugLog(@"-----IMSDK监听群消息>>>>>群号[%@]", cid);
        _liveRoom = imRoom;
        
        // 为了不影响视频，runloop线程优先级较低，用户可根据自身需要去调整
        _sharedRunLoopRef = [TCILAVIMRunloop sharedAVIMRunloop];
        
        _cacheMapDictionary = [NSMutableDictionary dictionary];
        
        [self addCacheFor:TCILiveCMD_Text capacity:10];
        [self addCacheFor:TCILiveCMD_Praise capacity:5];
        
        self.isCacheMode = YES;
        _isPureMode = NO;
        _msgCacheLock = OS_SPINLOCK_INIT;
        
        _msgClass = [TCILiveMsg class];
    }
    return self;
}

- (void)filterCurrentLiveMessageInNewMessages:(NSArray *)messages
{
    [self performSelector:@selector(onHandleNewMessages:) onThread:_sharedRunLoopRef.thread withObject:messages waitUntilDone:NO];
}

- (void)filterCurrentLiveMessageInNewMessage:(TIMMessage *)messages
{
    [self performSelector:@selector(onHandleNewMessage:) onThread:_sharedRunLoopRef.thread withObject:messages waitUntilDone:NO];
}

- (void)registerMsgClass:(Class)liveMsgClass
{
    if ([liveMsgClass isSubclassOfClass:[TCILiveMsg class]])
    {
        _msgClass = liveMsgClass;
    }
    else
    {
        TCILDebugLog(@"%@ 必须是TCILiveMsg的子类型", liveMsgClass);
    }
}

- (void)refreshMsgToUI
{
    if (!_isPureMode)
    {    
        NSDictionary *dic = [self getMsgCache];
        
        if ([_roomIMListner respondsToSelector:@selector(onIMHandler:timedRefresh:)])
        {
            [_roomIMListner onIMHandler:self timedRefresh:dic];
        }
    }
}

- (void)onRecvC2C:(TIMMessage *)msg
{
    TIMUserProfile *profile = [msg GetSenderProfile];
    // 未处理C2C文本消息
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        //        if([elem isKindOfClass:[TIMTextElem class]])
        //        {
        //            //消息
        //            TIMTextElem *textElem = (TIMTextElem *)elem;
        //            NSString *msgText = textElem.text;
        //            [self onRecvC2CSender:profile textMsg:msgText];
        //        }
        //        else
        // 只处理C2C自定义消息，不处理其他类型聊天消息
        if([elem isKindOfClass:[TIMCustomElem class]])
        {
            // 自定义消息
            [self onRecvC2CSender:profile customMsg:(TIMCustomElem *)elem inMessage:msg];
        }
    }
}

- (TCILiveCMD *)cacheRecvC2CSender:(TIMUserProfile *)sender customMsg:(TIMCustomElem *)elem inMessage:(TIMMessage *)message
{
    TCILiveCMD *cmd = [TCILiveCMD parseCustom:elem inMessage:message];
    
    if ([_roomIMListner respondsToSelector:@selector(onIMHandler:preRenderLiveCMD:)])
    {
        [_roomIMListner onIMHandler:self preRenderLiveCMD:cmd];
    }
    
    return cmd;
}


- (void)onRecvC2CSender:(TIMUserProfile *)sender customMsg:(TIMCustomElem *)elem inMessage:(TIMMessage *)message
{
    TCILiveCMD *cachedMsg = [self cacheRecvC2CSender:sender customMsg:elem inMessage:message];
    [self enCMDToCache:cachedMsg noCache:^(TCILiveCMD *cmd) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Demo中此类不处理C2C消息
            if (cachedMsg)
            {
                NSInteger type = [cachedMsg msgType];
                if (type > TCILiveCMD_Multi && type < TCILiveCMD_Multi_Custom)
                {
                    TCILDebugLog(@"收到消息：%@", cachedMsg);
                    // 收到内部的自定义多人互动消
                    if ([_roomIMListner respondsToSelector:@selector(onIMHandler:recvCustomC2CMultiMsg:)])
                    {
                        [_roomIMListner onIMHandler:self recvCustomC2CMultiMsg:cachedMsg];
                    }
                }
                else
                {
                    TCILDebugLog(@"收到消息：%@", cachedMsg);
                    [_roomIMListner onIMHandler:self recvCustomC2C:cachedMsg];
                }
            }
        });
    }];
}


- (TCILiveMsg *)cacheRecvGroupSender:(TIMUserProfile *)sender textMsg:(NSString *)msg
{
    TCILiveMsg *amsg = [[_msgClass alloc] initWith:sender message:msg];
    
    if ([_roomIMListner respondsToSelector:@selector(onIMHandler:preRenderLiveMsg:)])
    {
        [_roomIMListner onIMHandler:self preRenderLiveMsg:amsg];
    }
    
    return amsg;
}


// 收到群自定义消息处理
- (void)onRecvGroupSender:(TIMUserProfile *)sender textMsg:(NSString *)msg
{
    TCILiveMsg *cachedMsg = [self cacheRecvGroupSender:sender textMsg:msg];
    [self enMsgToCache:cachedMsg noCache:^(TCILiveMsg *msg){
        if (msg)
        {
            [self performSelectorOnMainThread:@selector(onRecvGroupMsgInMainThread:) withObject:msg waitUntilDone:YES];
        }
    }];
}

- (void)onRecvGroupMsgInMainThread:(TCILiveMsg *)cachedMsg
{
    [_roomIMListner onIMHandler:self recvGroupMsg:cachedMsg];
}


- (TCILiveCMD *)cacheRecvGroupSender:(TIMUserProfile *)sender customMsg:(TIMCustomElem *)elem inMessage:(TIMMessage *)msg
{
    TCILiveCMD *cmd = [TCILiveCMD parseCustom:elem inMessage:msg];
    if ([_roomIMListner respondsToSelector:@selector(onIMHandler:preRenderLiveCMD:)])
    {
        [_roomIMListner onIMHandler:self preRenderLiveCMD:cmd];
    }
    
    return cmd;
}


- (TCILiveMsg *)onRecvSender:(TIMUserProfile *)sender tipMessage:(NSString *)msg
{
    TCILiveMsg *amsg = [[_msgClass alloc] initWith:sender message:msg];
    if ([_roomIMListner respondsToSelector:@selector(onIMHandler:preRenderLiveMsg:)])
    {
        [_roomIMListner onIMHandler:self preRenderLiveMsg:amsg];
    }
    return amsg;
}


- (void)enTipToCacne:(NSString *)tip fromSender:(TIMUserProfile *)sender
{
    __weak typeof(_roomIMListner) wrl = _roomIMListner;
    __weak typeof(self) ws = self;
    TCILiveMsg *enterMsg = [self onRecvSender:sender tipMessage:tip];
    [self enMsgToCache:enterMsg noCache:^(TCILiveMsg *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TCILDebugLog(@"收到消息：%@", msg);
            if (msg && [wrl respondsToSelector:@selector(onIMHandler:recvGroupMsg:)])
            {
                [wrl onIMHandler:ws recvGroupMsg:msg];
            }
        });
    }];
}

// 收到群自定义消息处理
- (void)onRecvGroupSender:(TIMUserProfile *)sender customMsg:(TIMCustomElem *)elem inMessage:(TIMMessage *)msg
{
    TCILiveCMD *cachedMsg = [self cacheRecvGroupSender:sender customMsg:elem inMessage:msg];
    if (cachedMsg)
    {
        NSInteger type = [cachedMsg msgType];
        BOOL hasHandle = YES;
        if (type > 0 && sender)
        {
            switch (type)
            {
                case TCILiveCMD_EnterLive:
                {
                    [self enTipToCacne:@"进来了" fromSender:sender];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_roomIMListner onIMHandler:self joinGroup:@[sender]];
                    });
                    
                }
                    break;
                case TCILiveCMD_ExitLive:
                {
                    [self enTipToCacne:@"离开了" fromSender:sender];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[sender identifier] isEqualToString:[_liveRoom liveHostID]])
                        {
                            TCILDebugLog(@"主播主动退群");
                            // 主播主动退群，结束直播
                            [_roomIMListner onIMHandler:self deleteGroup:sender];
                        }
                        else
                        {
                            [_roomIMListner onIMHandler:self exitGroup:@[sender]];
                        }
                    });
                }
                    break;
                case TCILiveCMD_Host_Leave:
                {
                    [self enTipToCacne:@"暂时离开了" fromSender:sender];
                    hasHandle = NO;
                }
                    break;
                case TCILiveCMD_Host_Back:
                {
                    [self enTipToCacne:@"回来了" fromSender:sender];
                    hasHandle = NO;
                }
                    break;
                case TCILiveCMD_Multi_CancelInteract:
                {
                    [self enCMDToCache:cachedMsg noCache:^(TCILiveCMD *msg){
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([_roomIMListner respondsToSelector:@selector(onIMHandler:recvCustomGroupMultiMsg:)])
                            {
                                [_roomIMListner onIMHandler:self recvCustomGroupMultiMsg:msg];
                            }
                        });
                    }];
                }
                    break;
                default:
                    hasHandle = NO;
                    break;
            }
        }
        
        if (!hasHandle)
        {
            __weak typeof(_roomIMListner) wrl = _roomIMListner;
            __weak typeof(self) ws = self;
            [self enCMDToCache:cachedMsg noCache:^(TCILiveCMD *msg){
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([wrl respondsToSelector:@selector(onIMHandler:recvCustomGroup:)])
                    {
                        [wrl onIMHandler:ws recvCustomGroup:msg];
                    }
                });
            }];
        }
    }
}



- (void)onRecvGroup:(TIMMessage *)msg
{
    TIMUserProfile *info = [msg GetSenderProfile];
    
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        if([elem isKindOfClass:[TIMTextElem class]])
        {
            //消息
            TIMTextElem *textElem = (TIMTextElem *)elem;
            NSString *msgText = textElem.text;
            [self onRecvGroupSender:info textMsg:msgText];
        }
        else if([elem isKindOfClass:[TIMCustomElem class]])
        {
            // 自定义消息
            [self onRecvGroupSender:info customMsg:(TIMCustomElem *)elem inMessage:msg];
        }
    }
}

- (void)onRecvSystem:(TIMMessage *)msg
{
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        
        if ([elem isKindOfClass:[TIMGroupSystemElem class]])
        {
            TIMGroupSystemElem *item = (TIMGroupSystemElem *)elem;
            
            if ([item.group isEqualToString:[_liveRoom chatRoomID]])
            {
                // 只处理群解散消息
                if (item.type == TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE)
                {
                    // 有人退群
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 系统退群，后台自动解散
                        if (_roomIMListner && [_roomIMListner respondsToSelector:@selector(onIMHandler:deleteGroup:)])
                        {
                            [_roomIMListner onIMHandler:self deleteGroup:item.opUserInfo];
                        }
                    });
                }
            }
        }
    }
    
}


- (void)onHandleNewMessage:(TIMMessage *)msg
{
    TIMConversationType conType = msg.getConversation.getType;
    switch (conType)
    {
        case TIM_C2C:
        {
            [self onRecvC2C:msg];
        }
            break;
        case TIM_GROUP:
        {
            if([[msg.getConversation getReceiver] isEqualToString:[_liveRoom chatRoomID]])
            {
                // 处理群聊天消息
                // 只接受来自该聊天室的消息
                [self onRecvGroup:msg];
            }
        }
            break;
        case TIM_SYSTEM:
        {
            [self onRecvSystem:msg];
        }
            break;
        default:
            break;
    }
    
}


- (void)onHandleNewMessages:(NSArray *)msgs
{
    for(TIMMessage *msg in msgs)
    {
        [self onHandleNewMessage:msg];
    }
}

- (void)setIsCacheMode:(BOOL)isCacheMode
{
    _isCacheMode = isCacheMode;
    if (_isCacheMode)
    {
        [self createMsgCache];
    }
    else
    {
        [self releaseMsgCache];
    }
}

// capacity不宜过大
- (void)addCacheFor:(NSInteger)cmdindex capacity:(NSUInteger)capacity
{
    [_cacheMapDictionary setObject:@(capacity) forKey:@(cmdindex)];
}

- (void)removeCacheFor:(NSInteger)cmdIndex
{
    [_cacheMapDictionary removeObjectForKey:@(cmdIndex)];
}

- (void)createMsgCache
{
    _msgCache = [NSMutableDictionary dictionary];
    for (NSNumber *key in _cacheMapDictionary)
    {
        NSNumber *num = (NSNumber *)_cacheMapDictionary[key];
        [_msgCache setObject:[[TCILAVIMCache alloc] initWith:num.integerValue] forKey:key];
        
    }
}

- (void)resetMsgCache
{
    [self createMsgCache];
}
- (void)releaseMsgCache
{
    _msgCache = nil;
}

- (void)enMsgToCache:(TCILiveMsg *)msg noCache:(TCILAVIMMsgCacheBlock)noCacheblock
{
    if (!_isCacheMode)
    {
        if (noCacheblock)
        {
            noCacheblock(msg);
        }
    }
    else
    {
        if (msg)
        {
            OSSpinLockLock(&_msgCacheLock);
            TCILAVIMCache *cache = [_msgCache objectForKey:@([msg msgType])];
            if (cache)
            {
                [cache enCache:msg];
            }
            else
            {
                if (noCacheblock)
                {
                    noCacheblock(msg);
                }
            }
            OSSpinLockUnlock(&_msgCacheLock);
        }
    }
}

- (void)enCMDToCache:(TCILiveCMD *)cmd noCache:(TCILAVIMCMDCacheBlock)noCacheblock
{
    if (!_isCacheMode)
    {
        if (noCacheblock)
        {
            noCacheblock(cmd);
        }
    }
    else
    {
        if (cmd)
        {
            OSSpinLockLock(&_msgCacheLock);
            TCILAVIMCache *cache = [_msgCache objectForKey:@([cmd msgType])];
            if (cache)
            {
                [cache enCache:cmd];
            }
            else
            {
                if (noCacheblock)
                {
                    noCacheblock(cmd);
                }
            }
            OSSpinLockUnlock(&_msgCacheLock);
        }
    }
}

- (NSDictionary *)getMsgCache
{
    OSSpinLockLock(&_msgCacheLock);
    NSDictionary *dic = _msgCache;
    
    [self resetMsgCache];
    OSSpinLockUnlock(&_msgCacheLock);
    
    return dic;
}
@end
