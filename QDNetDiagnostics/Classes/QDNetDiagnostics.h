//
//  QDNetDiagnostics.h
//  QD
//
//  Created by apple on 2018/9/12.
//  Copyright © 2018年 qd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^Callback)(NSString *);

typedef void(^CompleteCallback)(void);


@interface QDNetDiagnostics : NSObject


- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithHostName:(NSString *)hostName NS_DESIGNATED_INITIALIZER;

- (void)startDiagnosticAndNetInfo:(Callback)callback ompleteBlock: (CompleteCallback)completeBlock;

+ (void)startTcpPing:(NSString*)host port:(NSUInteger)port ompleteBlock:(CompleteCallback)completeBlock;
@end
