//
//  TCILAVIMRunloop.m
//  MsfSDK
//
//  Created by etkmao on 13-6-4.
//  Copyright (c) 2013年 etkmao. All rights reserved.
//

#import "TCILAVIMRunloop.h"
#include <sys/time.h>
#import <UIKit/UIDevice.h>
#import "TCILiveConst.h"


@implementation TCILAVIMRunloop

static void AVIMSourceEvent(void* info __unused)
{
    // NSLog(@"MSFRunloop source perform");
    // do nothing
}

- (void)dealloc
{
    TCILDebugLog(@"%@ [%@] Release", self, [TCILAVIMRunloop class]);
}

static TCILAVIMRunloop *_sharedRunLoop = nil;


+ (TCILAVIMRunloop *)sharedAVIMRunloop
{
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        _sharedRunLoop = [[TCILAVIMRunloop alloc] init];
    });
    
    return _sharedRunLoop;
}

- (id)init
{
    if(self = [super init])
    {
        [self start];
    }
    return self;
}

- (void)runloopThreadEntry
{
    NSAssert(![NSThread isMainThread], @"runloopThread error");
    CFRunLoopSourceRef source;
    CFRunLoopSourceContext sourceContext;
    bzero(&sourceContext, sizeof(sourceContext));
    sourceContext.perform = AVIMSourceEvent;
    source = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    
    while (YES)
    {
        [[NSRunLoop currentRunLoop] run];
    }
}

- (void)start
{
    if(_thread)
    {
        return;
    }
    
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(runloopThreadEntry) object:nil];
    
    [_thread setName:@"TCILAVIMMsgHandleThread"];
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
    {
        // 设置成最低优先级，以保证AV正常
        [_thread setQualityOfService:NSQualityOfServiceUtility];
    }
    else
    {
        [_thread setThreadPriority:1.0];
    }
    [_thread start];
}


@end


