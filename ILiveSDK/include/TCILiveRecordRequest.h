//
//  TCILiveRecordRequest.h
//  ILiveSDK
//
//  Created by AlexiChen on 16/10/9.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImSDK/IMSdkComm.h>

@class TCILiveRoom;

@interface TCILiveRecordRequest : NSObject

@property (nonatomic, strong) OMAVRoomInfo *roomInfo;   // 房间信息

@property (nonatomic, strong) AVRecordInfo *recordInfo;  // 录制参数

@property (nonatomic, strong) NSArray *recordFileIds;   // 录制结束后，调用停止成功后，才会返回的fileID

- (instancetype)initWith:(TCILiveRoom *)room record:(AVRecordInfo *)info;

@end

