//
//  ProjectWindowName.h
//  ProjectWindowName
//
//  Created by Simeon Leifer on 10/2/14.
//  Copyright (c) 2014 Simeon Leifer. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface ProjectWindowName : NSObject

+ (instancetype)sharedPlugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@end