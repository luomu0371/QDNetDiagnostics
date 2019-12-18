//
//  QDViewController.m
//  QDNetDiagnostics
//
//  Created by 244514311@qq.com on 09/13/2018.
//  Copyright (c) 2018 244514311@qq.com. All rights reserved.
//

#import "QDViewController.h"
#import "QDNetDiagnostics.h"


@interface QDViewController ()

@property (nonatomic, strong) QDNetDiagnostics *netDiagnostics;
@end

@implementation QDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // device info ping and traceroute
    self.netDiagnostics = [[QDNetDiagnostics alloc] initWithHostName:@"www.apple.com"];

    [self.netDiagnostics startDiagnosticAndNetInfo:^(NSString *info) {
        NSLog(@"%@",info);
    } ompleteBlock:^{
        self.netDiagnostics = [[QDNetDiagnostics alloc] initWithHostName:@"www.baidu.com"];
        [self.netDiagnostics startDiagnosticAndNetInfo:^(NSString *info) {
            NSLog(@"%@",info);
        } ompleteBlock:^{
            [QDNetDiagnostics startTcpPing:@"www.baidu.com" port:8080 ompleteBlock:^{
                
            }];
        }];
    }];
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
