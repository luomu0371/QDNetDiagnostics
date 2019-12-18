//
//  PNTcpPing.m
//  PhoneNetSDK
//
//  Created by mediaios on 2019/3/11.
//  Copyright © 2019 mediaios. All rights reserved.
//

#import "PNTcpPing.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#include <netinet/in.h>
#include <netinet/tcp.h>

@interface PNTcpPingResult()

- (instancetype)init:(NSString *)ip
                loss:(NSUInteger)loss
               count:(NSUInteger)count
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime;

@end

@implementation PNTcpPingResult

- (instancetype)init:(NSString *)ip
                loss:(NSUInteger)loss
               count:(NSUInteger)count
                 max:(NSTimeInterval)maxTime
                 min:(NSTimeInterval)minTime
                 avg:(NSTimeInterval)avgTime
{
    if (self = [super init]) {
        _ip = ip;
        _loss = loss;
        _count = count;
        _max_time = maxTime;
        _avg_time = avgTime;
        _min_time = minTime;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"TCP conn loss=%lu,  min/avg/max = %.2f/%.2f/%.2fms",(unsigned long)self.loss,self.min_time,self.avg_time,self.max_time];
}

@end


static PNTcpPing *g_tcpPing = nil;
void tcp_conn_handler()
{
    if (g_tcpPing) {
        [g_tcpPing processLongConn];
    }
}


@interface PNTcpPing()
{
    struct sockaddr_in addr;
    struct sockaddr_in6 addr6;
    int sock;
}
@property (nonatomic,readonly) NSString  *host;
@property (nonatomic,readonly) NSUInteger port;
@property (nonatomic,readonly) NSUInteger count;
@property (copy,readonly) PNTcpPingHandler complete;
@property (atomic) BOOL isStop;
@property (nonatomic,assign) BOOL isSucc;

@property (nonatomic,copy) NSMutableString *pingDetails;
@end

@implementation PNTcpPing

- (instancetype)init:(NSString *)host
                port:(NSUInteger)port
               count:(NSUInteger)count
            complete:(PNTcpPingHandler)complete
{
    if (self = [super init]) {
        _host = host;
        _port = port;
        _count = count;
        _complete = complete;
        _isStop = NO;
        _isSucc = YES;
    }
    return self;
}

+ (instancetype)start:(NSString * _Nonnull)host
             complete:(PNTcpPingHandler _Nonnull)complete
{
    return [[self class] start:host port:80 count:3 complete:complete];
}

+ (instancetype)start:(NSString * _Nonnull)host
                 port:(NSUInteger)port
                count:(NSUInteger)count
             complete:(PNTcpPingHandler _Nonnull)complete
{
    PNTcpPing *tcpPing = [[PNTcpPing alloc] init:host port:port count:count complete:complete];
    g_tcpPing = tcpPing;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [tcpPing sendAndRec];
    });
    return tcpPing;
}

- (BOOL)isTcpPing
{
    return !_isStop;
}
- (void)stopTcpPing
{
    _isStop = YES;
}

- (void)sendAndRec
{
    _pingDetails = [NSMutableString stringWithString:@"\n"];
    NSString *ip = [self convertDomainToIp:_host];
    if (ip == NULL) {
        return;
    }
    NSTimeInterval *intervals = (NSTimeInterval *)malloc(sizeof(NSTimeInterval) * _count);
    int index = 0;
    int r = 0;
    int loss = 0;
    do {
        NSDate *t_begin = [NSDate date];
        r = [self connect:&addr];
        NSTimeInterval conn_time = [[NSDate date] timeIntervalSinceDate:t_begin];
        intervals[index] = conn_time * 1000;
        if (r == 0) {
//            NSLog(@"connected to %s:%lu, %f ms\n",inet_ntoa(addr.sin_addr), (unsigned long)_port, conn_time * 1000);
            [_pingDetails appendString:[NSString stringWithFormat:@"conn to %@:%lu,  %.2f ms \n",ip,_port,conn_time * 1000]];
        } else {
            NSLog(@"connect failed to %s:%lu, %f ms, error %d\n",inet_ntoa(addr.sin_addr), (unsigned long)_port, conn_time * 1000, r);
            [_pingDetails appendString:[NSString stringWithFormat:@"connect failed to %s:%lu, %f ms, error %d\n",inet_ntoa(addr.sin_addr), (unsigned long)_port, conn_time * 1000, r]];
            loss++;
        }
//        _complete(_pingDetails);
        if (index <= _count && !_isStop && r == 0) {
            usleep(1000*100);
        }
    } while (++index < _count && !_isStop &&  r == 0);
    
    NSInteger code = r;
    if (_isStop) {
        code = -5;
    }else{
        _isStop = YES;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if (self.isSucc) {
            PNTcpPingResult *pingRes  = [self constPingRes:code ip:ip durations:intervals loss:loss count:index];
            [self.pingDetails appendString:pingRes.description];
        }
        self.complete(self.pingDetails);
        free(intervals);
    });
}


- (void)processLongConn
{
    close(sock);
    _isStop = YES;
    _isSucc = NO;
}

- (int)connect:(struct sockaddr_in *)addr{
    sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == -1) {
        return errno;
    }
    int on = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *)&on, sizeof(on));
    
    struct timeval timeout;
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout));
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout, sizeof(timeout));
    
    sigset(SIGALRM, tcp_conn_handler);
    alarm(1);
    int conn_res = connect(sock, (struct sockaddr *)addr, sizeof(struct sockaddr));
    alarm(0);
    sigrelse(SIGALRM);
    
    if (conn_res < 0) {
        int err = errno;
        close(sock);
        return err;
    }
    close(sock);
    return 0;
}

- (NSString *)convertDomainToIp:(NSString *)host
{
    
    const char *hostaddr = [host UTF8String];
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    if (hostaddr == NULL) {
        hostaddr = "\0";
    }
    addr.sin_addr.s_addr = inet_addr(hostaddr);
    
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent *remoteHost = gethostbyname(hostaddr);
        if (remoteHost == NULL || remoteHost->h_addr == NULL) {
            [_pingDetails appendString:[NSString stringWithFormat:@"access %@ DNS error..\n",host]];
            _complete(_pingDetails);
            return NULL;
        }
        addr.sin_addr = *(struct in_addr *)remoteHost->h_addr;
        return [NSString stringWithFormat:@"%s",inet_ntoa(addr.sin_addr)];
    }
    return host;
}

- (NSString *)convertDomainToIp2:(NSString *)hostName {
    const char* hostnameC = [hostName UTF8String];
    
    struct addrinfo hints, *res;
    struct sockaddr_in *s4;
    struct sockaddr_in6 *s6;
    int retval;
    char buf[64];
    NSMutableArray *result; //the array which will be return
    NSString *previousIP = nil;
    
    memset (&hints, 0, sizeof (struct addrinfo));
    hints.ai_family = PF_UNSPEC;//AF_INET6;
    hints.ai_flags = AI_CANONNAME;
    //AI_ADDRCONFIG, AI_ALL, AI_CANONNAME,  AI_NUMERICHOST
    //AI_NUMERICSERV, AI_PASSIVE, OR AI_V4MAPPED
    
    retval = getaddrinfo(hostnameC, NULL, &hints, &res);
    if (retval == 0) {
        //        if (res->ai_canonname == nil){
        //            result = [NSMutableArray arrayWithObject:[NSString stringWithUTF8String:res->ai_canonname]];
        //        } else {
        //            //it means the DNS didn't know this host
        //            return nil;
        //        }
        result = [NSMutableArray array];
        while (res) {
            switch (res->ai_family){
                case AF_INET6:
                    memset(&addr6, 0, sizeof(addr6));
                    s6 = (struct sockaddr_in6 *)res->ai_addr;
                    memcpy(&addr6, s6, sizeof(addr6));

                    if(inet_ntop(res->ai_family, (void *)&(s6->sin6_addr), buf, sizeof(buf))
                       == NULL) {
                        NSLog(@"inet_ntop failed for v6!\n");
                    } else {
                        //surprisingly every address is in double, let's add this test
                        if (![previousIP isEqualToString:[NSString stringWithUTF8String:buf]]) {
                            [result addObject:[NSString stringWithUTF8String:buf]];
                        }
                    }
                    break;
                    
                case AF_INET:
                    memset(&addr, 0, sizeof(addr));
                    s4 = (struct sockaddr_in *)res->ai_addr;
                    memcpy(&addr, s4, sizeof(addr));
                    if(inet_ntop(res->ai_family, (void *)&(s4->sin_addr), buf, sizeof(buf))
                       == NULL){
                        NSLog(@"inet_ntop failed for v4!\n");
                    } else {
                        //surprisingly every address is in double, let's add this test
                        if (![previousIP isEqualToString:[NSString stringWithUTF8String:buf]]) {
                            [result addObject:[NSString stringWithUTF8String:buf]];
                        }
                    }
                    break;
                default:
                    NSLog(@"Neither IPv4 nor IPv6!");
            }
            
            //surprisingly every address is in double, let's add this test
            previousIP = [NSString stringWithUTF8String:buf];
            res = res->ai_next;
        }
    } else {
        NSLog(@"no IP found");
        return nil;
    }
    
    return result.firstObject;
}

- (PNTcpPingResult *)constPingRes:(NSInteger)code
                               ip:(NSString *)ip
                        durations:(NSTimeInterval *)durations
                             loss:(NSUInteger)loss
                            count:(NSUInteger)count
{
    if (code != 0 && code != -5) {
        return [[PNTcpPingResult alloc] init:ip loss:1 count:1 max:0 min:0 avg:0];
    }
    
    NSTimeInterval max = 0;
    NSTimeInterval min = 10000000;
    NSTimeInterval sum = 0;
    for (int i= 0; i < count; i++) {
        if (durations[i] > max) {
            max = durations[i];
        }
        if (durations[i] < min) {
            min = durations[i];
        }
        sum += durations[i];
    }
    
    NSTimeInterval avg = sum/count;
    return [[PNTcpPingResult alloc] init:ip loss:loss count:count max:max min:min avg:avg];
}

+ (NSMutableArray *)lookupHost:(NSString *)host port:(uint16_t)port
{
    NSMutableArray *addresses = nil;
    
    if ([host isEqualToString:@"localhost"] || [host isEqualToString:@"loopback"])
    {
        // Use LOOPBACK address
        struct sockaddr_in nativeAddr4;
        nativeAddr4.sin_len         = sizeof(struct sockaddr_in);
        nativeAddr4.sin_family      = AF_INET;
        nativeAddr4.sin_port        = htons(port);
        nativeAddr4.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        memset(&(nativeAddr4.sin_zero), 0, sizeof(nativeAddr4.sin_zero));
        
        struct sockaddr_in6 nativeAddr6;
        nativeAddr6.sin6_len        = sizeof(struct sockaddr_in6);
        nativeAddr6.sin6_family     = AF_INET6;
        nativeAddr6.sin6_port       = htons(port);
        nativeAddr6.sin6_flowinfo   = 0;
        nativeAddr6.sin6_addr       = in6addr_loopback;
        nativeAddr6.sin6_scope_id   = 0;
        
        // Wrap the native address structures
        
        NSData *address4 = [NSData dataWithBytes:&nativeAddr4 length:sizeof(nativeAddr4)];
        NSData *address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
        
        addresses = [NSMutableArray arrayWithCapacity:2];
        [addresses addObject:address4];
        [addresses addObject:address6];
    }
    else
    {
        NSString *portStr = [NSString stringWithFormat:@"%hu", port];
        
        struct addrinfo hints, *res, *res0;
        
        memset(&hints, 0, sizeof(hints));
        hints.ai_family   = PF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        hints.ai_protocol = IPPROTO_TCP;
        
        int gai_error = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res0);
        
        if (gai_error)
        {
        }
        else
        {
            NSUInteger capacity = 0;
            for (res = res0; res; res = res->ai_next)
            {
                if (res->ai_family == AF_INET || res->ai_family == AF_INET6) {
                    capacity++;
                }
            }
            
            addresses = [NSMutableArray arrayWithCapacity:capacity];
            
            for (res = res0; res; res = res->ai_next)
            {
                if (res->ai_family == AF_INET)
                {
                    // Found IPv4 address.
                    // Wrap the native address structure, and add to results.
                    
                    NSData *address4 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
                    [addresses addObject:address4];
                }
                else if (res->ai_family == AF_INET6)
                {
                    // Fixes connection issues with IPv6
                    // https://github.com/robbiehanson/CocoaAsyncSocket/issues/429#issuecomment-222477158
                    
                    // Found IPv6 address.
                    // Wrap the native address structure, and add to results.
                    
                    struct sockaddr_in6 *sockaddr = (struct sockaddr_in6 *)res->ai_addr;
                    in_port_t *portPtr = &sockaddr->sin6_port;
                    if ((portPtr != NULL) && (*portPtr == 0)) {
                            *portPtr = htons(port);
                    }

                    NSData *address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
                    [addresses addObject:address6];
                }
            }
            freeaddrinfo(res0);
        }
    }
    
    return addresses;
}
@end
