//
//  EDOExport.h
//  Endo-iOS
//
//  Created by PonyCui on 2018/6/5.
//  Copyright © 2018年 UED Center, YY Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "NSObject+EDOObjectRef.h"

typedef id(^EDOInitializer)(NSArray *arguments);

#define EDO_EXPORT_CLASS(A, B) [[EDOExporter sharedExporter] exportClass:[self class] name:A superName:B];
#define EDO_EXPORT_INITIALIZER(BLOCK) [[EDOExporter sharedExporter] exportInitializer:[self class] initializer:^id(NSArray *arguments) BLOCK ];
#define EDO_EXPORT_CONST(A, B) [[EDOExporter sharedExporter] exportConst:A value:B];
#define EDO_EXPORT_PROPERTY(A) [[EDOExporter sharedExporter] exportProperty:[self class] propName:A readonly:NO];
#define EDO_EXPORT_STATIC_PROPERTY(A) [[EDOExporter sharedExporter] exportStaticProperty:[self class] propName:A readonly:NO];
#define EDO_EXPORT_READONLY_PROPERTY(A) [[EDOExporter sharedExporter] exportProperty:[self class] propName:A readonly:YES];
#define EDO_EXPORT_STATIC_READONLY_PROPERTY(A) [[EDOExporter sharedExporter] exportStaticProperty:[self class] propName:A readonly:YES];
#define EDO_BIND_METHOD(A) [[EDOExporter sharedExporter] bindMethodToJavaScript:[self class] selector:@selector(A)];
#define EDO_EXPORT_METHOD(A) [[EDOExporter sharedExporter] exportMethodToJavaScript:[self class] selector:@selector(A)];
#define EDO_EXPORT_METHOD_ALIAS(A, B) [[EDOExporter sharedExporter] exportMethodToJavaScript:[self class] selector:@selector(A) jsName:B];
#define EDO_EXPORT_STATIC_METHOD(A) [[EDOExporter sharedExporter] exportStaticMethodToJavaScript:[self class] selector:@selector(A)];
#define EDO_EXPORT_STATIC_METHOD_ALIAS(A, B) [[EDOExporter sharedExporter] exportStaticMethodToJavaScript:[self class] selector:@selector(A) jsName:B];
#define EDO_EXPORT_SCRIPT(A) [[EDOExporter sharedExporter] exportScriptToJavaScript:[self class] script:A isInnerScript:YES];
#define EDO_EXPORT_GLOBAL_SCRIPT(A) [[EDOExporter sharedExporter] exportScriptToJavaScript:[self class] script:A isInnerScript:NO];

@protocol EDOJSExport <JSExport>

- (NSString *)createInstanceWithName:(NSString *)name arguments:(NSArray *)arguments owner:(JSValue *)owner;
- (JSValue *)valueWithPropertyName:(NSString *)name owner:(JSValue *)owner;
- (void)setValueWithPropertyName:(NSString *)name value:(JSValue *)value owner:(JSValue *)owner;
- (JSValue *)callMethodWithName:(NSString *)name arguments:(NSArray *)arguments owner:(JSValue *)owner;
- (void)addListenerWithName:(NSString *)name owner:(JSValue *)owner;

@end

@class EDOExportable;

@interface EDOExporter : NSObject<EDOJSExport>

@property (nonatomic, readonly) NSDictionary<NSString *, EDOExportable *> *exportables;

+ (EDOExporter *)sharedExporter;

- (void)exportWithContext:(nonnull JSContext *)context;
- (void)exportEnum:(nonnull NSString *)name values:(nonnull NSDictionary *)values;
- (void)exportConst:(nonnull NSString *)name value:(nonnull id)value;
- (void)exportClass:(Class)clazz name:(nonnull NSString *)name superName:(nullable NSString *)superName;
- (void)exportInitializer:(Class)clazz initializer:(nonnull EDOInitializer)initializer;
- (void)exportProperty:(Class)clazz propName:(nonnull NSString *)propName readonly:(BOOL)readonly;
- (void)exportStaticProperty:(Class)clazz propName:(nonnull NSString *)propName readonly:(BOOL)readonly;
- (void)bindMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector;
- (void)bindMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector isBefore:(BOOL)isBefore;
- (void)exportMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector;
- (void)exportMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector jsName:(nullable NSString *)jsName;
- (void)exportStaticMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector;
- (void)exportStaticMethodToJavaScript:(Class)clazz selector:(nonnull SEL)aSelector jsName:(nullable NSString *)jsName;
- (void)exportScriptToJavaScript:(Class)clazz script:(nonnull NSString *)script isInnerScript:(BOOL)isInnerScript;
- (nullable id)nsValueWithJSValue:(nonnull JSValue *)value;
- (nullable id)nsValueWithObjectRef:(nonnull NSString *)objectRef;
- (void)createScriptObjectIfNeed:(nonnull NSObject *)anObject
                         context:(nonnull JSContext *)context
                     initializer:(nullable id (^)(NSArray *, BOOL))initializer
                  createIfNeeded:(BOOL)createdIfNeed;
- (nullable JSValue *)scriptObjectWithObject:(nonnull NSObject *)anObject
                                     context:(nonnull JSContext *)context
                                 initializer:(nullable id (^)(NSArray *, BOOL))initializer
                              createIfNeeded:(BOOL)createdIfNeed;
- (nonnull NSArray<JSValue *> *)scriptObjectsWithObject:(nonnull NSObject *)anObject;

@end
