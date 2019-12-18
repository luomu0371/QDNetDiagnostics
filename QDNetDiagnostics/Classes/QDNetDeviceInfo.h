//
//  QDNetDeviceInfo.h
//  QD
//
//  Created by apple on 2018/9/12.
//  Copyright © 2018年 qd. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, NetworkType) {
    NetworkTypeNone,
    NetworkTypeWIFI,
    NetworkTypeWWAN_Unknown,
    NetworkType2G,
    NetworkType3G,
    NetworkType4G,
};


@interface QDNetDeviceInfo : NSObject

/// 根据域名获取IP地址
+ (NSString*)getIPWithHostName:(const NSString*)hostName;

+ (NSArray *)addressesForHostname:(const NSString *)hostName;


/// 获取本机DNS服务器
+ (NSArray *)outPutDNSServers;
+ (NSArray *) getOutPutDNSServers;

/*!
 * 通过hostname获取ip列表 DNS解析地址
 */
+ (NSArray *)getDNSsWithDormain:(NSString *)hostName;

/*!
 * 获取当前设备ip地址
 */
+ (NSArray *)deviceIPAdress;

/*!
 * 获取当前设备网关地址
 */
+ (NSArray *)getGatewayIPAddress;

+ (NSString* )getNetworkType;

@end
