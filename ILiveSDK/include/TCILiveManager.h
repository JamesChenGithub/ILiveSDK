//
//  TCILiveManager.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/ImSDK.h>
#import <QAVSDK/QAVSDK.h>

#import "TCILiveConst.h"
#import "TCILiveRoom.h"
#import "TCIMemoItem.h"

#import "TCILiveManagerDelegate.h"
#import "TCILiveMsgHandler.h"
#import "TCILivePushRequest.h"
#import "TCILiveRecordRequest.h"

@class AVGLBaseView;
@class AVGLCustomRenderView;


@interface TCILiveManager : NSObject
{
@protected
    NSString        *_curUserID;
    QAVContext      *_avContext;
    
@protected
    TCILiveRoom     *_room;
    
    __weak id<TCILiveManagerDelegate> _delegate;
}

@property (nonatomic, readonly) NSString *curUserID;    // 当前用户ID
@property (nonatomic, readonly) QAVContext *avContext;
@property (nonatomic, readonly) AVGLBaseView *avglView;
@property (nonatomic, readonly) TCILiveRoom *room;

/*
 * @brief 没有接入IMSDK，可使用该方法配置IMSDK，如果之前已接入IMSDK，则可以不使用该方法进行接入
 * @param sdkAppId : 用户在腾讯上申请的AppID，必传
 * @param accountType : 用户在腾讯上申请的accountType，，必传
 * @param willDo : 初始化IMSDK前要处理的操作，通常是指定IMSDK相关的日志配置，可为nil
 * @param completion : 初始化IMSDK后，要设置的IMSDK内部的一些监听回调，用户根据业务逻辑配置，可为nil
 */
+ (void)configWithAppID:(int)sdkAppId accountType:(NSString *)accountType willInit:(TCIVoidBlock)willDo initCompleted:(TCIVoidBlock)completion;

+ (instancetype)sharedInstance;

// 当前是不是主播
- (BOOL)isHostLive;

// 外部状态判断：当前是不是在直播
- (BOOL)isLiving;

/*
 * @bried 未接入IMSDK的可直接使用下面的方法进行登录, 其内部会自动startContextWith:completion:方法，相当于默认初始化完IMSDK+AVSDK所有的操作
 * @param param : 登录IMSDK的参数
 * @param fail : 登录IMSDK失败回调
 * @param offline : 登录时，遇到互踢回调
 * @param completion : 登录IMSDK，并且始化AVSDK Context的回调
 */
- (void)login:(TIMLoginParam *)param loginFail:(TIMFail)fail offlineKicked:(void (^)(TIMLoginParam *param, TCIRoomBlock succ, TIMFail fail))offline startContextCompletion:(TCIRoomBlock)completion;

/*
 * @bried 只登录IMSDK的可直接使用下面的方法进行登录, 其内部不会自动初始化AVSDK上下文
 * @param param : 登录IMSDK的参数
 * @param fail : 登录IMSDK失败回调
 * @param offline : 登录时，遇到互踢回调
 * @param succ : 登录IMSDK成功回调
 */
- (void)login:(TIMLoginParam *)param loginFail:(TIMFail)fail offlineKicked:(void (^)(TIMLoginParam *param, TCIRoomBlock succ, TIMFail fail))offline succ:(TCIRoomBlock)completion;

/*
 * @brief 开启AVSDK上下文，在登录IMSDK成功后调用
 * @param param : 登录IMSDK的参数
 * @param completion : 启动上下文回调
 */
- (void)startContextWith:(TIMLoginParam *)param completion:(TCIRoomBlock)completion;

/*
 * @breif 登出操作：当前如果在直播，会先退出直播，然后再登出IMSDK，以及停止以及销毁AVSDK上下文
 * @param succ : 登出成功回调
 * @param fail : 登出失败回调
 */
- (void)logout:(TIMLoginSucc)succ fail:(TIMFail)fail;


//=============================================================
// 网络检查

/*
 * @brief 检查直播中的网络状态，同步返回checkNetblock，外部用户，根据connect与type的组合，处理自身业务逻辑
 * @param connect : 网络是否连接上, YES : 连上 NO : 断开
 * @param type : 当前的网络类型，内部过滤不常用的，只返回以下四种
 * EQALNetworkType_Undefine = -1,
 * EQALNetworkType_NotReachable = 0,
 * EQALNetworkType_ReachableViaWiFi = 1,
 * EQALNetworkType_ReachableViaWWAN = 2,
 */
- (void)checkNetwork:(void (^)(BOOL connect, EQALNetworkType type))checkNetblock;

/*
 * @brief 检查Mic以及摄像头头权限。iOS在App运行中，修改Mic以及相机权限，App会退出，所以运行时，只有创建或邀请上麦者需要检查该权限，检查过一次之后，同一项不需要再检查第二次
 * 实际操作时，用户可自行检查。当无Camera无权限，会进入cameraNoBlock，不会继续检查Mic权限。如果无mic权限会进入micNoBlock，有权限则进行micBlock，用户在micBlock中进行后续相关的操作
 * @param cameraNoBlock : 无相机权限回调
 * @param micNoBlock : 无Mic权限回调
 * @param complete : 相机，以及Mic权限都有，检查成功，可正常进行直播
 */
- (void)checkNoCameraAuth:(TCIVoidBlock)cameraNoBlock micNotPermission:(TCIVoidBlock)micNoBlock checkComplete:(TCIVoidBlock)complete;

- (void)checkMicNotPermission:(TCIVoidBlock)micNoBlock checkComplete:(TCIVoidBlock)complete;


//=============================================================

// 手动处理渲染
/*
 * @brief 向直播界面添加渲染控件，所创建的AVGLBaseView会自动insert到vc.view的0位置
 * @param vc:创建的直播界面
 * @return 返回创建的渲染控件，以便外部可作其他处理
 */
- (AVGLBaseView *)createAVGLViewIn:(UIViewController *)vc;
- (AVGLBaseView *)createFloatAVGLViewIn:(UIViewController *)vc atRect:(CGRect)rect;

/*
 * @brief 向直播界面所添加渲染控件AVGLBaseView上添加渲染窗口，如果已添加过该uid，会对应只更新对应的renderView的区域
 * @param uid : 默认添加的是摄像头视频源标识id （如果业务是只处理手机视频，可使用用户id作标识）
 * @return 返回渲染所用的renderview，以便外部可作其他处理
 */

- (AVGLCustomRenderView *)renderFor:(NSString *)uid;

- (AVGLCustomRenderView *)addRenderFor:(NSString *)uid atFrame:(CGRect)rect;

- (void)switchRender:(NSString *)key withKey:(NSString *)oldKey;

- (void)removeRenderFor:(NSString *)uid;

// 直播前配置好渲染
/*
 * @brief 如果在直播界面外，采用默内内部处理的逻辑（调用该接口- (void)enterRoom:imChatRoomBlock:avRoomCallBack:listener:）。
 *        因开始enterRoom，在进入到直播界面时，会收到半自动推送视频画面。提前在本地处理好要渲染的区域(未开始直播前设置)
 * @param list : 为TCIMemoItem列表，所传的TCIMemoItem.showRect不能为CGRectZero，若为CGRectZero内部会过滤，其有顺序要求，外部控制好逻辑（全屏的放在前面，小窗口放至后面）。最多为4个，为空或大于四个则不作处理
 * @return 返回一个全屏的AVGLRenderView，外部而不急于添加到直播界面
 */
- (void)registerRenderMemo:(NSArray *)list;

// 直播进房间接口
/*
 * @brief 进入房间，内部统一处理AVSDK回调, 默认已使用请求画面，打开摄像头操作，以及回调设置，但是外部，还是要监一下，直播中的遇到的问题
 * @param room不能为空
 * @param imblock:IM处理回调
 * @param avblock:AV进房间(-(void)OnEnterRoomComplete:(int)result)回调处理
 * @param managerDelegate : TCILiveManager内部单次直播时的回调处理
 */
- (void)enterRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)imblock avRoomCallBack:(TCIRoomBlock)avblock managerListener:(id<TCILiveManagerDelegate>)managerDelegate;

/*
 * @brief 进入房间，外部处理AVSDK回调
 * @param room不能为空
 * @param imblock:IM处理回调
 * @param delegate:进AV房间处理回调，若delegate不为空且不为[TCILiveManager sharedInstance]，外部处理，不走该回调
 * @param managerDelegate : TCILiveManager内部单次直播时的回调处理
 */
- (void)enterRoom:(TCILiveRoom *)room imChatRoomBlock:(TCIChatRoomBlock)imblock avListener:(id<QAVRoomDelegate>)delegate managerListener:(id<TCILiveManagerDelegate>)managerDelegate;

/*
 * @brief 打开或关闭摄像头，外部尽量使用该方法进行摄像头操作，其内部会记录摄像头状态
 * @param pos: 摄像头ID，CameraPosFront:前置摄像头 CameraPosBack:后置摄像头
 * @param bEnable : YES/打开, NO/关闭
 * @parma block : 返回操作结果
 */
- (void)enableCamera:(cameraPos)pos isEnable:(BOOL)bEnable complete:(void (^)(BOOL succ, QAVResult result))block;

// 是否使用的是前置摄像头
- (BOOL)isFrontCamera;

// 是否打开了摄像头
- (BOOL)isEnabledCamera;

- (void)turnOnFlash:(BOOL)on;

/*
 * @brief 打开/关闭扬声器。
 * @param bEnable 是否打开。
 * @return YES表示操作成功，NO表示操作失败。
 */
- (BOOL)enableSpeaker:(BOOL)bEnable;
- (BOOL)isEnabledSpeaker;

/**
 @brief 打开/关闭麦克风。
 
 @param isEnable 是否打开。
 
 @return YES表示操作成功，NO表示操作失败。
 */
- (BOOL)enableMic:(BOOL)isEnable;
- (BOOL)isEnabledMic;

/*
 * @brief 摄像头切换，外部尽量使用该方法进行摄像头操作，其内部会记录摄像头状态
 * @param pos: 摄像头ID，CameraPosFront:前置摄像头 CameraPosBack:后置摄像头
 * @param bEnable : YES/打开, NO/关闭
 */
- (void)switchCamera:(cameraPos)pos complete:(void (^)(BOOL succ, QAVResult result))block;



- (void)requestViewList:(NSArray *)identifierList srcTypeList:(NSArray *)srcTypeList ret:(RequestViewListBlock)block;


/*
 * @brief 退出房间，内部统一处理
 * @param imblock:IM退群处理回调
 * @param avblock:AV出房间(-(void)OnExitRoomComplete)回调处理
 */
- (void)exitRoom:(TCIRoomBlock)avBlock;

/*
 * @brief 退出房间，外部统一处理回调;
 */
- (void)exitRoom;

//================================

//- (TCIMemoItem *)getItemOf:(NSString *)identifier;

//================================
// 外部监听前后台事件，然后主动调用下面的方法
// 进入后台时回调
- (void)onEnterBackground;

// 进入前台时回调
- (void)onEnterForeground;

//================================
// 直播间内发送消息处理逻辑

/*
 * @breif 向直播聊天室中发送文本消息
 * @param msg : 文本消息内容
 * @param succ : 发送成功回调，下同
 * @param failed : 发送失败回调，下同
 */
- (void)sendGroupTextMsg:(NSString *)msg succ:(TIMSucc)succ fail:(TIMFail)failed;


/*
 * @breif 向直播聊天室中发送群自定义消息
 * @param action : 自定义命令字段
 * @param action : 自定义消息参数字段
 */
- (void)sendGroupCustomMsg:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed;

/*
 * @breif 向单个用户发送自定义的消息
 * @param action : 单个用户的ID
 * @param action : 自定义命令字段
 * @param action : 自定义消息参数字段
 */
- (void)sendC2CCustomMsg:(NSString *)recvID action:(NSInteger)action actionParam:(NSString *)actionParam succ:(TIMSucc)succ fail:(TIMFail)failed;

//================================

// 在TIMMessageListener的onNewMessage中添加该方法，进行直播间过滤（onNewMessage可提前过滤）
- (void)filterCurrentLiveMessageInNewMessages:(NSArray *)messages;

- (void)filterCurrentLiveMessageInNewMessage:(TIMMessage *)messages;

/*
 * @brief msgListener监听直播间内消息，并以timerInterval秒的刷新一次消息，前提：当前必须是在直播间内且_room.config.autoHandleLiveMsg必须为YES
 * @description 外部主动在IMSDK的消息回调onNewMessage中调用 - (void)filterCurrentLiveMessageInNewMessages:(NSArray *)messages; 或 - (void)filterCurrentLiveMessageInNewMessage:(TIMMessage *)messages; 内部自动过滤出跟当前直播间相关的消息，半进行解析，然后上抛给界面进行处理
 * @param msgListener : 直播间内的消息监听
 * @param timerInterval : 直播间内的消息刷新间隔，如果无画面时，消息渲染会有一定延迟（约2＊timerInterval秒）
 */
- (TCILiveMsgHandler *)setAutoHandleMsgListener:(id<TCILiveMsgHandlerListener>)msgListener refreshInterval:(CGFloat)timerInterval;

//=============================
// 请求上下麦逻辑

// 具体与Spear配置相关，请注意设置
// completion为异步回调，注意内存泄露
- (void)changeToRole:(NSString *)role auth:(unsigned long long)auth completion:(TCIFinishBlock)completion;

//================================
// 推流/录制

/*
 * @brief 开始推流（一般只建议在开摄像头端，才可以进以推流），进入直播间内才可以推流，发起直播者调用
 * @description 内部记录推流状态，退出房间时，若外部未停止推流，内部先停止推流，再退出房间。不停止推流，有可能会导致下一次推流不成功，同时也有可能占用云资源增加计费。
 * @param channelName : 频道名，
 * @param streamInfo : 频道描述
 * @param streamInfo : 推流类型
 * @param succ : 成功回调，返回推流响应,  req，底层发送的推流靖求
 * @param failed : 失败回调
 */
- (void)asyncStartPushStream:(NSString *)channelName channelDesc:(NSString *)channelDesc type:(AVEncodeType)type succ:(void(^)(TCILivePushRequest *req))succ fail:(OMMultiFail)fail;

/*
 * @brief 停止推流（外部手动调用时，会将内部记录的状态清空）
 * @param channelIDs : 推流的频道号
 * @param succ : 成功回调
 * @param failed : 失败回调
 */
- (void)asyncStopPushStream:(AVEncodeType)type succ:(OMMultiSucc)succ fail:(OMMultiFail)fail;

/*
 * @brief 停止所有推流
 * @param succ : 成功回调
 * @param failed : 失败回调
 */
- (void)asyncStopAllPushStreamWithSucc:(OMMultiSucc)succ fail:(OMMultiFail)fail;

/*
 * @brief 开始录制（只支持一个录制，开启新录制时，停掉这前的），进入直播间内才可以录制，发起直播者调用
 * @param recordInfo : 录制的信息，不能为空
 * @param succ : 成功回调
 * @param failed : 失败回调
 */
- (void)asyncStartRecord:(AVRecordInfo *)recordInfo succ:(OMMultiSucc)succ errBlock:(OMMultiFail)fail;

/*
 * @brief 停止录制（只支持一个录制，开启新录制时，停掉这前的），进入直播间内才可以停止录制，发起直播者调用
 * @param succ : 成功回调
 * @param failed : 失败回调
 */
- (void)asyncStopRecordWithCompletion:(OMMultiVideoRecorderStopSucc)succ errBlock:(OMMultiFail)fail;




@end


@interface TCILiveManager (ProtectedMethod)
- (void)onLogoutCompletion;
@end
