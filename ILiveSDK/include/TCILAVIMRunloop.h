//
//  TCILAVIMRunloop.h
//  MsfSDK
//
//  Created by etkmao on 13-6-4.
//  Copyright (c) 2013年 etkmao. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TCILAVIMRunloop : NSObject
{
    NSThread    *_thread;
}

@property (nonatomic, readonly) NSThread *thread;

+ (TCILAVIMRunloop *)sharedAVIMRunloop;
- (void)start;

@end

