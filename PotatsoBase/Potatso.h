//
//  PotatsoManager.h
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Potatso : NSObject
+ (NSString * _Nonnull)sharedGroupIdentifier;
+ (NSURL * _Nonnull)sharedUrl;
+ (NSURL * _Nonnull)sharedDatabaseUrl;
+ (NSUserDefaults * _Nonnull)sharedUserDefaults;

+ (NSURL * _Nonnull)sharedGeneralConfUrl;
+ (NSURL * _Nonnull)sharedSocksConfUrl;
+ (NSURL * _Nonnull)sharedProxyConfUrl;
+ (NSURL * _Nonnull)sharedHttpProxyConfUrl;
+ (NSURL * _Nonnull)sharedLogUrl;
@end
