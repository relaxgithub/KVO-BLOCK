//
//  NSObject+RLKVO.h
//  KVO-CC
//
//  Created by relax on 2018/3/23.
//  Copyright © 2018年 relax. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^KVOBlock)(id observer,NSString *keyPath,id oldValue ,id newValue);

@interface NSObject (RLKVO)


- (void)rl_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context withBlock:(KVOBlock)block;

@end
