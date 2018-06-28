//
//  JSContext+EndoThread.h
//  Endo-iOS
//
//  Created by 崔明辉 on 2018/6/28.
//  Copyright © 2018年 UED Center, YY Inc. All rights reserved.
//

#import <JavaScriptCore/JavaScriptCore.h>

@class EDOObjectReference;

@interface EDOObjectReference: NSObject

@property (nonatomic, readonly) NSObject *value;
@property (nonatomic, strong) JSManagedValue *soManagedValue;

@end

@interface JSContext (EDOThread)

@property (nonatomic, strong) NSMutableDictionary<NSString *, EDOObjectReference *> *references;

- (nonnull JSValue *)edo_createMetaClass:(nonnull NSObject *)anObject;
- (void)edo_storeScriptObject:(nonnull NSObject *)anObject scriptObject:(nonnull JSValue *)scriptObject;
- (nullable id)edo_nsValueWithObjectRef:(nonnull NSString *)objectRef;
- (nullable JSValue *)edo_jsValueWithObject:(nonnull NSObject *)anObject initializer:(nullable id (^)(NSArray *))initializer createIfNeeded:(BOOL)createIfNeeded;
- (void)edo_garbageCollect;

@end