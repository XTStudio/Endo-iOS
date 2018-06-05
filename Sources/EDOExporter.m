//
//  EDOExport.m
//  Endo-iOS
//
//  Created by 崔明辉 on 2018/6/5.
//  Copyright © 2018年 UED Center, YY Inc. All rights reserved.
//

#import <Aspects/Aspects.h>
#import "EDOExporter.h"
#import "EDOExportable.h"
#import "NSObject+EDOObjectRef.h"

@interface EDOObjectReference: NSObject

@property (nonatomic, strong) NSObject *value;
@property (nonatomic, strong) JSManagedValue *metaClassManagedValue;

@end

@implementation EDOObjectReference

- (instancetype)initWithValue:(NSObject *)value {
    self = [super init];
    if (self) {
        _value = value;
    }
    return self;
}

@end

@interface EDOExporter ()

@property (nonatomic, strong) NSDictionary<NSString *, EDOExportable *> *exportables;
@property (nonatomic, strong) NSMutableDictionary<NSString *, EDOObjectReference *> *references;
@property (nonatomic, strong) NSMutableDictionary<NSString *, JSManagedValue *> *scriptObjects;

@end

@implementation EDOExporter

+ (EDOExporter *)sharedExporter {
    static EDOExporter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [EDOExporter new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _exportables = @{};
        _references = [NSMutableDictionary dictionary];
        _scriptObjects = [NSMutableDictionary dictionary];
        [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(runGC) userInfo:nil repeats:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(runGC) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)runGC {
#ifdef DEV
    NSLog(@"[EDOExporter] GC Running.");
#endif
    @synchronized(self) {
        NSDictionary<NSString *, EDOObjectReference *> *copy = self.references.copy;
        for (NSString *key in copy) {
            if (copy[key].metaClassManagedValue.value == nil) {
                [self.references removeObjectForKey:key];
                [self.scriptObjects removeObjectForKey:key];
#ifdef DEV
                NSLog(@"[EDOExporter] %@ object released", key);
#endif
            }
        }
    }
}

- (void)exportWithContext:(JSContext *)context {
    NSMutableString *script = [NSMutableString string];
    [script appendString:@"var _EDO_MetaClass = /** @class */ (function () { function _EDO_MetaClass(classname, objectRef) { this.classname = classname; this.objectRef = objectRef; } return _EDO_MetaClass; }());"];
    [self.exportables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull classKey, EDOExportable * _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *constructorScript = [NSString stringWithFormat:@"function Initializer(){if(arguments[0]instanceof _EDO_MetaClass){this._meta_class=arguments[0]}else{var args=[];for(var key in arguments){args.push(arguments[key])}this._meta_class=ENDO.createInstanceWithNameArgumentsOwner(\"%@\",args,this)}}", classKey];
        NSMutableString *propsScript = [NSMutableString string];
        [obj.exportedProps enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propKey, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
            [propsScript appendFormat:@"Object.defineProperty(Initializer.prototype,\"%@\",{get:function(){return ENDO.valueWithPropertyNameMetaClass(\"%@\",this._meta_class)},set:function(value){ENDO.setValueWithPropertyNameValueMetaClass(\"%@\",value,this._meta_class)},enumerable:true,configurable:true});", propKey, propKey, propKey];
        }];
        NSMutableString *methodScript = [NSMutableString string];
        [obj.bindedMethods enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull methodKey, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *methodName = [methodKey componentsSeparatedByString:@":"].firstObject;
            [methodScript appendFormat:@"Initializer.prototype.layoutSubviews=function(){};Initializer.prototype.__%@=function(){this.%@.apply(this,arguments)};", methodName, methodName];
        }];
        NSString *clazzScript = [NSString stringWithFormat:@"var %@ = /** @class */ (function () { %@ %@ %@ return Initializer; }());",
                                 classKey, constructorScript, propsScript, methodScript];
        [script appendString:clazzScript];
    }];
    context[@"ENDO"] = [EDOExporter sharedExporter];
    [context evaluateScript:script];
}

- (void)exportClass:(Class)clazz name:(NSString *)name {
    EDOExportable *exportable = [[EDOExportable alloc] init];
    exportable.clazz = clazz;
    exportable.name = name;
    NSMutableDictionary *mutableExportables = [self.exportables mutableCopy];
    [mutableExportables setObject:exportable forKey:name];
    self.exportables = mutableExportables.copy;
}

- (void)exportInitializer:(Class)clazz initializer:(EDOInitializer)initializer {
    [self.exportables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, EDOExportable * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.clazz == clazz) {
            obj.initializer = initializer;
        }
    }];
}

- (void)exportProperty:(Class)clazz propName:(NSString *)propName propType:(EDOPropType)propType {
    [self.exportables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, EDOExportable * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.clazz == clazz) {
            NSMutableDictionary *mutableProps = (obj.exportedProps ?: @{}).mutableCopy;
            [mutableProps setObject:@(propType) forKey:propName];
            obj.exportedProps = mutableProps.copy;
        }
    }];
}

- (void)exportStructProperty:(Class)clazz propName:(NSString *)propName structType:(EDOStructType)structType {
    [self.exportables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, EDOExportable * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.clazz == clazz) {
            NSMutableDictionary *mutableProps = (obj.exportedProps ?: @{}).mutableCopy;
            [mutableProps setObject:@(structType) forKey:propName];
            obj.exportedProps = mutableProps.copy;
        }
    }];
}

- (void)bindMethodToJavaScript:(Class)clazz selector:(SEL)aSelector invokingBlock:(nullable EDOBindMethodInvokingBlock)invokingBlock {
    NSString *selectorName = NSStringFromSelector(aSelector);
    [self.exportables enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, EDOExportable * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.clazz == clazz) {
            NSMutableDictionary *bindedMethods = (obj.bindedMethods ?: @{}).mutableCopy;
            if (invokingBlock != nil) {
                [bindedMethods setObject:invokingBlock forKey:selectorName];
            }
            else {
                [bindedMethods setObject:[NSNull null] forKey:selectorName];
            }
            obj.bindedMethods = bindedMethods.copy;
        }
    }];
    [clazz aspect_hookSelector:aSelector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo) {
        if ([aspectInfo.instance isKindOfClass:[NSObject class]]) {
            NSObject *target = aspectInfo.instance;
            if ([target edo_objectRef] != nil) {
                JSValue *scriptObject = self.scriptObjects[target.edo_objectRef].value;
                if (scriptObject != nil) {
                    [scriptObject invokeMethod:[NSString stringWithFormat:@"__%@", [[NSStringFromSelector(aspectInfo.originalInvocation.selector) componentsSeparatedByString:@":"] firstObject]]
                                 withArguments:@[]];
                }
            }
        }
    } error:NULL];
}

- (JSValue *)createInstanceWithName:(NSString *)name arguments:(NSArray *)arguments owner:(JSValue *)owner {
    if ([name isKindOfClass:[NSString class]] && self.exportables[name] != nil) {
        NSObject *newInstance = self.exportables[name].initializer != nil ? self.exportables[name].initializer(arguments) : [self.exportables[name].clazz new];
        return [self createMetaClassWithObject:newInstance context:[JSContext currentContext] owner:owner];
    }
    return nil;
}

- (JSValue *)createMetaClassWithObject:(NSObject *)anObject context:(JSContext *)context owner:(JSValue *)owner {
    if (anObject.edo_objectRef == nil) {
        anObject.edo_objectRef = [[NSUUID UUID] UUIDString];
    }
    EDOObjectReference *objectReference = [[EDOObjectReference alloc] initWithValue:anObject];
    JSValue *objectMetaClass = [context evaluateScript:[NSString stringWithFormat:@"new _EDO_MetaClass(\"%@\", \"%@\")", NSStringFromClass(anObject.class), anObject.edo_objectRef]];
    objectReference.metaClassManagedValue = [[JSManagedValue alloc] initWithValue:objectMetaClass];
    @synchronized(self) {
        [self.references setObject:objectReference forKey:anObject.edo_objectRef];
        if (owner != nil) {
            [self.scriptObjects setObject:[JSManagedValue managedValueWithValue:owner] forKey:anObject.edo_objectRef];
        }
    }
    return objectMetaClass;
}

- (JSValue *)valueWithPropertyName:(NSString *)name metaClass:(JSValue *)metaClass {
    @try {
        NSString *objectRef = [metaClass toDictionary][@"objectRef"];
        Class objectClazz = NSClassFromString([metaClass toDictionary][@"classname"]);
        if ([objectRef isKindOfClass:[NSString class]]) {
            EDOObjectReference *weakRef = self.references[objectRef];
            if ([weakRef isKindOfClass:[EDOObjectReference class]]) {
                NSObject *anObject = weakRef.value;
                if ([anObject isKindOfClass:[NSObject class]]) {
                    for (NSString *key in self.exportables) {
                        if (self.exportables[key].clazz == objectClazz) {
                            NSUInteger propType = [self.exportables[key].exportedProps[name] unsignedIntegerValue];
                            if (propType >= 1000 && propType < 10000) {
                                return [EDOStructValue valueForStructType:propType value:[anObject valueForKey:name]];
                            }
                            break;
                        }
                    }
                    return [anObject valueForKey:name] ?: [JSValue valueWithUndefinedInContext:[JSContext currentContext]];
                }
            }
        }
    } @catch (NSException *exception) { } @finally { }
    return [JSValue valueWithUndefinedInContext:[JSContext currentContext]];
}

- (void)setValueWithPropertyName:(NSString *)name value:(JSValue *)value metaClass:(JSValue *)metaClass {
    @try {
        NSString *objectRef = [metaClass toDictionary][@"objectRef"];
        Class objectClazz = NSClassFromString([metaClass toDictionary][@"classname"]);
        if ([objectRef isKindOfClass:[NSString class]]) {
            EDOObjectReference *weakRef = self.references[objectRef];
            if ([weakRef isKindOfClass:[EDOObjectReference class]]) {
                NSObject *anObject = weakRef.value;
                if ([anObject isKindOfClass:[NSObject class]]) {
                    for (NSString *key in self.exportables) {
                        if (self.exportables[key].clazz == objectClazz) {
                            NSUInteger propType = [self.exportables[key].exportedProps[name] unsignedIntegerValue];
                            if (propType >= 1000 && propType < 10000) {
                                [anObject setValue:[EDOStructValue nsValueForStructType:propType value:value] forKey:name];
                            }
                            else if (propType == EDOPropTypeString && value.isString) {
                                [anObject setValue:value.toString forKey:name];
                            }
                            else if (propType == EDOPropTypeNumber && value.isNumber) {
                                [anObject setValue:value.toNumber forKey:name];
                            }
                            else if (propType == EDOPropTypeBoolean && value.isBoolean) {
                                [anObject setValue:@(value.toBool) forKey:name];
                            }
                            else if (propType == EDOPropTypeArray && value.isArray) {
                                [anObject setValue:value.toArray forKey:name];
                            }
                            else if (propType == EDOPropTypeDictionary && value.isObject) {
                                [anObject setValue:value.toDictionary forKey:name];
                            }
                            else if (value.isUndefined || value.isNull) {
                                [anObject setValue:nil forKey:name];
                            }
                            break;
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) { } @finally { }
}

@end
