//
//  NSError+Helper.m
//  Potatso
//
//  Created by LEI on 3/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "NSError+Helper.h"

@implementation NSError (Helper)

+ (NSError *)errorWithCode: (NSInteger)code description: (NSString *)description {
    return [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end
