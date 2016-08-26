//
//  Settings.h
//  Potatso
//
//  Created by LEI on 7/13/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Settings : NSObject
+ (Settings *)shared;
@property (nonatomic, strong) NSDate *startTime;
@end
