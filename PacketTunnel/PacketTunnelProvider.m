//
//  PacketTunnelProvider.m
//  PacketTunnel
//
//  Created by LEI on 12/13/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

#import "PacketTunnelProvider.h"
#import "ProxyManager.h"
#import "TunnelInterface.h"
#import "TunnelError.h"
#import "dns.h"
#import "PotatsoBase.h"
#import <sys/syslog.h>
#import <ShadowPath/ShadowPath.h>
#import <sys/socket.h>
#import <arpa/inet.h>
@import MMWormhole;
@import CocoaAsyncSocket;

#define REQUEST_CACHED @"requestsCached"    // Indicate that recent requests need update

@interface PacketTunnelProvider () <GCDAsyncSocketDelegate>
@property (nonatomic) MMWormhole *wormhole;
@property (nonatomic) GCDAsyncSocket *statusSocket;
@property (nonatomic) GCDAsyncSocket *statusClientSocket;
@property (nonatomic) BOOL didSetupHockeyApp;
@property (nonatomic) NWPath *lastPath;
@property (strong) void (^pendingStartCompletion)(NSError *);
@property (strong) void (^pendingStopCompletion)(void);
@end


@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *))completionHandler {
    [self openLog];
    NSLog(@"starting potatso tunnel...");
    [self updateUserDefaults];
    NSError *error = [TunnelInterface setupWithPacketTunnelFlow:self.packetFlow];
    if (error) {
        completionHandler(error);
        exit(1);
        return;
    }
    self.pendingStartCompletion = completionHandler;
    [self startProxies];
    [self startPacketForwarders];
    [self setupWormhole];
}

- (void)updateUserDefaults {
    [[Potatso sharedUserDefaults] removeObjectForKey:REQUEST_CACHED];
    [[Potatso sharedUserDefaults] synchronize];
    [[Settings shared] setStartTime:[NSDate date]];
}

- (void)setupWormhole {
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier: [Potatso sharedGroupIdentifier] optionalDirectory:@"wormhole"];
    __weak typeof(self) weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:@"getTunnelStatus" listener:^(id  _Nullable messageObject) {
        [weakSelf.wormhole passMessageObject:@"ok" identifier:@"tunnelStatus"];
    }];
    [self.wormhole listenForMessageWithIdentifier:@"stopTunnel" listener:^(id  _Nullable messageObject) {
        [weakSelf stop];
    }];
    [self.wormhole listenForMessageWithIdentifier:@"getTunnelConnectionRecords" listener:^(id  _Nullable messageObject) {
        NSMutableArray *records = [NSMutableArray array];
        struct log_client_states *p = log_clients;
        while (p) {
            struct client_state *client = p->csp;
            NSMutableDictionary *d = [NSMutableDictionary dictionary];
            char *url = client->http->url;
            if (url ==  NULL) {
                p = p->next;
                continue;
            }
            d[@"url"] = [NSString stringWithCString:url encoding:NSUTF8StringEncoding];
            d[@"method"] = @(client->http->gpc);
            for (int i=0; i < TIME_STAGE_COUNT; i++) {
                d[[NSString stringWithFormat:@"time%d", i]] = @(client->time_stages[i]);
            }
            d[@"version"] = @(client->http->ver);
            if (client->rule) {
                d[@"rule"] = [NSString stringWithCString:client->rule encoding:NSUTF8StringEncoding];
            }
            d[@"global"] = @(global_mode);
            d[@"routing"] = @(client->routing);
            d[@"forward_stage"] = @(client->current_forward_stage);
            if (client->http->remote_host_ip_addr_str) {
                d[@"ip"] = [NSString stringWithCString:client->http->remote_host_ip_addr_str encoding:NSUTF8StringEncoding];
            }
            d[@"responseCode"] = @(client->http->status);
            [records addObject:d];
            p = p->next;
        }
        NSString *result = [records jsonString];
        [weakSelf.wormhole passMessageObject:result identifier:@"tunnelConnectionRecords"];
    }];
    [self setupStatusSocket];
}

- (void)setupStatusSocket {
    NSError *error;
    self.statusSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    [self.statusSocket acceptOnInterface:@"127.0.0.1" port:0 error:&error];
    [self.statusSocket performBlock:^{
        int port = sock_port(self.statusSocket.socket4FD);
        [[Potatso sharedUserDefaults] setObject:@(port) forKey:@"tunnelStatusPort"];
        [[Potatso sharedUserDefaults] synchronize];
    }];
}

- (void)startProxies {
    [self startShadowsocks];
    [self startHttpProxy];
    [self startSocksProxy];
}

- (void)syncStartProxy: (NSString *)name completion: (void(^)(dispatch_group_t g, NSError **proxyError))handler {
    dispatch_group_t g = dispatch_group_create();
    __block NSError *proxyError;
    dispatch_group_enter(g);
    handler(g, &proxyError);
    long res = dispatch_group_wait(g, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 2));
    if (res != 0) {
        proxyError = [TunnelError errorWithMessage:@"timeout"];
    }
    if (proxyError) {
        NSLog(@"start proxy: %@ error: %@", name, [proxyError localizedDescription]);
        exit(1);
        return;
    }
}

- (void)startShadowsocks {
    [self syncStartProxy: @"shadowsocks" completion:^(dispatch_group_t g, NSError *__autoreleasing *proxyError) {
        [[ProxyManager sharedManager] startShadowsocks:^(int port, NSError *error) {
            *proxyError = error;
            dispatch_group_leave(g);
        }];
    }];
}

- (void)startHttpProxy {
    [self syncStartProxy: @"http" completion:^(dispatch_group_t g, NSError *__autoreleasing *proxyError) {
        [[ProxyManager sharedManager] startHttpProxy:^(int port, NSError *error) {
            *proxyError = error;
            dispatch_group_leave(g);
        }];
    }];
}

- (void)startSocksProxy {
    [self syncStartProxy: @"socks" completion:^(dispatch_group_t g, NSError *__autoreleasing *proxyError) {
        [[ProxyManager sharedManager] startSocksProxy:^(int port, NSError *error) {
            *proxyError = error;
            dispatch_group_leave(g);
        }];
    }];
}

- (void)startPacketForwarders {
    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTun2SocksFinished) name:kTun2SocksStoppedNotification object:nil];
    [self startVPNWithOptions:nil completionHandler:^(NSError *error) {
        if (error == nil) {
            [weakSelf addObserver:weakSelf forKeyPath:@"defaultPath" options:NSKeyValueObservingOptionInitial context:nil];
            [TunnelInterface startTun2Socks:[ProxyManager sharedManager].socksProxyPort];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [TunnelInterface processPackets];
            });
        }
        if (weakSelf.pendingStartCompletion) {
            weakSelf.pendingStartCompletion(error);
            weakSelf.pendingStartCompletion = nil;
        }
    }];
}

- (void)startVPNWithOptions:(NSDictionary *)options completionHandler:(void (^)(NSError *error))completionHandler {
    NSString *generalConfContent = [NSString stringWithContentsOfURL:[Potatso sharedGeneralConfUrl] encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *generalConf = [generalConfContent jsonDictionary];
    NSString *dns = generalConf[@"dns"];
    NEIPv4Settings *ipv4Settings = [[NEIPv4Settings alloc] initWithAddresses:@[@"192.0.2.1"] subnetMasks:@[@"255.255.255.0"]];
    NSArray *dnsServers;
    if (dns.length) {
        dnsServers = [dns componentsSeparatedByString:@","];
        NSLog(@"custom dns servers: %@", dnsServers);
    }else {
        dnsServers = [DNSConfig getSystemDnsServers];
        NSLog(@"system dns servers: %@", dnsServers);
    }
    ipv4Settings.includedRoutes = @[[NEIPv4Route defaultRoute]];
    NEPacketTunnelNetworkSettings *settings = [[NEPacketTunnelNetworkSettings alloc] initWithTunnelRemoteAddress:@"192.0.2.2"];
    settings.IPv4Settings = ipv4Settings;
    settings.MTU = @(TunnelMTU);
    NEProxySettings* proxySettings = [[NEProxySettings alloc] init];
    NSInteger proxyServerPort = [ProxyManager sharedManager].httpProxyPort;
    NSString *proxyServerName = @"localhost";

    proxySettings.HTTPEnabled = YES;
    proxySettings.HTTPServer = [[NEProxyServer alloc] initWithAddress:proxyServerName port:proxyServerPort];
    proxySettings.HTTPSEnabled = YES;
    proxySettings.HTTPSServer = [[NEProxyServer alloc] initWithAddress:proxyServerName port:proxyServerPort];
    proxySettings.excludeSimpleHostnames = YES;
    settings.proxySettings = proxySettings;
    NEDNSSettings *dnsSettings = [[NEDNSSettings alloc] initWithServers:dnsServers];
    dnsSettings.matchDomains = @[@""];
    settings.DNSSettings = dnsSettings;
    [self setTunnelNetworkSettings:settings completionHandler:^(NSError * _Nullable error) {
        if (error) {
            if (completionHandler) {
                completionHandler(error);
            }
        }else{
            if (completionHandler) {
                completionHandler(nil);
            }
        }
    }];
}

- (void)openLog {
    NSString *logFilePath = [Potatso sharedLogUrl].path;
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "w+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "w+", stderr);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"defaultPath"]) {
        if (self.defaultPath.status == NWPathStatusSatisfied && ![self.defaultPath isEqualToPath:self.lastPath]) {
            if (!self.lastPath) {
                self.lastPath = self.defaultPath;
            }else {
                NSLog(@"received network change notifcation");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self startVPNWithOptions:nil completionHandler:nil];
                });
            }
        }else {
            self.lastPath = self.defaultPath;
        }
    }
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler
{
	// Add code here to start the process of stopping the tunnel
    self.pendingStopCompletion = completionHandler;
    [self stop];
}

- (void)stop {
    NSLog(@"stoping potatso tunnel...");
    [[Potatso sharedUserDefaults] setObject:@(0) forKey:@"tunnelStatusPort"];
    [[Potatso sharedUserDefaults] synchronize];
    [[ProxyManager sharedManager] stopHttpProxy];
    [[ProxyManager sharedManager] stopSocksProxy];
    [TunnelInterface stop];
}

- (void)onTun2SocksFinished {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.pendingStopCompletion) {
        self.pendingStopCompletion();
        self.pendingStopCompletion = nil;
    }
    [self cancelTunnelWithError:nil];
    exit(EXIT_SUCCESS);
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData *))completionHandler {
    if (completionHandler != nil) {
        completionHandler(nil);
    }
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    NSLog(@"sleeping potatso tunnel...");
	completionHandler();
}

- (void)wake {
    NSLog(@"waking potatso tunnel...");
}

#pragma mark - GCDAsyncSocket Delegate 

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    self.statusClientSocket = newSocket;
}


@end
