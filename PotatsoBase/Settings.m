//
//  Settings.m
//  Potatso
//
//  Created by LEI on 7/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "Settings.h"
#import "Potatso.h"

#define kSettingsKeyStartTime @"startTime"

@interface Settings ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation Settings

+ (Settings *)shared {
    static Settings *settings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settings = [Settings new];
    });
    return settings;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName: [Potatso sharedGroupIdentifier]];
    }
    return self;
}

- (void)setStartTime:(NSDate *)startTime {
    [self.userDefaults setObject:startTime forKey:kSettingsKeyStartTime];
    [self.userDefaults synchronize];
}

- (NSDate *)startTime {
    return [self.userDefaults objectForKey:kSettingsKeyStartTime];
}

@end
