//
//  QDNetDiagnostics.m
//  QD
//
//  Created by apple on 2018/9/12.
//  Copyright © 2018年 qd. All rights reserved.
//

#import "QDNetDiagnostics.h"
#import "QDNetDeviceInfo.h"
#import "QDNetServerProtocol.h"
#import "PNTcpPing.h"

#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>


@interface QDNetDiagnostics()

@property (nonatomic, strong) NSString *hostName;
@property (nonatomic, strong) id<QDNetServerProtocol> ping;
@property (nonatomic, strong) id<QDNetServerProtocol> traceroute;
@property (nonatomic, copy) Callback callback;
@property (nonatomic, copy) Callback pingCallback;
@property (nonatomic, copy) Callback tracerouteCallback;

@property (nonatomic, copy) CompleteCallback ompleteBlock;
@end

@implementation QDNetDiagnostics

- (instancetype)initWithHostName:(NSString *)hostName{
    self = [super init];
    if (self) {
        self.hostName = hostName;
        self.ping = [[NSClassFromString(@"QDPing") alloc] initWithHostName:hostName];
        self.traceroute = [[NSClassFromString(@"QDTraceroute") alloc] initWithHostName:hostName];
    }
    return self;
}

- (void)startDiagnosticAndNetInfo:(Callback)callback ompleteBlock: (CompleteCallback)completeBlock {
    self.callback = callback;
    self.ompleteBlock = completeBlock;

    callback(@"begin diagnostics");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];
        NSString *appName = [dicBundle objectForKey:@"CFBundleDisplayName"];
        
        NSString *appVersion = [dicBundle objectForKey:@"CFBundleShortVersionString"];
        
        UIDevice *device = [UIDevice currentDevice];
        
        NSString *carrierName;
        NSString *isoCountryCode;
        NSString *mobileCountryCode;
        NSString *mobileNetworkCode;
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netInfo subscriberCellularProvider];
        if (carrier != NULL) {
            carrierName = [carrier carrierName];
            isoCountryCode = [carrier isoCountryCode];
            mobileCountryCode = [carrier mobileCountryCode];
            mobileNetworkCode = [carrier mobileNetworkCode];
        } else {
            carrierName = @"";
            isoCountryCode = @"";
            mobileCountryCode = @"";
            mobileNetworkCode = @"";
        }
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"appName：%@",appName]);
            callback([NSString stringWithFormat:@"appVersion：%@",appVersion]);
            callback([NSString stringWithFormat:@"systemName: %@", [device systemName]]);
            callback([NSString stringWithFormat:@"systemVersion: %@", [device systemVersion]]);

            callback([NSString stringWithFormat:@"carrierName: %@", carrierName]);
            callback([NSString stringWithFormat:@"isoCountryCode: %@", isoCountryCode]);
            callback([NSString stringWithFormat:@"mobileCountryCode: %@", mobileCountryCode]);
            callback([NSString stringWithFormat:@"mobileNetworkCode: %@", mobileNetworkCode]);

        });
        
        
        NSString *netType = [QDNetDeviceInfo getNetworkType];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"NetworkType：%@", netType]);
        });

        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"hostName：%@",self.hostName]);
        });
        
        NSArray *ipArray = [QDNetDeviceInfo addressesForHostname:self.hostName];
        NSString* ipStr = [ipArray componentsJoinedByString:@", "];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"HOST to IP：%@", ipStr]);
        });
        
        NSArray* localIPArray = [QDNetDeviceInfo deviceIPAdress];
        ipStr = [localIPArray componentsJoinedByString:@", "];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"本地IP：%@", ipStr]);
        });
        
        NSArray* gatewayIpArray = [QDNetDeviceInfo getGatewayIPAddress];
        NSString* gatewayIp = [gatewayIpArray componentsJoinedByString:@", "];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"本地网关：%@", gatewayIp]);
        });

        
        NSArray *dnsArray = [QDNetDeviceInfo outPutDNSServers];
        NSString* dns = [dnsArray componentsJoinedByString:@", "];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"本地DNS ：%@", dns]);
        });
        
        dnsArray = [QDNetDeviceInfo getOutPutDNSServers];
        dns = [dnsArray componentsJoinedByString:@", "];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"本地DNS2：%@", dns]);
        });
        
        dnsArray = [QDNetDeviceInfo getDNSsWithDormain: self.hostName];
        dns = [dnsArray componentsJoinedByString:@", "];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            callback([NSString stringWithFormat:@"通过域名 DNS解析结果：%@", dns]);
        });
                
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self.ping startNetServerAndCallback:^(NSString *info, NSInteger flag) {
                if (flag == InfoFlagEnd) {
                    [self.traceroute startNetServerAndCallback:^(NSString *info_also, NSInteger flag) {
                        self.callback(info_also);
                        if (flag == InfoFlagEnd) {
                            callback(@"end diagnostics");
                            self.ompleteBlock();
                            [self stop];
                        }
                    }];
                }
                
                self.callback(info);
                
            }];
        });
    });
}

- (void)startPingAndCallback:(Callback) callback {
    self.pingCallback = callback;
    [self.ping startNetServerAndCallback:^(NSString *info, NSInteger flag) {
        if (flag == InfoFlagOn) {
            self.pingCallback(info);
        }else {
            self.pingCallback(info);
            [self stop];
        }
    }];
}

- (void)startTracerouteAndCallback:(Callback) callback {
    self.tracerouteCallback = callback;
    [self.traceroute startNetServerAndCallback:^(NSString *info, NSInteger flag) {
        if (flag == InfoFlagOn) {
            self.tracerouteCallback(info);
        }else {
            self.tracerouteCallback(info);
            [self stop];
        }
    }];
}

- (void)stop {
    self.ping = nil;
    self.traceroute = nil;
    self.callback = nil;
    self.pingCallback = nil;
    self.tracerouteCallback = nil;
    self.ompleteBlock = nil;
}

+ (void)startTcpPing:(NSString*)host port:(NSUInteger)port ompleteBlock:(CompleteCallback)completeBlock {
    [PNTcpPing start:host port:port count:5 complete:^(NSMutableString *info) {
        NSLog(@"TCP:%@", info);
    }];
}
@end
