//
//  TCILiveRecordRequest.m
//  ILiveSDK
//
//  Created by AlexiChen on 16/10/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import "TCILiveRecordRequest.h"
#import "TCILiveRoom.h"

@implementation TCILiveRecordRequest

- (instancetype)initWith:(TCILiveRoom *)room record:(AVRecordInfo *)info
{
    if (!info)
    {
        return nil;
    }
    
    if (self = [super init])
    {
        UInt32 roomid = (UInt32)[room avRoomID];
        OMAVRoomInfo *avRoomInfo = [[OMAVRoomInfo alloc] init];
        avRoomInfo.roomId = roomid;
        avRoomInfo.relationId = roomid;
        self.roomInfo = avRoomInfo;
        self.recordInfo = info;
    }
    return self;
}

@end
