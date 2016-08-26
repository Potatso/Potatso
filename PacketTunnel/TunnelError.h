//
//  TunnelError.h
//  Potatso
//
//  Created by LEI on 7/21/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TunnelError : NSObject
+ (NSError *)errorWithMessage: (NSString *)message;
@end
