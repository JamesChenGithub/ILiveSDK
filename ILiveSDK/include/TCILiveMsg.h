//
//  TCILiveMsg.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/27.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/TIMFriendshipManager.h>
#import <ImSDK/TIMGroupManager.h>
#import <ImSDK/TIMMessage.h>
// 直播中的消息
@interface TCILiveMsg : NSObject
{
@protected
    TIMUserProfile  *_sender;            // 发送者
    
@protected
    NSString        *_msgText;          // 消息内容
}

@property (nonatomic, readonly) TIMUserProfile *sender;
@property (nonatomic, readonly) NSString *msgText;

- (instancetype)initWith:(TIMUserProfile *)sender message:(NSString *)text;
- (NSInteger)msgType;

@end


// 直播中使用
@interface TCILiveCMD : NSObject

@property (nonatomic, strong) TIMUserProfile *sender;           // 发消息者
@property (nonatomic, assign) NSInteger userAction;             // 命令字，电话命令，必须填写
@property (nonatomic, copy) NSString *actionParam;              // 自定义参数，内部使用Json格式解析

+ (instancetype)parseCustom:(TIMCustomElem *)elem inMessage:(TIMMessage *)msg;
- (instancetype)initWith:(NSInteger)command;
- (instancetype)initWith:(NSInteger)command param:(NSString *)param;


- (NSData *)packToSendData;
- (TIMMessage *)packToSendMessage;
- (NSInteger)msgType;

@end


