//
//  TCILiveMsg.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/9/27.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveMsg.h"
#import "TCILiveConst.h"


#ifndef kTCAVCALL_UserAction
#define kTCAVCALL_UserAction        @"userAction"
#endif


#ifndef kTCAVCALL_ActionParam
#define kTCAVCALL_ActionParam       @"actionParam"
#endif

@implementation TCILiveMsg

- (instancetype)initWith:(TIMUserProfile *)sender message:(NSString *)text
{
    if (self = [super init])
    {
        _sender = sender;
        _msgText = text;
        
    }
    return self;
}

- (NSInteger)msgType
{
    return TCILiveCMD_Text;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"sender = %@ name = %@ text = %@", [_sender identifier], [_sender nickname], _msgText];
}

@end

@implementation TCILiveCMD

- (instancetype)initWith:(NSInteger)command
{
    if (self = [super init])
    {
        _userAction = command;
    }
    return self;
}
- (instancetype)initWith:(NSInteger)command param:(NSString *)param
{
    if (self = [super init])
    {
        _userAction = command;
        _actionParam = param;
    }
    return self;
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
                
                TCILiveCMD *cmd = [[TCILiveCMD alloc] init];
                
                cmd.sender = [msg GetSenderProfile];
                
                NSObject *actionNum = [jd objectForKey:kTCAVCALL_UserAction];
                if ([actionNum isKindOfClass:[NSNumber class]])
                {
                    cmd.userAction = [(NSNumber *)actionNum intValue];
                    
                    if (cmd.userAction >= TCILiveCMD_None)
                    {
                        NSObject *actionParamObj = jd[kTCAVCALL_ActionParam];
                        if ([actionParamObj isKindOfClass:[NSString class]])
                        {
                            NSString *actionString = (NSString *)actionParamObj;
                            
                            cmd.actionParam = actionString;
                        }
                        else
                        {
                            return cmd;
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


- (NSData *)packToSendData
{
    NSMutableDictionary *post = [NSMutableDictionary dictionary];
    [post setObject:@(_userAction) forKey:@"userAction"];
    
    if (_actionParam && _actionParam.length > 0)
    {
        [post setObject:_actionParam forKey:@"actionParam"];
    }
    
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

- (TIMMessage *)packToSendMessage
{
    TIMMessage *msg = [[TIMMessage alloc] init];
    
    TIMCustomElem *elem = [[TIMCustomElem alloc] init];
    elem.data = [self packToSendData];
    
    [msg addElem:elem];
    
    
    
    return msg;
}

- (void)prepareForRender
{
    // 因不用于显示，作空实现
    // do nothing
}

- (NSInteger)msgType
{
    return _userAction;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"sender = %@ action = %d", [_sender identifier], (int)_userAction];
}
@end

