//
//  ViewController.m
//  KVO-CC
//
//  Created by relax on 2018/3/23.
//  Copyright © 2018年 relax. All rights reserved.
//

#import "ViewController.h"
#import "RLPerson.h"
#import "NSObject+RLKVO.h"

@interface ViewController ()



@end

@implementation ViewController {
    RLPerson *_person;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _person = [RLPerson new];
    _person.name = @"李四";
    [_person rl_addObserver:self forKeyPath:@"name" options:(NSKeyValueObservingOptionNew) context:nil withBlock:^(id observer, NSString *keyPath, id oldValue, id newValue) {
        NSLog(@"keyPath : %@ oldValue: %@ newValue : %@",keyPath,oldValue,newValue);
    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _person.name = [NSString stringWithFormat:@"%@-",_person.name];
}

@end


@implementation NSDictionary (log)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *strM = [NSMutableString string];
    [strM appendString:@"{\n"];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [strM appendFormat:@"\t%@=%@,\n",key,obj];
    }];
    [strM appendString:@"\n}"];
    
    return strM.copy;
}

@end
