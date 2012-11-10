//
//  DMMemoize.m
//  DMMemoize
//
//  Created by Jonathon Mah on 2012-11-10.
//  Copyright (c) 2012 Delicious Monster Software. All rights reserved.
//

#import "DMMemoize.h"

#import <objc/runtime.h>


@implementation DMMemoize

+ (id)cachedValueForKey:(id)cacheKey storageOwner:(id)cacheOwner token:(void *)staticToken generator:(id(^)(void))generatorBlock;
{
    static dispatch_once_t onceToken;
    static id nilMarker;
    dispatch_once(&onceToken, ^{
        nilMarker = [NSObject new];
    });

    NSParameterAssert(cacheOwner && staticToken && generatorBlock);
    if (!cacheOwner || !staticToken)
        return nil;

    const id nonNilCacheKey = cacheKey ? : nilMarker;


    NSMapTable *cacheStorage = objc_getAssociatedObject(cacheOwner, staticToken);
    if (!cacheStorage) {
        cacheStorage = [NSMapTable strongToStrongObjectsMapTable];
        objc_setAssociatedObject(cacheOwner, staticToken, cacheStorage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    id cachedValue = [cacheStorage objectForKey:nonNilCacheKey];
    if (!cachedValue) {
        cachedValue = generatorBlock() ? : nilMarker;
        [cacheStorage setObject:cachedValue forKey:nonNilCacheKey];
    }

    return (cachedValue != nilMarker) ? cachedValue : nil;
}

@end
