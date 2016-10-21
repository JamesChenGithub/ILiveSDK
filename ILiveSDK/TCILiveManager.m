//
//  TCILiveManager.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveManager.h"

#import <QALSDK/QalSDKProxy.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>

#import "AVGLBaseView.h"
#import "AVGLRenderView.h"
#import "TCAVFrameDispatcher.h"

#import "TCAVSharedContext.h"
#import "AVGLCustomRenderView.h"
#import "TCIMemoItem.h"
#import "TCILiveMsgHandler.h"
#import "TCICallCMD.h"






@interface TCILiveManager () <QAVLocalVideoDelegate, QAVRemoteVideoDelegate, QAVScreenVideoDelegate, QAVRoomDelegate, QAVChangeDelegate, QAVChangeRoleDelegate>
{
    AVGLBaseView        *_avglView;
    TCAVFrameDispatcher *_frameDispatcher;
    
    NSMutableArray      *_avStatusList;                             //  记录当前直播中麦的信息
    
    BOOL _isLiving;
    
    BOOL _hasEnableCameraBeforeEnterBackground;
    BOOL _hasEnableMicBeforeEnterBackground;
    
    
    // 用于音频退出直播时还原现场
    NSString                        *_audioSesstionCategory;        // 进入房间时的音频类别
    NSString                        *_audioSesstionMode;            // 进入房间时的音频模式
    AVAudioSessionCategoryOptions   _audioSesstionCategoryOptions;  // 进入房间时的音频类别选项
    
    CTCallCenter                    *_callCenter;                   // 电话监听
    BOOL                            _isHandleCall;                  // 处理电话
    
    
    TCILiveMsgHandler               *_msgHandler;                   // 房间内接收消息的处理者
    NSTimer                         *_autoRefreshMsgTimer;          // 定时刷新消息，默认1s刷新一次消息缓存
    CGFloat                         _msgRefershInterval;            // 消息刷新间隔
    BOOL                            _canRenderNow;                  // 是否可以刷新消息
    
    // 正在切换AuthAndRole
    BOOL      _isSwitchAuthAndRole;
    NSString  *_switchToRole;
    unsigned long long _switchToAuth;
    
@protected
    NSMutableDictionary     *_pushMap;
    NSMutableDictionary     *_recordmMap;
}

@property (nonatomic, copy) NSString *curUserID;
@property (nonatomic, strong) QAVContext *avContext;

@property (nonatomic, strong) AVGLBaseView *avglView;
@property (nonatomic, strong) TCAVFrameDispatcher *frameDispatcher;

@property (nonatomic, copy) TCIRoomBlock enterRoomBlock;
@property (nonatomic, copy) TCIRoomBlock exitRoomBlock;

//@property (nonatomic, assign) BOOL isConnected;
//@property (nonatomic, assign) EQALNetworkType networkType;


@property (nonatomic, assign) BOOL hasCheckCameraAuth;
@property (nonatomic, assign) BOOL hasCameraAuth;
@property (nonatomic, assign) BOOL hasCheckMicPermission;
@property (nonatomic, assign) BOOL hasMicPermission;

@property (nonatomic, strong) NSMutableDictionary *pushMap;
@property (nonatomic, strong) NSMutableDictionary *recordMap;

@property (nonatomic, copy) TCIFinishBlock switchAutoRoleCompletion;
@end

@implementation TCILiveManager

static TCILiveManager *_sharedInstance = nil;

+ (void)configWithAppID:(int)sdkAppId accountType:(NSString *)accountType willInit:(TCIVoidBlock)willDo initCompleted:(TCIVoidBlock)completion
{
    if (willDo)
    {
        willDo();
    }
    
    TIMManager *manager = [TIMManager sharedInstance];
    [manager initSdk:sdkAppId accountType:accountType];
    
    if (completion)
    {
        completion();
    }
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _sharedInstance = [[TCILiveManager alloc] init];
    });
    
    return _sharedInstance;
}

- (BOOL)isHostLive
{
    return _room && [[_room liveHostID] isEqualToString:_curUserID];
}

- (BOOL)isLiving
{
    return _isLiving;
}

- (NSInteger)maxVideoCount
{
    return 4;
}

- (NSInteger)hasVideoCount
{
    NSInteger count = 0;
    for (TCIMemoItem *item in _avStatusList)
    {
        count += item.isCameraVideo;
        count += item.isScreenVideo;
    }
    
    return count;
}

- (NSInteger)maxMicCount
{
    return 6;
}

- (NSInteger)hasAudioCount
{
    NSInteger count = 0;
    for (TCIMemoItem *item in _avStatusList)
    {
        count += item.isAudio;
    }
    
    return count;
}

#define kEachKickErrorCode 6208
- (void)login:(TIMLoginParam *)param loginFail:(TIMFail)fail offlineKicked:(void (^)(TIMLoginParam *param, TCIRoomBlock completion, TIMFail fail))offline startContextCompletion:(TCIRoomBlock)completion
{
    if (!param)
    {
        if (fail)
        {
            fail(-1, @"登录参数不能为空");
        }
        return;
    }
    
    __weak typeof(self) ws = self;
    [[TIMManager sharedInstance] login:param succ:^{
        TCILDebugLog(@"登录成功:%@ tinyid:%llu sig:%@", param.identifier, [[IMSdkInt sharedInstance] getTinyId], param.userSig);
        [ws startContextWith:param completion:completion];
    } fail:^(int code, NSString *msg) {
        
        TCILDebugLog(@"TIMLogin Failed: code=%d err=%@", code, msg);
        if (code == kEachKickErrorCode)
        {
            //互踢重联，重新再登录一次
            if (offline)
            {
                offline(param, completion, fail);
            }
        }
        else
        {
            if (fail)
            {
                fail(code, msg);
            }
        }
    }];
}

- (void)startContextWith:(TIMLoginParam *)param completion:(TCIRoomBlock)completion
{
    self.curUserID = param.identifier;
    [TCAVSharedContext configContextWith:param completion:completion];
}

- (void)logout:(TIMLoginSucc)succ fail:(TIMFail)fail
{
    __weak typeof(self) ws = self;
    
    if (_isLiving)
    {
        [self exitRoom:^(BOOL suc, NSError *err) {
            [ws logout:succ fail:fail];
        }];
    }
    else
    {
        [[TIMManager sharedInstance] logout:^{
            [ws onLogoutCompletion];
            if (succ)
            {
                succ();
            }
        } fail:^(int code, NSString *err) {
            [ws onLogoutCompletion];
            if (fail)
            {
                fail(code, err);
            }
        }];
    }
    
    
}



//==================================================================

- (void)enterRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)imblock avRoomCallBack:(TCIRoomBlock)avblock managerListener:(id<TCILiveManagerDelegate>)managerDelegate
{
    [self enterRoom:room imChatRoomBlock:imblock avRoomCallBack:avblock avListener:nil managerListener:managerDelegate];
}
- (void)enterRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)imblock avListener:(id<QAVRoomDelegate>)delegate managerListener:(id<TCILiveManagerDelegate>)managerDelegate
{
    [self enterRoom:room imChatRoomBlock:imblock avRoomCallBack:nil avListener:delegate managerListener:managerDelegate];
}

- (void)addAudioInterruptListener
{
    NSError *error = nil;
    AVAudioSession *aSession = [AVAudioSession sharedInstance];
    
    _audioSesstionCategory = [aSession category];
    _audioSesstionMode = [aSession mode];
    _audioSesstionCategoryOptions = [aSession categoryOptions];
    
    [aSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
    [aSession setMode:AVAudioSessionModeDefault error:&error];
    [aSession setActive:YES error: &error];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioInterruption:)  name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillTeminal:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)addForeBackgroundListener
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)removeForeBackgroundListener
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)onAudioInterruption:(NSNotification *)notification
{
    //DDLogInfo(@"audioInterruption%@",notification.userInfo);
    NSDictionary *interuptionDict = notification.userInfo;
    NSNumber* interuptionType = [interuptionDict valueForKey:AVAudioSessionInterruptionTypeKey];
    if(interuptionType.intValue == AVAudioSessionInterruptionTypeBegan)
    {
        TCILDebugLog(@"初中断");
    }
    else if (interuptionType.intValue == AVAudioSessionInterruptionTypeEnded)
    {
        // siri输入
        [[AVAudioSession sharedInstance] setActive:YES error: nil];
        
    }
}

- (BOOL)isOtherAudioPlaying
{
    UInt32 otherAudioIsPlaying;
    UInt32 propertySize = sizeof (otherAudioIsPlaying);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AudioSessionGetProperty(kAudioSessionProperty_OtherAudioIsPlaying, &propertySize, &otherAudioIsPlaying);
#pragma clang diagnostic pop
    return otherAudioIsPlaying;
}


- (void)onAppBecomeActive:(NSNotification *)notification
{
    if (![self isOtherAudioPlaying])
    {
        [[AVAudioSession sharedInstance] setActive:YES error: nil];
    }
}

- (void)onAppWillTeminal:(NSNotification*)notification
{
    [self exitRoom:nil];
}

- (void)removeAudioInterruptListener
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    
    // [[NSNotificationCenter defaultCenter] removeObserver:self];
    AVAudioSession *aSession = [AVAudioSession sharedInstance];
    [aSession setCategory:_audioSesstionCategory withOptions:_audioSesstionCategoryOptions error:nil];
    [aSession setMode:_audioSesstionMode error:nil];
}
// 进入直播间
- (void)enterRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)block avRoomCallBack:(TCIRoomBlock)avblock avListener:(id<QAVRoomDelegate>)delegate managerListener:(id<TCILiveManagerDelegate>)managerDelegate
{
    if (!room || room.avRoomID <= 0)
    {
        TCILDebugLog(@"_room不能为空");
        if (avblock)
        {
            NSError *error = [NSError errorWithDomain:@"room不能为空" code:QAV_ERR_INVALID_ARGUMENT userInfo:nil];
            avblock(NO, error);
        }
        
        if ([delegate respondsToSelector:@selector(OnEnterRoomComplete:)])
        {
            [delegate OnEnterRoomComplete:QAV_ERR_INVALID_ARGUMENT];
        }
        return;
    }
    
    _isLiving = YES;
    _isHandleCall = NO;
    
    _delegate = managerDelegate;
    _room = room;
    
    if (!_avStatusList)
    {
        _avStatusList = [NSMutableArray array];
    }
    
    
    if (delegate == nil || delegate == self)
    {
        self.enterRoomBlock = avblock;
        delegate = self;
    }
    
    if (_room.config.autoMonitorAudioInterupt)
    {
        [self addAudioInterruptListener];
    }
    
    
    if (_room.config.isSupportIM)
    {
        // 创建IM
        [self enterIMRoom:room imChatRoomBlock:block avListener:delegate];
    }
    else
    {
        [self enterAVLiveRoom:room avListener:delegate];
    }
}

- (void)enterIMRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)block avListener:(id<QAVRoomDelegate>)delegate
{
    BOOL isHost =  [self isHostLive];
    __weak typeof(self) ws = self;
    if (isHost)
    {
        NSString *roomid = nil;
        if (room.config.isFixAVRoomIDAsChatRoomID)
        {
            roomid = [NSString stringWithFormat:@"%d", room.avRoomID];
        }
        
        TCILDebugLog(@"----->>>>>主播开始创建直播聊天室:%@", roomid);
        [[TIMGroupManager sharedInstance] CreateGroup:room.config.imChatRoomType members:nil groupName:roomid groupId:room.config.isFixAVRoomIDAsChatRoomID ? roomid : nil succ:^(NSString *groupId) {
            TCILDebugLog(@"----->>>>>主播开始创建直播聊天室成功");
            [room setChatRoomID:groupId];
            if (block)
            {
                block(YES, groupId, nil);
            }
            
            [ws enterAVLiveRoom:room avListener:delegate];
            
        } fail:^(int code, NSString *error) {
            // 返回10025，group id has be used，
            // 10025无法区分当前是操作者是否是原群的操作者（目前业务逻辑不存在拿别人的uid创建聊天室逻辑），
            // 为简化逻辑，暂定创建聊天室时返回10025，就直接等同于创建成功
            if (code == 10025)
            {
                TCILDebugLog(@"----->>>>>主播开始创建直播聊天室成功");
                [room setChatRoomID:roomid];
                if (block)
                {
                    block(YES, roomid, nil);
                }
                
                [ws enterAVLiveRoom:room avListener:delegate];
            }
            else
            {
                TCILDebugLog(@"----->>>>>主播开始创建直播聊天室失败 code: %d , msg = %@", code, error);
                
                if (block)
                {
                    NSError *err = [NSError errorWithDomain:error code:code userInfo:nil];
                    block(NO, nil, err);
                }
                
                [ws removeAudioInterruptListener];
            }
        }];
        
    }
    else
    {
        // 观众加群
        NSString *roomid = room.chatRoomID;
        if (roomid.length == 0)
        {
            TCILDebugLog(@"----->>>>>观众加入直播聊天室不成功");
            if (block)
            {
                NSError *err = [NSError errorWithDomain:@"聊天室ID为空" code:-1 userInfo:nil];
                block(NO, nil, err);
            }
            [ws removeAudioInterruptListener];
            return;
        }
        [[TIMGroupManager sharedInstance] JoinGroup:roomid msg:nil succ:^{
            TCILDebugLog(@"----->>>>>观众加入直播聊天室成功");
            if (block)
            {
                block(YES, roomid, nil);
            }
            [ws enterAVLiveRoom:room avListener:delegate];
            
        } fail:^(int code, NSString *error) {
            
            if (code == 10013)
            {
                TCILDebugLog(@"----->>>>>观众加入直播聊天室成功");
                if (block)
                {
                    block(YES, roomid, nil);
                }
                [ws enterAVLiveRoom:room avListener:delegate];
            }
            else
            {
                TCILDebugLog(@"----->>>>>观众加入直播聊天室失败 code: %d , msg = %@", code, error);
                // 作已在群的处的处理
                if (block)
                {
                    NSError *err = [NSError errorWithDomain:error code:code userInfo:nil];
                    block(NO, roomid, err);
                }
                [ws removeAudioInterruptListener];
            }
            
        }];
    }
}

- (QAVMultiParam *)createRoomParam:(TCILiveRoom *)room
{
    BOOL isHost =  [self isHostLive];
    QAVMultiParam *param = [[QAVMultiParam alloc] init];
    param.relationId = [room avRoomID];
    param.audioCategory = isHost ? CATEGORY_MEDIA_PLAY_AND_RECORD : CATEGORY_MEDIA_PLAYBACK;
    param.controlRole = [room.config roomControlRole];
    param.authBits = room.config.enterRoomAuth;
    param.createRoom = isHost;
    param.videoRecvMode = VIDEO_RECV_MODE_SEMI_AUTO_RECV_CAMERA_VIDEO;
#if DEBUG
    param.enableMic = NO;
#else
    param.enableMic = room.config.autoEnableMic;
#endif
    
    param.enableSpeaker = YES;
    param.enableHdAudio = YES;
    param.autoRotateVideo = NO;
    
    return param;
}

- (void)enterAVLiveRoom:(TCILiveRoom *)room avListener:(id<QAVRoomDelegate>)delegate
{
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    QAVMultiParam *param = [self createRoomParam:room];
    
    _avContext = [TCAVSharedContext sharedContext];
    
    if (!_avContext)
    {
        if (self.enterRoomBlock)
        {
            NSError *err = [NSError errorWithDomain:@"TCAVSharedContext未初始化" code:-1 userInfo:nil];
            self.enterRoomBlock(NO, err);
        }
        
        [self removeAudioInterruptListener];
        return;
    }
    
    // 检查当前网络
    QAVResult result = [_avContext enterRoom:param delegate:delegate];
    
    if(QAV_OK != result)
    {
        TCILDebugLog(@"进房间失败");
        
        if (self.enterRoomBlock)
        {
            NSError *err = [NSError errorWithDomain:@"TCAVSharedContext未初始化" code:-1 userInfo:nil];
            self.enterRoomBlock(NO, err);
        }
        
        if (delegate && [delegate respondsToSelector:@selector(OnEnterRoomComplete:)])
        {
            [delegate OnEnterRoomComplete:result];
        }
        
        [self removeAudioInterruptListener];
    }
}

- (void)enableCamera:(cameraPos)pos isEnable:(BOOL)bEnable complete:(void (^)(BOOL succ, QAVResult result))block
{
    if (_isLiving)
    {
        __weak typeof(_room) wr = _room;
        QAVResult res = [_avContext.videoCtrl enableCamera:pos isEnable:bEnable complete:^(int result) {
            if (result == QAV_OK)
            {
                wr.config.autoEnableCamera = bEnable;
                if (block)
                {
                    block(YES, result);
                }
            }
            else
            {
                if (result == QAV_ERR_HAS_IN_THE_STATE)
                {
                    // 已是重复状态不处理
                    wr.config.autoEnableCamera = bEnable;
                    if (block)
                    {
                        block(YES, QAV_ERR_HAS_IN_THE_STATE);
                    }
                }
                else
                {
                    // 打开相机重试
                    if (block)
                    {
                        block(NO, result);
                    }
                }
            }
            
        }];
        
        if (res != QAV_OK)
        {
            if (res == QAV_ERR_EXCLUSIVE_OPERATION)
            {
                // 互斥操作时，不会走回调
                TCILDebugLog(@"互斥操作, 没有执行该操作");
                if (block)
                {
                    block(NO, QAV_ERR_EXCLUSIVE_OPERATION);
                }
            }
            else
            {
                // 其他错误
                if (block)
                {
                    block(NO, res);
                }
            }
        }
    }
    else
    {
        if (block)
        {
            TCILDebugLog(@"没有进入房间，不能操作摄像头");
            block(NO, QAV_ERR_FAILED);
        }
    }
}

- (BOOL)isFrontCamera
{
    if (_isLiving)
    {
        return _avContext.videoCtrl && [_avContext.videoCtrl isFrontcamera];
    }
    return NO;
}

- (BOOL)isEnabledCamera
{
    if (_isLiving)
    {
        return _avContext.videoCtrl && _room.config.autoEnableCamera;
    }
    return NO;
}

- (void)turnOnFlash:(BOOL)on
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch])
    {
        [device lockForConfiguration:nil];
        [device setTorchMode: on ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
        [device unlockForConfiguration];
        
    }
}

/*
 * @brief 打开/关闭扬声器。
 * @param bEnable 是否打开。
 * @return YES表示操作成功，NO表示操作失败。
 */
- (BOOL)enableSpeaker:(BOOL)bEnable
{
    if (_isLiving)
    {
        BOOL succ = [_avContext.audioCtrl enableSpeaker:bEnable];
        
        if (succ)
        {
            _room.config.autoEnableSpeaker = bEnable;
        }
        return succ;
    }
    else
    {
        TCILDebugLog(@"没有进入房间，不能操作Speaker");
        return NO;
    }
    
}

- (BOOL)isEnabledSpeaker
{
    if (_isLiving)
    {
        return _room.config.autoEnableSpeaker;
    }
    return NO;
}

/**
 @brief 打开/关闭麦克风。
 
 @param isEnable 是否打开。
 
 @return YES表示操作成功，NO表示操作失败。
 */
- (BOOL)enableMic:(BOOL)isEnable
{
    if (_isLiving)
    {
        BOOL succ = [_avContext.audioCtrl enableMic:isEnable];
        
        if (succ)
        {
            _room.config.autoEnableMic = isEnable;
        }
        return succ;
    }
    else
    {
        TCILDebugLog(@"没有进入房间，不能操作Mic");
        return NO;
    }
}

- (BOOL)isEnabledMic
{
    if (_isLiving)
    {
        return _room.config.autoEnableMic;
    }
    return NO;
}

- (void)switchCamera:(cameraPos)pos complete:(void (^)(BOOL succ, QAVResult result))block
{
    if (_isLiving)
    {
        QAVVideoCtrl *avvc = [_avContext videoCtrl];
        
        __weak typeof(_room.config) wc = _room.config;
        QAVResult res = [avvc switchCamera:pos complete:^(int result) {
            if (QAV_OK == result)
            {
                wc.autoEnableCamera = YES;
                wc.autoCameraId = pos;
                if (block)
                {
                    block(YES, QAV_OK);
                }
            }
            else
            {
                if (result == QAV_ERR_HAS_IN_THE_STATE)
                {
                    // 已是重复状态不处理
                    wc.autoEnableCamera = YES;
                    wc.autoCameraId = pos;
                    if (block)
                    {
                        block(YES, QAV_ERR_HAS_IN_THE_STATE);
                    }
                }
                else
                {
                    if (block)
                    {
                        block(NO, QAV_ERR_HAS_IN_THE_STATE);
                    }
                }
                
            }
        }];
        
        
        if (res != QAV_OK)
        {
            if (res == QAV_ERR_EXCLUSIVE_OPERATION)
            {
                // 互斥操作时，不会走回调
                TCILDebugLog(@"互斥操作, 没有执行该操作");
                if (block)
                {
                    block(NO, QAV_ERR_EXCLUSIVE_OPERATION);
                }
            }
            else
            {
                // 其他错误
                if (block)
                {
                    block(NO, res);
                }
            }
        }
    }
    else
    {
        TCILDebugLog(@"没有进入房间，不能操作Mic");
        if (block)
        {
            block(NO, QAV_ERR_FAILED);
        }
    }
}

- (void)requestViewList:(NSArray *)identifierList srcTypeList:(NSArray *)srcTypeList ret:(RequestViewListBlock)block
{
    [_avContext.room requestViewList:identifierList srcTypeList:srcTypeList ret:^(QAVResult result) {
        if (QAV_OK != result)
        {
            TCILDebugLog(@"请求画面出错");
        }
    }];
}


- (void)innerWillExitRoom:(TCIRoomBlock)avBlock externalExit:(BOOL)fromExternal
{
    self.exitRoomBlock = avBlock;
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (_room.config.isSupportIM)
    {
        if (_room.config.isNeedExitIMChatRoom)
        {
            [self asyncExitAVChatRoom:_room succ:nil fail:nil];
        }
    }
    
    //    if (_room.config.autoMonitorNetwork)
    //    {
    //        [self removeNetworkListener];
    //    }
    
    if (_room.config.autoMonitorCall)
    {
        [self removeCallListener];
    }
    
    //    if (_room.config.autoMonitorKiekedOffline)
    //    {
    //        [[TIMManager sharedInstance] setUserStatusListener:nil];
    //    }
    
    if (_room.config.autoMonitorForeBackgroundSwitch)
    {
        [self addForeBackgroundListener];
    }
    
    [self releaseResource];
    
    
    int nettype = [[QalSDKProxy sharedInstance] getNetType];
    if (EQALNetworkType_NotReachable == nettype)
    {
        [self onAVExitRoom:fromExternal];
    }
    else
    {
        __weak typeof(self) ws = self;
        
        if (ws.pushMap.count)
        {
            [self asyncStopAllPushStreamWithSucc:^{
                [ws stopRecordOnExitRoom:fromExternal];
            } fail:^(int code, NSString *string) {
                [ws stopRecordOnExitRoom:fromExternal];
            }];
        }
        else
        {
            [self onAVExitRoom:fromExternal];
        }
    }
}

- (void)stopRecordOnExitRoom:(BOOL)fromExternal
{
    int nettype = [[QalSDKProxy sharedInstance] getNetType];
    if (EQALNetworkType_NotReachable == nettype)
    {
        [self onAVExitRoom:fromExternal];
    }
    else
    {
        __weak typeof(self) ws = self;
        
        if (ws.recordMap.count)
        {
            __weak typeof(self) ws = self;
            [self asyncStopRecordWithCompletion:^(NSArray *fileds) {
                [ws stopRecordOnExitRoom:fromExternal];
            } errBlock:^(int code, NSString *msg) {
                [ws stopRecordOnExitRoom:fromExternal];
            }];
        }
        else
        {
            [self onAVExitRoom:fromExternal];
        }
    }
    
}

- (void)onAVExitRoom:(BOOL)fromExternal
{
    if (fromExternal)
    {
        [_avContext exitRoom];
    }
    else
    {
        [self OnExitRoomComplete];
    }
    
}

/*
 * @brief 退出房间，内部统一处理
 * @param imblock:IM退群处理回调
 * @param avblock:AV出房间(-(void)OnExitRoomComplete)回调处理
 */
- (void)exitRoom:(TCIRoomBlock)avBlock
{
    [self innerWillExitRoom:avBlock externalExit:YES];
}


// 主播 : 主播删除直播聊天室
// 观众 : 观众退出直播聊天室
- (void)asyncExitAVChatRoom:(TCILiveRoom *)room succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (!room)
    {
        TCILDebugLog(@"直播房房间信息不正确");
        if (fail)
        {
            fail(-1, @"直播房房间信息不正确");
        }
        return;
    }
    
    NSString *roomid = [room chatRoomID];
    
    if (roomid.length == 0)
    {
        TCILDebugLog(@"----->>>>>观众退出的直播聊天室ID为空");
        if (fail)
        {
            fail(-1, @"直播聊天室ID为空");
        }
        return;
    }
    
    
    BOOL isHost = [self isHostLive];
    if (isHost)
    {
        // 主播删群
        [[TIMGroupManager sharedInstance] DeleteGroup:roomid succ:succ fail:fail];
    }
    else
    {
        // 观众退群
        [[TIMGroupManager sharedInstance] QuitGroup:roomid succ:succ fail:fail];
    }
}
/*
 * @brief 退出房间，外部统一处理回调，
 */
- (void)exitRoom
{
    [self exitRoom:nil];
}

- (void)releaseResource
{
    _delegate = nil;
    
    _avStatusList = nil;
    
    
    _isSwitchAuthAndRole = NO;
    
    
    _frameDispatcher.imageView = nil;
    _frameDispatcher = nil;
    
    [_avglView stopDisplay];
    [_avglView destroyOpenGL];
    _avglView = nil;
    
    [_autoRefreshMsgTimer invalidate];
    _msgHandler.roomIMListner = nil;
    _msgHandler = nil;
    
    QAVVideoCtrl *ctrl = [_avContext videoCtrl];
    [ctrl setLocalVideoDelegate:nil];
    [ctrl setRemoteVideoDelegate:nil];
}
//==============================================
- (TCIMemoItem *)getItemOf:(NSString *)identifier
{
    return [self renderMemoOf:identifier];
}

//==============================================
// 进入后台时回调
- (void)onEnterBackground
{
    [_avglView stopDisplay];
    
    
    if (_isLiving)
    {
        
        if (!_hasEnableCameraBeforeEnterBackground)
        {
            _hasEnableCameraBeforeEnterBackground = _room.config.autoEnableCamera;
        }
        if (_hasEnableCameraBeforeEnterBackground)
        {
            // 到前台的时候打开摄像头，但不需要通知到处面
            [self enableCamera:_room.config.autoCameraId isEnable:NO complete:^(BOOL succ, QAVResult result) {
                TCILDebugLog(@"退后台关闭摄像头:%@", succ ? @"成功" : @"失败");
            }];
        }
        
        if (!_hasEnableMicBeforeEnterBackground)
        {
            _hasEnableMicBeforeEnterBackground = _room.config.autoEnableMic;
        }
        if (_hasEnableMicBeforeEnterBackground && _room.config.isSupportBackgroudMode)
        {
            // 有后台模式时，关mic
            // 无后台模式，系统自动关
            TCILDebugLog(@"进入关开mic");
            [self enableMic:NO];
        }
    }
    
}

// 进入前台时回调
- (void)onEnterForeground
{
    if (_isLiving)
    {
        if (_hasEnableCameraBeforeEnterBackground)
        {
            // 到前台的时候打开摄像头，但不需要通知到处面
            [self enableCamera:_room.config.autoCameraId isEnable:YES complete:^(BOOL succ, QAVResult result) {
                TCILDebugLog(@"退后台关闭摄像头:%@", succ ? @"成功" : @"失败");
            }];
        }
        
        if (_hasEnableMicBeforeEnterBackground && _room.config.isSupportBackgroudMode)
        {
            // 有后台模式时，关mic
            // 无后台模式，系统自动关
            TCILDebugLog(@"进入关开mic");
            [self enableMic:YES];
        }
    }
    [_avglView startDisplay];
}

//==============================================
- (AVGLBaseView *)createAVGLViewIn:(UIViewController *)vc
{
    if (!vc)
    {
        TCILDebugLog(@"传入的直播界面不能为空");
        return nil;
    }
    if (!_avglView)
    {
        _avglView = [[AVGLBaseView alloc] initWithFrame:vc.view.bounds];
        _avglView.backgroundColor = [UIColor clearColor];
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        [_avglView setBackGroundTransparent:YES];
        [vc.view insertSubview:_avglView atIndex:0];
        
        @try
        {
            [_avglView initOpenGL];
            [self configDispatcher];
            TCILDebugLog(@"初始化OpenGL成功");
            
        }
        @catch (NSException *exception)
        {
            TCILDebugLog(@"OpenGL 初台化异常");
        }
        @finally
        {
            return _avglView;
        }
    }
    else
    {
        if (_avglView.superview != vc.view)
        {
            [_avglView removeFromSuperview];
            [vc.view insertSubview:_avglView atIndex:0];
        }
    }
    return _avglView;
}
- (AVGLBaseView *)createFloatAVGLViewIn:(UIViewController *)vc atRect:(CGRect)rect
{
    if (!vc)
    {
        TCILDebugLog(@"传入的直播界面不能为空");
        return nil;
    }
    if (!_avglView)
    {
        _avglView = [[AVGLBaseView alloc] initWithFrame:rect];
        _avglView.backgroundColor = [UIColor blackColor];
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        [_avglView setBackGroundTransparent:YES];
        [vc.view addSubview:_avglView];
        
        @try
        {
            [_avglView initOpenGL];
            [self configDispatcher];
            TCILDebugLog(@"初始化OpenGL成功");
            
        }
        @catch (NSException *exception)
        {
            TCILDebugLog(@"OpenGL 初台化异常");
        }
        @finally
        {
            return _avglView;
        }
    }
    else
    {
        if (_avglView.superview != vc.view)
        {
            [_avglView removeFromSuperview];
            [vc.view addSubview:_avglView];
        }
    }
    return _avglView;
}

- (void)configDispatcher
{
    if (!_frameDispatcher)
    {
        _frameDispatcher = [[TCAVFrameDispatcher alloc] init];
        _frameDispatcher.imageView = _avglView;
    }
    else
    {
        TCILDebugLog(@"Protected方法，外部禁止调用");
    }
}

- (TCIMemoItem *)hasRenderMemo:(NSString *)uid atFrame:(CGRect)rect;
{
    if (uid.length == 0)
    {
        return nil;
    }
    
    if (!_avStatusList)
    {
        _avStatusList = [NSMutableArray array];
    }
    
    for (TCIMemoItem *item in _avStatusList)
    {
        if ([item.identifier isEqualToString:uid])
        {
            item.showRect = rect;
            return item;
        }
    }
    
    TCIMemoItem *item = [[TCIMemoItem alloc] initWith:uid showRect:rect];
    [_avStatusList addObject:item];
    
    return nil;
}

- (TCIMemoItem *)renderMemoOf:(NSString *)uid
{
    for (TCIMemoItem *item in _avStatusList)
    {
        if ([item.identifier isEqualToString:uid])
        {
            return item;
        }
    }
    
    return nil;
}

- (void)removeRenderMemoOf:(NSString *)uid
{
    TCIMemoItem *bi = nil;
    for (TCIMemoItem *item in _avStatusList)
    {
        if ([item.identifier isEqualToString:uid])
        {
            bi = item;
            break;
        }
    }
    
    [_avStatusList removeObject:bi];
}

- (AVGLCustomRenderView *)renderFor:(NSString *)uid
{
    AVGLCustomRenderView *glView = (AVGLCustomRenderView *)[_avglView getSubviewForKey:uid];
    return glView;
}

- (AVGLCustomRenderView *)addRenderFor:(NSString *)uid atFrame:(CGRect)rect
{
    if (![self renderMemoOf:uid] && [self hasVideoCount] >= [self maxVideoCount])
    {
        TCILDebugLog(@"已达到最大请求数，不能添加RenderV");
        return nil;
    }
    
    if (!_avglView)
    {
        TCILDebugLog(@"_avglView为空，添加render无用");
        return nil;
    }
    
    if (uid.length == 0 || CGRectIsEmpty(rect))
    {
        TCILDebugLog(@"参数错误");
        return nil;
    }
    
    AVGLCustomRenderView *glView = (AVGLCustomRenderView *)[_avglView getSubviewForKey:uid];
    
    if (!glView)
    {
        glView = [[AVGLCustomRenderView alloc] initWithFrame:_avglView.bounds];
        [_avglView addSubview:glView forKey:uid];
    }
    else
    {
        TCILDebugLog(@"已存在的%@渲染画面，不重复添加", uid);
    }
    
    glView.frame = rect;
    [glView setHasBlackEdge:NO];
    glView.nickView.hidden = YES;
    [glView setBoundsWithWidth:0];
    [glView setDisplayBlock:NO];
    [glView setCuttingEnable:YES];
    
    if (![_avglView isDisplay])
    {
        [_avglView startDisplay];
    }
    
    [self hasRenderMemo:uid atFrame:rect];
    
    return glView;
}

- (void)switchRender:(NSString *)key withKey:(NSString *)oldKey
{
    [_avglView switchSubviewForKey:key withKey:oldKey];
}

- (void)removeRenderFor:(NSString *)uid
{
    [_avglView removeSubviewForKey:uid];
    [self removeRenderMemoOf:uid];
}

- (BOOL)switchRender:(NSString *)userid withOther:(NSString *)mainuser
{
    BOOL succ = [_avglView switchSubviewForKey:userid withKey:mainuser];
    if (succ)
    {
        AVGLRenderView *uv = [_avglView getSubviewForKey:userid];
        AVGLRenderView *mv = [_avglView getSubviewForKey:mainuser];
        
        [self hasRenderMemo:userid atFrame:uv.frame];
        [self hasRenderMemo:mainuser atFrame:mv.frame];
        
    }
    return succ;
}

- (BOOL)replaceRender:(NSString *)userid withUser:(NSString *)mainuser
{
    // 先交换二者的位置参数
    BOOL succ = [_avglView switchSubviewForKey:userid withKey:mainuser];
    if (succ)
    {
        AVGLRenderView *mv = [_avglView getSubviewForKey:mainuser];
        [self hasRenderMemo:mainuser atFrame:mv.frame];
        
        [self removeRenderFor:userid];
    }
    return succ;
}

- (void)registerRenderMemo:(NSArray *)list
{
    if (!list || list.count > 4)
    {
        TCILDebugLog(@"参数错误，不作处理");
        return;
    }
    
    
    if (!_avglView)
    {
        CGRect rect = [UIScreen mainScreen].bounds;
        _avglView = [[AVGLBaseView alloc] initWithFrame:rect];
        _avglView.backgroundColor = [UIColor blackColor];
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        [_avglView setBackGroundTransparent:YES];
        
        @try
        {
            [_avglView initOpenGL];
            [self configDispatcher];
            TCILDebugLog(@"初始化OpenGL成功");
            
        }
        @catch (NSException *exception)
        {
            TCILDebugLog(@"OpenGL 初台化异常");
        }
        @finally
        {
            
            
        }
    }
    
    if (!_avStatusList)
    {
        _avStatusList = [NSMutableArray array];
    }
    
    [_avStatusList removeAllObjects];
    
    for (TCIMemoItem *item in list)
    {
        if ([item isValid])
        {
            if (![item isPlaceholder])
            {
                [self addRenderFor:item.identifier atFrame:item.showRect];
            }
            else
            {
                [_avStatusList addObject:item];
            }
            
        }
    }
    
}

/*
 * @brief 如果在直播界面外，采用默内内部处理的逻辑（调用该接口- (void)enterRoom:imChatRoomBlock:avRoomCallBack:listener:）, 开始enterRoom，在进入到直播界面时，需要手动查下该
 */
- (NSDictionary *)getAVStatusList
{
    return nil;
}

//=====================================


- (void)sendToC2C:(NSString *)recvID message:(TIMMessage *)message succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (!_room.config.isSupportIM)
    {
        TCILDebugLog(@"传入的房间配置不支持IM");
        return;
    }
    if (recvID.length == 0)
    {
        TCILDebugLog(@"接收者recvID不能为空");
        return;
    }
    
    if (!message)
    {
        TCILDebugLog(@"发送的消息不能为空");
        return;
    }
    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:recvID];
    [conv sendMessage:message succ:succ fail:fail];
}
- (void)sendGroupMessage:(TIMMessage *)message succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (!_room.config.isSupportIM)
    {
        TCILDebugLog(@"传入的房间配置不支持IM");
        return;
    }
    
    if (!message)
    {
        TCILDebugLog(@"发送的消息不能为空");
        return;
    }
    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:_room.chatRoomID];
    [conv sendMessage:message succ:succ fail:fail];
}


// 向直播聊天室中发送文本消息
- (void)sendGroupTextMsg:(NSString *)msg succ:(TIMSucc)succ fail:(TIMFail)failed
{
    TIMMessage *message = [[TIMMessage alloc] init];
    
    TIMTextElem *elem = [[TIMTextElem alloc] init];
    elem.text = msg;
    
    [message addElem:elem];
    [self sendGroupMessage:message succ:succ fail:failed];
}

// 向直播聊天室中发送自定义的群自义消息
- (void)sendGroupCustomMsg:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed;
{
    TCILiveCMD *cmd = [[TCILiveCMD alloc] initWith:action param:actionParam];
    TIMMessage *msg = [cmd packToSendMessage];
    [self sendGroupMessage:msg succ:succ fail:failed];
}

// 向单个用户发送自定义的消息
- (void)sendC2CCustomMsg:(NSString *)recvID action:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed;
{
    TCILiveCMD *cmd = [[TCILiveCMD alloc] initWith:action param:actionParam];
    TIMMessage *msg = [cmd packToSendMessage];
    
    [self sendToC2C:recvID message:msg succ:succ fail:failed];
}

//====================================

- (TCILiveMsgHandler *)setAutoHandleMsgListener:(id<TCILiveMsgHandlerListener>)msgListener refreshInterval:(CGFloat)timerInterval
{
    if (!_isLiving || !_room)
    {
        // 还未进入到直播间，不能进行设置
        TCILDebugLog(@"还未进入到直播间，不能进行设置");
        return nil;
    }
    
    if (!_room.config.autoHandleLiveMsg)
    {
        TCILDebugLog(@"房间配置不支持自动消息处理");
        return nil;
    }
    
    // 定时上报消息
    
    if (!_msgHandler)
    {
        _msgHandler.roomIMListner = nil;
        _msgHandler = nil;
    }
    
    _msgHandler = [[TCILiveMsgHandler alloc] initWith:_room];
    _msgHandler.roomIMListner = msgListener;
    
    [_autoRefreshMsgTimer invalidate];
    _autoRefreshMsgTimer = nil;
    _autoRefreshMsgTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(onRefreshMsgToUI) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_autoRefreshMsgTimer forMode:NSRunLoopCommonModes];
    return _msgHandler;
}

- (void)onRefreshMsgToUI
{
    if (_canRenderNow)
    {
        [_msgHandler refreshMsgToUI];
        _canRenderNow = NO;
    }
    else
    {
        _canRenderNow = YES;
    }
}


- (void)filterCurrentLiveMessageInNewMessages:(NSArray *)messages
{
    [_msgHandler filterCurrentLiveMessageInNewMessages:messages];
}

- (void)filterCurrentLiveMessageInNewMessage:(TIMMessage *)message
{
    [_msgHandler filterCurrentLiveMessageInNewMessage:message];
}


//====================================

- (void)checkNoCameraAuth:(TCIVoidBlock)cameraNoBlock micNotPermission:(TCIVoidBlock)micNoBlock checkComplete:(TCIVoidBlock)complete
{
    BOOL hasCamAuth = YES;
    hasCamAuth = [self checkCameraAuth:cameraNoBlock];
    
    
    if (hasCamAuth)
    {
        [self checkMicNotPermission:micNoBlock checkComplete:complete];
    }
}


// iOS在App运行中，修改Mic以及相机权限，App会退出
// 检查Camera权限，没有权限时，执行noauthBlock
- (BOOL)checkCameraAuth:(TCIVoidBlock)cameraNoBlock
{
    if (self.hasCheckCameraAuth)
    {
        if (!self.hasCameraAuth)
        {
            if (cameraNoBlock)
            {
                cameraNoBlock();
            }
        }
        return self.hasCameraAuth;
    }
    else
    {
        self.hasCheckCameraAuth = YES;
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        self.hasCameraAuth = !(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied);
        if (!self.hasCameraAuth)
        {
            // 没有权限，到设置中打开权限
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (cameraNoBlock)
                {
                    cameraNoBlock();
                }
                
            });
        }
        return self.hasCameraAuth;
    }
    
}

- (void)checkMicNotPermission:(TCIVoidBlock)micNoBlock checkComplete:(TCIVoidBlock)complete
{
    __weak typeof(self) ws = self;
    if (ws.hasCheckMicPermission)
    {
        if (!ws.hasMicPermission)
        {
            if (micNoBlock)
            {
                micNoBlock();
            }
        }
        else
        {
            if (complete)
            {
                complete();
            }
        }
    }
    else
    {
        // 获取麦克风权限
        AVAudioSession *avSession = [AVAudioSession sharedInstance];
        if ([avSession respondsToSelector:@selector(requestRecordPermission:)])
        {
            [avSession requestRecordPermission:^(BOOL available) {
                ws.hasCheckMicPermission = YES;
                ws.hasMicPermission = available;
                if (!available)
                {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (micNoBlock)
                        {
                            micNoBlock();
                        }
                    });
                }
                else
                {
                    if (complete)
                    {
                        complete();
                    }
                }
            }];
        }
    }
}


//=====================================

- (void)checkNetwork:(void (^)(BOOL connect, EQALNetworkType type))checkNetblock
{
    BOOL connected = [[QalSDKProxy sharedInstance] isConnected];
    EQALNetworkType type = [[QalSDKProxy sharedInstance] getNetType];
    
    if (type > EQALNetworkType_ReachableViaWWAN)
    {
        // 不处理这些
        type = EQALNetworkType_ReachableViaWWAN;
    }
    
    if (checkNetblock)
    {
        checkNetblock(connected, type);
    }
}


- (void)addCallListener
{
    if (!_callCenter)
    {
        _callCenter = [[CTCallCenter alloc] init];
        __weak typeof(self) ws = self;
        _callCenter.callEventHandler = ^(CTCall *call) {
            // 需要在主线程执行
            [ws performSelectorOnMainThread:@selector(handlePhoneEvent:) withObject:call waitUntilDone:YES];
        };
    }
    
}

- (void)handlePhoneEvent:(CTCall *)call
{
    TCILDebugLog(@"电话中断处理：电话状态为call.callState = %@", call.callState);
    if ([call.callState isEqualToString:CTCallStateDisconnected])
    {
        // 电话已结束
        if (_isHandleCall)
        {
            // 说明在前台的时候接通过电话
            TCILDebugLog(@"电话中断处理：在前如的时候处理的电话，挂断后，立即回到前台");
            // iOS8下电话来之后，如果快速挂断，直接调用会导致无法打开摄像头
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 不加延时，若挂断时，相机操作会打不开
                [self onEnterForeground];
            });
        }
        else
        {
            TCILDebugLog(@"电话中断处理：退到后台接话：不处理");
        }
        
    }
    else
    {
        if (!_isHandleCall)
        {
            TCILDebugLog(@"电话中断处理：退到后台接话：不处理");
            // 首次收到，并且在前台
            _isHandleCall = YES;
            [self onEnterBackground];
        }
        else
        {
            TCILDebugLog(@"电话中断处理：已在后台接电话话：不处理");
        }
    }
}

- (void)removeCallListener
{
    _callCenter.callEventHandler = nil;
    _callCenter = nil;
}

//=====================================

/**
 @brief 返回QAVContext::EnterRoom()的异步操作结果的函数。
 
 @details 此函数用来返回QAVContext::EnterRoom()的异步操作结果。
 
 @param result 返回码。SDK的各种返回码的定义和其他详细说明参考QAVError.h。
 */
-(void)OnEnterRoomComplete:(int)result
{
    // 进入AV房间
    
    if(QAV_OK == result)
    {
        //设置麦克风和扬声器（在进入房间设置才有效）
        QAVVideoCtrl *ctrl = [_avContext videoCtrl];
        if (ctrl)
        {
            [ctrl setLocalVideoDelegate:self];
            [ctrl setRemoteVideoDelegate:self];
            [ctrl setScreenVideoDelegate:self];
        }
        
        if (_room.config.autoEnableCamera)
        {
            [self enableCamera:_room.config.autoCameraId isEnable:YES complete:nil];
        }
        
        //        if (![_room isHostLive] && _room.config.autoRequestView)
        //        {
        //            [self requestViewList:@[_room.liveHostID] srcTypeList:@[@(QAVVIDEO_SRC_TYPE_CAMERA)] ret:nil];
        //        }
        
        //        if (_room.config.autoMonitorNetwork)
        //        {
        //            [self addNetworkListener];
        //        }
        
        if (_room.config.autoMonitorCall)
        {
            [self addCallListener];
        }
        
        //        if (_room.config.autoMonitorKiekedOffline)
        //        {
        //            [[TIMManager sharedInstance] setUserStatusListener:self];
        //        }
        
        if (_room.config.autoMonitorForeBackgroundSwitch)
        {
            [self addForeBackgroundListener];
        }
        
        if (self.enterRoomBlock)
        {
            self.enterRoomBlock(YES, nil);
        }
    }
    else
    {
        if (self.enterRoomBlock)
        {
            NSError *err = [NSError errorWithDomain:[NSString stringWithFormat:@"错误码:%d", result] code:result userInfo:nil];
            self.enterRoomBlock(NO, err);
        }
    }
    
    self.enterRoomBlock = nil;
}


/**
 @brief 本地画面预览回调
 @param frameData : 本地视频帧数据
 */
-(void)OnLocalVideoPreview:(QAVVideoFrame*)frameData
{
    [self onAVRecvVideoFrame:frameData];
}

- (void)renderUIByAVSDK
{
    // AVSDK采集为15帧每秒
    // 可通过此处的控制显示的频率
    
    if (_canRenderNow)
    {
        [_msgHandler refreshMsgToUI];
        _canRenderNow = NO;
    }
}

- (void)onAVRecvVideoFrame:(QAVVideoFrame *)frame
{
    if ([_avglView isDisplay])
    {
        BOOL isLocal = frame.identifier.length == 0;
        if (isLocal)
        {
            // 为多人的时候要处理
            frame.identifier = _curUserID;
        }
        
        [_frameDispatcher dispatchVideoFrame:frame isLocal:isLocal isFront:[_avContext.videoCtrl isFrontcamera] isFull:YES];
    }
    
    [self renderUIByAVSDK];
}


-(void)OnLocalVideoPreProcess:(QAVVideoFrame*)frameData
{
    // do nothing
}

-(void)OnLocalVideoRawSampleBuf:(CMSampleBufferRef)buf result:(CMSampleBufferRef*)ret
{
    // do nothing
}


-(void)OnVideoPreview:(QAVVideoFrame*)frameData
{
    [self onAVRecvVideoFrame:frameData];
}
/**
 @brief 退出房间完成回调。
 
 @details APP调用ExitRoom()后，SDK通过此回调通知APP成功退出了房间。
 */
-(void)OnExitRoomComplete
{
    _isLiving = NO;
    [self releaseResource];
    if (self.exitRoomBlock)
    {
        self.exitRoomBlock(YES, nil);
    }
    self.exitRoomBlock = nil;
    
    if (_room.config.autoMonitorAudioInterupt)
    {
        [self removeAudioInterruptListener];
    }
}

/**
 @brief SDK主动退出房间提示。
 
 @details 该回调方法表示SDK内部主动退出了房间。SDK内部会因为30s心跳包超时等原因主动退出房间，APP需要监听此退出房间事件并对该事件进行相应处理
 
 @param reason 退出房间的原因，具体值见返回码。SDK的各种返回码的定义和其他详细说明参考QAVError.h。
 */

// 底层已退房
-(void)OnRoomDisconnect:(int)reason
{
    [self innerWillExitRoom:nil externalExit:NO];
    //    [_delegate onAVExitRoom:_liveOption succ:YES];
    TCILDebugLog(@"QAVSDK主动退出房间提示 : %d", reason);
    if ([_delegate respondsToSelector:@selector(onRoomDisconnected:)])
    {
        [_delegate onRoomDisconnected:reason];
    }
}


- (NSString *)eventTip:(QAVUpdateEvent)event
{
    switch (event)
    {
        case QAV_EVENT_ID_NONE:
            return @"no thing";
            break;
        case QAV_EVENT_ID_ENDPOINT_ENTER:
            return @"进入房间";
        case QAV_EVENT_ID_ENDPOINT_EXIT:
            return @"退出房间";
        case QAV_EVENT_ID_ENDPOINT_HAS_CAMERA_VIDEO:
            return @"打开摄像头";
        case QAV_EVENT_ID_ENDPOINT_NO_CAMERA_VIDEO:
            return @"关闭摄像头";
        case QAV_EVENT_ID_ENDPOINT_HAS_AUDIO:
            return @"打开麦克风";
        case QAV_EVENT_ID_ENDPOINT_NO_AUDIO:
            return @"关闭麦克风";
        case QAV_EVENT_ID_ENDPOINT_HAS_SCREEN_VIDEO:
            return @"发屏幕";
        case QAV_EVENT_ID_ENDPOINT_NO_SCREEN_VIDEO:
            return @"不发屏幕";
            
        default:
            return nil;
            break;
    }
}

- (void)autoRequestCameraViewOf:(NSArray *)endpoints ofEvenID:(QAVUpdateEvent)evenid
{
    
    for (QAVEndpoint *point in endpoints)
    {
        NSString *pid = [point identifier];
        TCIMemoItem *item = [self renderMemoOf:pid];
        
        
        
        if (!item)
        {
            NSArray *array = _avStatusList;
            for (TCIMemoItem *ti in array)
            {
                if (ti.isPlaceholder)
                {
                    ti.isCameraVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_CAMERA_VIDEO;
                    ti.isScreenVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_SCREEN_VIDEO;
                    ti.identifier = [point identifier];
                    [self addRenderFor:ti.identifier atFrame:ti.showRect];
                    item = ti;
                    break;
                }
            }
            
            if (!item)
            {
                item = [[TCIMemoItem alloc] init];
                item.identifier = [point identifier];
                item.isCameraVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_CAMERA_VIDEO;
                item.isScreenVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_SCREEN_VIDEO;
                [_avStatusList addObject:item];
            }
        }
        else
        {
            item.isCameraVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_CAMERA_VIDEO;
            item.isScreenVideo = evenid == QAV_EVENT_ID_ENDPOINT_HAS_SCREEN_VIDEO;
        }
    }
    NSMutableArray *ids = [NSMutableArray array];
    NSMutableArray *tds = [NSMutableArray array];
    
    for (TCIMemoItem *item in _avStatusList)
    {
        if (![item.identifier isEqualToString:self.curUserID])
        {
            if (item.isCameraVideo)
            {
                [tds addObject:@(QAVVIDEO_SRC_TYPE_CAMERA)];
                [ids addObject:item.identifier];
            }
            else if (item.isScreenVideo)
            {
                [tds addObject:@(QAVVIDEO_SRC_TYPE_SCREEN)];
                [ids addObject:item.identifier];
            }
        }
    }
    [self requestViewList:ids srcTypeList:tds ret:nil];
}

/**
 @brief 房间成员状态变化通知的函数。
 
 @details 当房间成员发生状态变化(如是否发音频、是否发视频等)时，会通过该函数通知业务侧。
 
 @param eventID 状态变化id，详见QAVUpdateEvent的定义。
 @param endpoints 发生状态变化的成员id列表。
 */
-(void)OnEndpointsUpdateInfo:(QAVUpdateEvent)eventID endpointlist:(NSArray *)endpoints
{
    TCILDebugLog(@"endpoints = %@ evenId = %d %@", endpoints, (int)eventID, [self eventTip:eventID]);
    
    switch (eventID)
    {
        case QAV_EVENT_ID_ENDPOINT_ENTER:// = 1,             ///< 进入房间事件。
        {
            
        }
            break;
        case QAV_EVENT_ID_ENDPOINT_EXIT:// = 2,              ///< 退出房间事件。
        {
            
        }
            break;
        case QAV_EVENT_ID_ENDPOINT_HAS_CAMERA_VIDEO:// 3,  ///< 有发摄像头视频事件。
        {
            
            //            for (QAVEndpoint *point in endpoints)
            //            {
            //                TCIMemoItem *item = [self renderMemoOf:point.identifier];
            //                item.isCameraVideo = YES;
            //            }
            //
            if (_room.config.autoRequestView)
            {
                [self autoRequestCameraViewOf:endpoints ofEvenID:eventID];
            }
            
        }
            
            break;
            
        case QAV_EVENT_ID_ENDPOINT_NO_CAMERA_VIDEO:// 4,  ///< 无发摄像头视频事件。
        {
            for (QAVEndpoint *point in endpoints)
            {
                TCIMemoItem *item = [self renderMemoOf:point.identifier];
                item.isCameraVideo = NO;
            }
        }
            break;
            
        case QAV_EVENT_ID_ENDPOINT_HAS_AUDIO:// = 5,        ///< 有发语音事件。
        {
            for (QAVEndpoint *point in endpoints)
            {
                TCIMemoItem *item = [self renderMemoOf:point.identifier];
                item.isAudio = YES;
            }
        }
            break;
        case QAV_EVENT_ID_ENDPOINT_NO_AUDIO:// = 6,         ///< 无发语音事件。
        {
            for (QAVEndpoint *point in endpoints)
            {
                TCIMemoItem *item = [self renderMemoOf:point.identifier];
                item.isAudio = NO;
            }
        }
            break;
            
        case QAV_EVENT_ID_ENDPOINT_HAS_SCREEN_VIDEO:// = 7,  ///< 有发屏幕视频事件。
        {
            //            for (QAVEndpoint *point in endpoints)
            //            {
            //                TCIMemoItem *item = [self renderMemoOf:point.identifier];
            //                item.isScreenVideo = YES;
            //            }
            if (_room.config.autoRequestView)
            {
                [self autoRequestCameraViewOf:endpoints ofEvenID:eventID];
            }
        }
            break;
        case QAV_EVENT_ID_ENDPOINT_NO_SCREEN_VIDEO:// = 8,   ///< 无发屏幕视频事件。
        {
            for (QAVEndpoint *point in endpoints)
            {
                TCIMemoItem *item = [self renderMemoOf:point.identifier];
                item.isScreenVideo = NO;
            }
        }
            break;
        default:
            break;
    }
    
    if ([_delegate respondsToSelector:@selector(onEndpointsUpdateInfo:endpointlist:)])
    {
        [_delegate onEndpointsUpdateInfo:eventID endpointlist:endpoints];
    }
}

- (void)handleSemiCameraVideoList:(NSArray *)identifierList
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *uid in identifierList)
    {
        TCIMemoItem *item = [self renderMemoOf:uid];
        if ([item isPlaceholder] && [item isValid])
        {
            item.identifier = uid;
            [self addRenderFor:uid atFrame:item.showRect];
        }
        else
        {
            [array addObject:uid];
        }
    }
    
    if (array.count)
    {
        if ([_delegate respondsToSelector:@selector(onRecvSemiAutoCameraVideo:)])
        {
            [_delegate onRecvSemiAutoCameraVideo:array];
        }
    }
}

- (void)OnSemiAutoRecvCameraVideo:(NSArray *)identifierList
{
    // 内部自动接收
    //    [_delegate onAVRecvSemiAutoVideo:identifierList];
    [self handleSemiCameraVideoList:identifierList];
}

-(void)OnPrivilegeDiffNotify:(int)privilege
{
    
}

-(void)OnCameraSettingNotify:(int)width Height:(int)height Fps:(int)fps
{
    // do nothing
}

-(void)OnRoomEvent:(int)type subtype:(int)subtype data:(void*)data
{
    // do nothing
}

//======================

// 具体与Spear配置相关，请注意设置
- (void)changeToRole:(NSString *)role auth:(unsigned long long)auth completion:(TCIFinishBlock)completion
{
    if (_isSwitchAuthAndRole)
    {
        TCILDebugLog(@"正在切换role或auth，请稍后再试");
        if (completion)
        {
            completion(NO);
        }
        return;
    }
    
    if (_isLiving)
    {
        _isSwitchAuthAndRole = YES;
        _switchToRole = role;
        _switchToAuth = auth;
        
        self.switchAutoRoleCompletion = completion;
        QAVMultiRoom *room = (QAVMultiRoom *)_avContext.room;
        [room ChangeAuthoritybyBit:auth orstring:nil delegate:self];
    }
    else
    {
        TCILDebugLog(@"当前不在直播，不用切换角色与权限");
        if (completion)
        {
            completion(NO);
        }
    }
}

- (QAVResult)changeAVControlRole:(NSString *)role
{
    if (_isLiving)
    {
        QAVMultiRoom *room = (QAVMultiRoom *)_avContext.room;
        QAVResult res = [room ChangeAVControlRole:role delegate:self];
        return res;
    }
    else
    {
        TCILDebugLog(@"房间状态不正确，无法changeRole");
    }
    return QAV_ERR_FAILED;
}

- (void)OnChangeRoleDelegate:(int)ret_code
{
    BOOL succ = ret_code == QAV_OK;
    if (self.switchAutoRoleCompletion)
    {
        self.switchAutoRoleCompletion(succ);
    }
    self.switchAutoRoleCompletion = nil;
    _isSwitchAuthAndRole = NO;
}


- (void)OnChangeAuthority:(int)ret_code
{
    BOOL succ = ret_code == QAV_OK;
    TCILDebugLog(@"修改用户Auth至%ld %@", (long)_switchToAuth, succ ? @"成功" : @"失败");
    if (succ)
    {
        // 修改权限成功
        NSString *role = _switchToRole;
        QAVResult res = [self changeAVControlRole:role];
        if (res != QAV_OK)
        {
            
            if (self.switchAutoRoleCompletion)
            {
                self.switchAutoRoleCompletion(NO);
            }
            self.switchAutoRoleCompletion = nil;
            _isSwitchAuthAndRole = NO;
        }
    }
    else
    {
        if (self.switchAutoRoleCompletion)
        {
            self.switchAutoRoleCompletion(NO);
        }
        self.switchAutoRoleCompletion = nil;
        _isSwitchAuthAndRole = NO;
    }
}

//================================
// 推流

- (void)asyncStartPushStream:(NSString *)channelName channelDesc:(NSString *)channelDesc type:(AVEncodeType)type succ:(void(^)(TCILivePushRequest *req))succ fail:(OMMultiFail)fail
{
    if (!_isLiving)
    {
        if (fail)
        {
            fail(-1, @"未开始直播，不能进行推流");
        }
        return;
    }
    TCILivePushRequest *oreq = _pushMap[@(type)];
    if (oreq)
    {
        if (fail)
        {
            fail(-2, [NSString stringWithFormat:@"当前正在进行［%d］推流", (int)type]);
        }
        return;
    }
    
    if (!_pushMap)
    {
        _pushMap = [NSMutableDictionary dictionary];
    }
    
    TCILivePushRequest *req = [[TCILivePushRequest alloc] initWith:_room channelName:channelName channelDesc:channelDesc type:type];
    
    __weak typeof(self) ws = self;
    int res = [[IMSdkInt sharedInstance] requestMultiVideoStreamerStart:req.roomInfo streamInfo:req.pushParam okBlock:^(AVStreamerResp *avstreamResp) {
        req.pushResp = avstreamResp;
        [ws.pushMap setObject:req forKey:@(type)];
        if (succ)
        {
            succ(req);
        }
    } errBlock:fail];
    
    if (res != 0)
    {
        if (fail)
        {
            fail(res, @"调用推流接口出错");
        }
    }
}

- (void)asyncStopPushStream:(AVEncodeType)type succ:(OMMultiSucc)succ fail:(OMMultiFail)fail
{
    if (!_isLiving)
    {
        if (fail)
        {
            fail(-1, @"未开始直播，不用停止推流");
        }
        return;
    }
    
    TCILivePushRequest *oreq = _pushMap[@(type)];
    if (oreq)
    {
        [self.pushMap removeObjectForKey:@(type)];
        [[IMSdkInt sharedInstance] requestMultiVideoStreamerStop:oreq.roomInfo channelIDs:@[@(oreq.pushResp.channelID)] okBlock:succ errBlock:fail];
    }
    else
    {
        TCILDebugLog(@"当前没有[%d]推流，不用停止", (int)type);
    }
    
}
- (void)asyncStopAllPushStreamWithSucc:(OMMultiSucc)succ fail:(OMMultiFail)fail
{
    if (!_isLiving)
    {
        if (fail)
        {
            fail(-1, @"未开始直播，不用停止推流");
        }
        return;
    }
    
    NSArray *allReq = self.pushMap.allValues;
    if (allReq)
    {
        NSMutableArray *array = [NSMutableArray array];
        
        for (TCILivePushRequest *req in allReq)
        {
            [array addObject:@(req.pushResp.channelID)];
        }
        
        _pushMap = nil;
        
        UInt32 roomid = (UInt32)[_room avRoomID];
        OMAVRoomInfo *avRoomInfo = [[OMAVRoomInfo alloc] init];
        avRoomInfo.roomId = roomid;
        avRoomInfo.relationId = roomid;
        
        [[IMSdkInt sharedInstance] requestMultiVideoStreamerStop:avRoomInfo channelIDs:array okBlock:succ errBlock:fail];
    }
    
}

//================================

- (void)asyncStartRecord:(AVRecordInfo *)recordInfo succ:(OMMultiSucc)succ errBlock:(OMMultiFail)fail
{
    if (!recordInfo)
    {
        if (fail)
        {
            fail(-1, @"参数为空");
        }
        return;
    }
    
    if (!_isLiving)
    {
        if (fail)
        {
            fail(-1, @"未开始直播，不能进行录制");
        }
        return;
    }
    
    NSInteger type = recordInfo.recordType;
    TCILiveRecordRequest *oreq = _recordMap[@(type)];
    if (oreq)
    {
        if (fail)
        {
            fail(-2, [NSString stringWithFormat:@"当前正在进行［%d］录制", (int)type]);
        }
        return;
    }
    
    if (!_recordMap)
    {
        _recordMap = [NSMutableDictionary dictionary];
    }
    
    TCILiveRecordRequest *req = [[TCILiveRecordRequest alloc] initWith:_room record:recordInfo];
    
    __weak typeof(self) ws = self;
    int res = [[IMSdkInt sharedInstance] requestMultiVideoRecorderStart:req.roomInfo recordInfo:req.recordInfo okBlock:^{
        [ws.recordMap setObject:req forKey:@(type)];
        if (succ)
        {
            succ();
        }
        
    } errBlock:fail];
    
    
    if (res != 0)
    {
        if (fail)
        {
            fail(res, @"调用录制接口出错");
        }
    }
}
- (void)asyncStopRecordWithCompletion:(OMMultiVideoRecorderStopSucc)succ errBlock:(OMMultiFail)fail
{
    
    if (!_isLiving)
    {
        if (fail)
        {
            fail(-1, @"未开始直播，不用停止推流");
        }
        return;
    }
    
    if (_recordMap)
    {
        self.recordMap = nil;
        
        UInt32 roomid = (UInt32)[_room avRoomID];
        OMAVRoomInfo *avRoomInfo = [[OMAVRoomInfo alloc] init];
        avRoomInfo.roomId = roomid;
        avRoomInfo.relationId = roomid;
        
        int ret = [[IMSdkInt sharedInstance] requestMultiVideoRecorderStop:avRoomInfo okBlock:succ errBlock:fail];
        
        if (ret != 0 && succ)
        {
            succ(nil);
        }
    }
    else
    {
        if (succ)
        {
            succ(nil);
        }
    }
}



@end


@implementation TCILiveManager (ProtectedMethod)

- (void)onLogoutCompletion
{
    [TCAVSharedContext destroyContextCompletion:nil];
    self.avContext = nil;
    self.curUserID = nil;
}

@end
