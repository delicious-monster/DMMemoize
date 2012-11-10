//
//  DMMemoize.h
//  DMMemoize
//
//  Created by Jonathon Mah on 2012-11-10.
//  Copyright (c) 2012 Delicious Monster Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DMMemoize : NSObject

/* Helper to add return value caching to pure methods (those without side-effects).
 *
 * Example.
 * The following function calculates the return value every time:
 *
 * - (id)someFunctionOf:(id)key {
 *     return [self expensiveCalculationWith:key];
 * }
 *
 * Using DMMemoize so each value is only calculated once:
 *
 * - (id)someFunctionOf:(id)key {
 *     static char cacheToken;
 *     return [DMMemoize cachedValueForKey:key storageOwner:self token:&cacheToken generator:^{
 *         return [self expensiveCalculationWith:key];
 *     }];
 * }
 *
 * The `cacheKey` and return values can be any object (including NSNull), or nil.
 *
 * The cache keys and return values will be retained until the storage owner is deallocated.
 *
 * If the pure method takes multiple parameters, combine them all into a single object to be used as cacheKey.
 * Although NSArray and NSDictionary are obvious candidates for this (e.g. +cachedValueForKey:@[arg1, arg2] …),
 * they are poor choices due to the default -hash of those objects being their count. This will typically lead
 * to 100% hash collisions, so cache lookup will be linear instead of constant. It's much better to use a
 * container with a hash that's a function of its elements' hashes. A composite string can serve this purpose
 * (e.g. [NSString stringWithFormat:@"%@ %@", arg1, arg2]), though of course be careful to avoid ambiguous
 * situations (i.e. for the above example, key=@"A B C" is the same for [@"A B", @"C"] and [@"A", @"B C"]).
 */
+ (id)cachedValueForKey:(id)cacheKey storageOwner:(id)cacheOwner token:(void *)staticToken generator:(id(^)(void))generatorBlock __attribute__((nonnull(2,3,4)));

@end
