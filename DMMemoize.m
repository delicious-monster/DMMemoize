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
    static dispatch_semaphore_t globalMutex; // locked while looking up or creating the per-owner mutex
    static id nilMarker;
    dispatch_once(&onceToken, ^{
        globalMutex = dispatch_semaphore_create(1);
        nilMarker = [NSObject new];
    });

    NSParameterAssert(cacheOwner && staticToken && generatorBlock);
    if (!cacheOwner || !staticToken)
        return nil;

    const id nonNilCacheKey = cacheKey ? : nilMarker;

    // Take the global lock during creation or look-up of finer-grained cacheStorage mutex
    dispatch_semaphore_wait(globalMutex, DISPATCH_TIME_FOREVER);
    NSMapTable *cacheStorage = objc_getAssociatedObject(cacheOwner, staticToken);
    if (!cacheStorage) {
        cacheStorage = [NSMapTable strongToStrongObjectsMapTable];
        objc_setAssociatedObject(cacheOwner, staticToken, cacheStorage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    static char storageMutexAssociationKey;
    dispatch_semaphore_t cacheStorageMutex = objc_getAssociatedObject(cacheStorage, &storageMutexAssociationKey);
    if (!cacheStorageMutex) {
        cacheStorageMutex = dispatch_semaphore_create(1);
        objc_setAssociatedObject(cacheStorage, &storageMutexAssociationKey, cacheStorageMutex, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    dispatch_semaphore_signal(globalMutex);


    dispatch_semaphore_wait(cacheStorageMutex, DISPATCH_TIME_FOREVER);

    id cachedValue = [cacheStorage objectForKey:nonNilCacheKey];
    if (!cachedValue) {
        // Value isn't cached. Another thread may already be generating it though.
        static char inProgressSemaphoreTableAssociationKey;
        NSMapTable *generatorInProgressSemaphores = objc_getAssociatedObject(cacheStorage, &inProgressSemaphoreTableAssociationKey);
        if (!generatorInProgressSemaphores) {
            generatorInProgressSemaphores = [NSMapTable strongToStrongObjectsMapTable];
            objc_setAssociatedObject(cacheStorage, &inProgressSemaphoreTableAssociationKey, generatorInProgressSemaphores, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        NSMutableArray *waitingSemaphoresArray = [generatorInProgressSemaphores objectForKey:nonNilCacheKey];
        if (waitingSemaphoresArray) {
            // Another thread is generating the value for this key; wait until it's done.
            dispatch_semaphore_t myWaitingSemaphore = dispatch_semaphore_create(0);
            [waitingSemaphoresArray addObject:myWaitingSemaphore];
            dispatch_semaphore_signal(cacheStorageMutex); // unlock while we wait
            dispatch_semaphore_wait(myWaitingSemaphore, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_wait(cacheStorageMutex, DISPATCH_TIME_FOREVER);

            cachedValue = [cacheStorage objectForKey:nonNilCacheKey];

        } else {
            // We are responsible for generating this key. Create a semaphore so others can wait on us.
            waitingSemaphoresArray = [NSMutableArray array];
            [generatorInProgressSemaphores setObject:waitingSemaphoresArray forKey:nonNilCacheKey];

            // Unlock before we call back into client code, because the generator could use other cached values
            dispatch_semaphore_signal(cacheStorageMutex);
            cachedValue = generatorBlock() ? : nilMarker;
            dispatch_semaphore_wait(cacheStorageMutex, DISPATCH_TIME_FOREVER);

            [cacheStorage setObject:cachedValue forKey:nonNilCacheKey];

            [generatorInProgressSemaphores removeObjectForKey:nonNilCacheKey];
            if ([generatorInProgressSemaphores count] == 0)
                // Dispose of empty semaphore table
                objc_setAssociatedObject(cacheStorage, &inProgressSemaphoreTableAssociationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            for (dispatch_semaphore_t waitingSemaphore in waitingSemaphoresArray)
                dispatch_semaphore_signal(waitingSemaphore); // signal all waiters (though they will immediately go back to sleep on cacheStorageMutex)
        }
    }
    dispatch_semaphore_signal(cacheStorageMutex);

    return (cachedValue != nilMarker) ? cachedValue : nil;
}

@end
