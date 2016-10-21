//
//  TCILiveMsgHandler.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/27.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/ImSDK.h>
#import <libkern/OSAtomic.h>

#import "TCILiveRoom.h"
#import "TCILAVIMRunloop.h"

@class TCILiveMsg;

@class TCILiveMsgHandler;

@class TCILiveCMD;

@protocol TCILiveMsgHandlerListener <NSObject>


@required

// 收到群聊天消息: (主要是文本类型)
- (void)onIMHandler:(TCILiveMsgHandler *)handler recvGroupMsg:(TCILiveMsg *)msg;

// 收到自定义C2C消息
// 用户自行解析
- (void)onIMHandler:(TCILiveMsgHandler *)handler recvCustomC2C:(TCILiveCMD *)msg;

// 收到自定义的Group消息
// 用户自行解析
- (void)onIMHandler:(TCILiveMsgHandler *)handler recvCustomGroup:(TCILiveCMD *)msg;

// 群主解散群消息，或后台自动解散
- (void)onIMHandler:(TCILiveMsgHandler *)handler deleteGroup:(TIMUserProfile *)sender;

// 有新用户进入
// senders是TIMUserProfile类型
- (void)onIMHandler:(TCILiveMsgHandler *)handler joinGroup:(NSArray *)senders;

// 有用户退出
// senders是TIMUserProfile类型
- (void)onIMHandler:(TCILiveMsgHandler *)handler exitGroup:(NSArray *)senders;


@required

// 收到自定义的TIMAdapter内的多人互动消息
- (void)onIMHandler:(TCILiveMsgHandler *)receiver recvCustomC2CMultiMsg:(TCILiveCMD *)msg;

- (void)onIMHandler:(TCILiveMsgHandler *)receiver recvCustomGroupMultiMsg:(TCILiveCMD *)msg;

@required

// 在子线程中预先计算消息渲染
- (void)onIMHandler:(TCILiveMsgHandler *)handler preRenderLiveMsg:(TCILiveMsg *)msg;

- (void)onIMHandler:(TCILiveMsgHandler *)handler preRenderLiveCMD:(TCILiveCMD *)msg;


@required
// 定时刷新消息回调
- (void)onIMHandler:(TCILiveMsgHandler *)handler timedRefresh:(NSDictionary *)cacheDic;


@end

typedef void (^TCILAVIMMsgCacheBlock)(TCILiveMsg *msg);
typedef void (^TCILAVIMCMDCacheBlock)(TCILiveCMD *msg);


// 只作消息接收解析，缓存
@interface TCILiveMsgHandler : NSObject
{
@protected
    TCILiveRoom                             *_liveRoom;
@protected
    __weak TCILAVIMRunloop                  *_sharedRunLoopRef;         // 消息处理线程的引用
    
    
@protected
    BOOL                                    _isCacheMode;               // 是否是缓存模式，详见修改日志时间: 20160525
    NSMutableDictionary                     *_msgCache;                 // 以key为id<AVIMMsgAble> msgtype的, value为TCILAVIMCache，在runloop线程中执行
    OSSpinLock                              _msgCacheLock;
    
@protected
    __weak id<TCILiveMsgHandlerListener>    _roomIMListner;
    
@protected
    BOOL                                    _isPureMode;                            // 纯净模工下，收到消息后，不作渲染计算
    
    Class                                   _msgClass;                              // 消息类型
}

@property (nonatomic, weak) id<TCILiveMsgHandlerListener> roomIMListner;

// 是否使用纯净模式，默认为NO
@property (nonatomic, assign) BOOL isPureMode;

// 默认使用缓存模式：默认为YES
// 默认缓存  TCILiveCMD_Text (文本消息，默认10条)，TCILiveCMD_Praise (点赞消息，默认5个赞)

@property (nonatomic, assign) BOOL isCacheMode;     // 是否是缓存模式


- (instancetype)initWith:(TCILiveRoom *)imRoom;

- (void)filterCurrentLiveMessageInNewMessages:(NSArray *)messages;

- (void)filterCurrentLiveMessageInNewMessage:(TIMMessage *)messages;

- (void)registerMsgClass:(Class)liveMsgClass;

// 主线程中调用的
- (void)refreshMsgToUI;


- (void)onRecvGroupSender:(TIMUserProfile *)sender textMsg:(NSString *)msg;


// capacity不宜过大
- (void)addCacheFor:(NSInteger)cmdindex capacity:(NSUInteger)capacity;
- (void)removeCacheFor:(NSInteger)cmdIndex;

// 用户通过设置此方法，监听要处理的消息类型
- (void)createMsgCache;

- (void)resetMsgCache;
- (void)releaseMsgCache;

// 如果cache不成功，会继续上报
- (void)enMsgToCache:(TCILiveMsg *)msg noCache:(TCILAVIMMsgCacheBlock)noCacheblock;
- (void)enCMDToCache:(TCILiveCMD *)cmd noCache:(TCILAVIMCMDCacheBlock)noCacheblock;


- (NSDictionary *)getMsgCache;

@end
