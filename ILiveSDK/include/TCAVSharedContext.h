//
//  TCAVSharedContext.h
//  TCShow
//
//  Created by AlexiChen on 16/5/24.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCILiveConst.h"
#import <QAVSDK/QAVContext.h>
#import <ImSDK/TIMComm.h>

// 当用户量较大时，用户长时间使用直播场景时，用户每次进入直播的时候，如果重新创建context，会去拉取配置，导致进入房间变慢
// 新增TCAVSharedContext，方便处理上面的逻辑，添加kIsUseAVSDKAsLiveScene ＝ 1在TCAVBaseRoomEngine不再重复创建context

@interface TCAVSharedContext : NSObject
{
@protected
    QAVContext      *_sharedContext;
}

// 防止因configWith创建context不成功时，为保留现有逻辑不变，则在原有TCAVBaseRoomEngine中添加
+ (QAVContext *)sharedContext;

// 防止因configWith创建context不成功时，为保留现有逻辑不变，则在原有TCAVBaseRoomEngine中添加
+ (void)configContextWith:(TIMLoginParam *)login completion:(TCIRoomBlock)block;

+ (void)destroyContextCompletion:(TCIVoidBlock)block;

@end

