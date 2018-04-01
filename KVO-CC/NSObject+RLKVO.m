//
//  NSObject+RLKVO.m
//  KVO-CC
//
//  Created by relax on 2018/3/23.
//  Copyright © 2018年 relax. All rights reserved.
//

#import "NSObject+RLKVO.h"
#import <objc/message.h>


// 用来保存传递进来的 KVO 回调 block。
// typedef void(^KVOBlock)(id observer,NSString *keyPath,id oldValue ,id newValue);
@interface RLKVO_Info : NSObject

@property (nonatomic,copy) KVOBlock block;
@property (nonatomic,weak) NSObject *observer; // 保存观察者
@property (nonatomic,copy) NSString *keyPath;

- (instancetype)initWithObserver:(NSObject *)observer block:(KVOBlock)block keypath:(NSString *)keyPath ;

@end


@implementation RLKVO_Info

- (instancetype)initWithObserver:(NSObject *)observer block:(KVOBlock)block keypath:(NSString *)keyPath {
    if (self = [super init]) {
        self.observer = observer;
        self.block = block;
        self.keyPath = keyPath;
    }
    
    return self;
}

@end

static NSString *const infoArrayPro = @"infoArrayPro";

@implementation NSObject (RLKVO)

- (void)rl_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context withBlock:(KVOBlock)block {
    // 周全的 keyPath 防异常 setter
    NSString *setterName = setterFormat(keyPath);
    SEL sel = NSSelectorFromString(setterName);
    // 这里获取 method 的意义在于，可以方便的获取当前方法的 EncodingType 一遍在添加方法class_addMethod的时候，可以设置 EncodingType.
    Method setterMethod = class_getInstanceMethod([self class], sel);
    
    if (!setterMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%@ have not %@ method",[self class],setterName] userInfo:nil];
    }
    
    
    NSString *superClassName = NSStringFromClass([self class]);
    const char *type = method_getTypeEncoding(setterMethod); // 通过方法结果提，拿到方法编码。EncodingType
    
    // 动态创建类
    Class newClass = [self createClassFromSuperName:superClassName sel:sel encodingType:type];
    
    // 替换当前 self 的 isa 指针
    object_setClass(self, newClass);
    
    // 保存信息
    RLKVO_Info *info = [[RLKVO_Info alloc] initWithObserver:observer block:block keypath:keyPath];
    
    NSMutableArray *infoArray = objc_getAssociatedObject(self, &infoArrayPro);
    if (!infoArray) {
        infoArray = [NSMutableArray array];
        objc_setAssociatedObject(self, &infoArrayPro, infoArray, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    [infoArray addObject:info];
    
    
}


/**
 根据父类创建子类
 
 @param superName 父类类型字符串
 @param sel 父类当前方法的 sel
 @param encodingType  父类当前方法的 EncodingType
 @return  返回以当前父类创建的新类。
 */
- (Class)createClassFromSuperName:(NSString *)superName sel:(SEL)sel encodingType:(const char *)encodingType {
    
    NSString *newClassName =  [NSString stringWithFormat:@"RLKVO_%@",
                               NSStringFromClass([self class])];
    Class cls = NSClassFromString(newClassName);
    Class newClass = nil;
    if (!cls) {
        newClass = objc_allocateClassPair(
                                                NSClassFromString(superName), // 当前类的基类
                                                [NSString stringWithFormat:@"RLKVO_%@",
                                                 NSStringFromClass([self class])].UTF8String,// 类名
                                                0);

    }
    
    // 创建一个类.
//    Class newClass = objc_allocateClassPair(
//                                            NSClassFromString(superName), // 当前类的基类
//                                            [NSString stringWithFormat:@"RLKVO_%@",
//                                             NSStringFromClass([self class])].UTF8String,// 类名
//                                            0);
    
    
    // const char *types = method_getTypeEncoding(class_getInstanceMethod(NSClassFromString(superName), @selector(class)));
    
    // 往新类中添加方法
    class_addMethod(newClass, sel, (IMP)kvoSetter, encodingType);
    
    
    // 类创建完毕之后，注册到 runtime
    objc_registerClassPair(newClass);
    
    
    // 返回这个新类。
    return newClass;
}

#pragma mark - 函数区域
// 使用 class_addMethod runtime 添加方法。
void kvoSetter(id self,SEL _cmd,id newValue) {
    // 拿到 setter
    NSString *setterName = NSStringFromSelector(_cmd);
    // 根据 setter 拿到 getter
    NSString *getterName = getterFormat(setterName);
    
    id oldValue = [self valueForKey:getterName];
    
    if (!getterName) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"getter 方法不存在" userInfo: nil];
    }
    
    // 手动开启 KVO
    [self willChangeValueForKey:getterName];
    // 调用父类的方法。
    // 定义一个函数指针
    void(*objc_msgSendRLKVO)(void *,SEL ,id) = (void *)objc_msgSendSuper;
    
    struct objc_super superClassStruct = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    objc_msgSendRLKVO(&superClassStruct,_cmd,newValue);
    
    [self didChangeValueForKey:getterName];
    
    
    //
    
    NSMutableArray *infoArrM = objc_getAssociatedObject(self, &infoArrayPro);
    if (infoArrM) {
        [infoArrM enumerateObjectsUsingBlock:^(RLKVO_Info *info, NSUInteger idx, BOOL * _Nonnull stop) {
            info.block(info.observer, info.keyPath, oldValue, newValue);
        }];
    }
}

static NSString * setterFormat(NSString *keyPath) {
    if (keyPath.length <= 0) {
        return nil;
    }
    
    NSString *firstStr = [keyPath substringToIndex:1].uppercaseString;
    NSString *leaveStr = [keyPath substringFromIndex:1];
    
    return [NSString stringWithFormat:@"set%@%@:",firstStr,leaveStr];
}

static NSString * getterFormat(NSString *setter) {
    // setName -> name
    NSString *getter = [[setter stringByReplacingOccurrencesOfString:@"set" withString:@""]
                            stringByReplacingOccurrencesOfString:@":" withString:@""];
    
    return getter.lowercaseString;
}




@end
