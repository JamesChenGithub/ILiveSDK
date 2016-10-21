//
//  TCAVIMMIManager.h
//  TCShow
//
//  Created by AlexiChen on 16/5/6.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCILiveManager.h"
#import "TCILiveConst.h"

// TCAVIMMIManager: Tencent Clound AVSDM/IMSDK Multi Interact Manager
// 该类只处理互动用户的管理，不包括渲染逻辑

@class TCAVIMMIManager;

@protocol TCAVIMMIManagerDelegate <NSObject>

@required

// 外部界面切换到请求画面操作
- (void)onAVIMMIMManagerRequestHostViewFailed:(TCAVIMMIManager *)mgr;

// 外部分配user窗口位置，此处可在界面显示相应的小窗口
// inviteOrAuto : YES, 主动邀请的, NO: 收到邀请主动创建的
- (void)onAVIMMIMManager:(TCAVIMMIManager *)mgr assignWindowResourceTo:(NSString *)user isInvite:(BOOL)inviteOrAuto;

// 外部界面切换到请求画面操作
- (void)onAVIMMIMManager:(TCAVIMMIManager *)mgr requestViewComplete:(BOOL)succ;

// 外部回收user窗口资源信息
- (void)onAVIMMIMManager:(TCAVIMMIManager *)mgr recycleWindowResourceOf:(NSString *)user;

@end

@interface TCAVIMMIManager : NSObject
{
@protected
    NSMutableArray                      *_multiResource;            // 正在互动用户列表，最大只能是四个
    NSString                            *_mainUser;                 // 主用户（全屏用户）
    __weak id<TCAVIMMIManagerDelegate>  _multiDelegate;
}

@property (nonatomic, weak) id<TCAVIMMIManagerDelegate> multiDelegate;
@property (nonatomic, readonly) NSMutableArray *multiResource;


// 是否是主屏幕用户
- (BOOL)isMainUserByID:(NSString *)userid;

- (BOOL)hasInteractUsers;

// 是否是互动观众
- (BOOL)isInteractUser:(NSString *)user;

// 查询互动用户
- (BOOL)interactUserOfID:(NSString *)userid;

// 与主屏幕用户进行
- (void)switchAsMainUser:(NSString *)user completion:(TCIFinishBlock)completion;

// 只是注册为主屏幕
- (void)registAsMainUser:(NSString *)user;

// 更新主屏幕用户信息
- (void)changeMainUser:(NSString *)user;

//// for Guest
//// 当收到主播邀请后，将自己托管到TCAVIMMultiManager，并进行连麦操作，渲染管理等
//- (void)registSelfOnRecvInteractRequest;
//
//// for Host
//// 邀请用户加入互动
//- (void)inviteUserJoinInteraction:(NSString *)user;
//
//// for Host/ Interact
//// 主动取消互动，释放资源，并通消息提
//// 主播：可以断开作意user(互动观众)，不能为自己本身
//// 互动观众：只能断开自己user
//- (BOOL)initiativeCancelInteractUser:(NSString *)user;
//
//
//// 主动取消邀请的观众，用户超时不回复邀请或邀请时挂断
//- (BOOL)initiativeCancelInviteUser:(id<AVMultiUserAble>)user;
//
//// for all
//// 主动取消互动后，其他人收到消息，则被动取消
//- (BOOL)forcedCancelInteractUser:(id<AVMultiUserAble>)user;
//
//
//// 请求某个人的视频画面
//- (void)requestViewOf:(id<AVMultiUserAble>)user;
//
//// 请求多个人（id<AVUserAble>）的视频画面
//- (void)requestMultipleViewOf:(NSArray *)users;
//
//// 收到半自动推送时，在界面上添加对应的小窗口进行显示
//- (void)addInteractUserOnRecvSemiAutoVideo:(NSArray *)users;
//
//- (void)enableInteractUser:(id<AVMultiUserAble>)user ctrlState:(AVCtrlState)state;
//- (void)disableInteractUser:(id<AVMultiUserAble>)user ctrlState:(AVCtrlState)state;
//
//- (void)clearAllOnSwitchRoom;

@end


//@interface TCAVIMMIManager (ProtectedMethod)
//
//- (BOOL)addInteractUser:(id<AVMultiUserAble>)user;
//
//@end
//
//
//
//// 用户上麦时，由Guest变为Interact，需要1.先修改权限 2.再修改Role，最后才开Camera/mic
//// 用户下麦时，由Interact变为Guest，需要先关Camera/mic, 1.先修改权限 2.再修改Role
//// 该分类主要处理Role跟权限问题
//// 对应云后端的需要配置三个Role:  Host/Interact/Guest
////
//@interface TCAVIMMIManager (RoleAndAuth)
//
//// 具体与Spear配置相关，请注意设置
//// completion为异步回调，注意内存泄露
//- (void)changeToInteractAuthAndRole:(CommonCompletionBlock)completion;
//
//// 当前是互动观众时，下麦时，使用
//// completion为异步回调，注意内存泄露
//- (void)changeToNormalGuestAuthAndRole:(CommonCompletionBlock)completion;
//
//@end
//
