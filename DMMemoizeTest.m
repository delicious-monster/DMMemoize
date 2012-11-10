//
//  DMMemoizeTest.m
//  DMMemoizeTest
//
//  Created by Jonathon Mah on 2012-11-10.
//  Copyright (c) 2012 Delicious Monster Software. All rights reserved.
//

#import "DMMemoizeTest.h"
#import "DMMemoize.h"


@interface CacheTest : NSObject
- (id)morphString:(NSString *)str;
- (NSString *)uppercaseString:(NSString *)str;
- (NSArray *)generatorHistory;
@end

@implementation CacheTest {
    NSMutableArray *_argHistory;
    NSMutableSet *_argSet;
}

- (id)morphString:(NSString *)str;
{
    static char token;
    return [DMMemoize cachedValueForKey:str storageOwner:self token:&token generator:^id{
        BOOL hasSeenKey;
        @synchronized(self) {
            if (!_argHistory)
                _argHistory = [NSMutableArray array];
            if (!_argSet)
                _argSet = [NSMutableSet set];

            [_argHistory addObject:str];
            hasSeenKey = [_argSet containsObject:str];
            [_argSet addObject:str];
        }
        NSCParameterAssert(!hasSeenKey);

        if ([str isEqual:@"nil"])
            return nil;
        if ([str isEqual:@"NSNull"])
            return [NSNull null];
        if ([str isEqual:@"recurse"])
            return [str stringByAppendingString:[self morphString:@"sub"]];
        return [str stringByAppendingString:str];
    }];
}

- (NSString *)uppercaseString:(NSString *)str;
{
    static char token;
    return [DMMemoize cachedValueForKey:str storageOwner:self token:&token generator:^id{
        return [str uppercaseString];
    }];
}

- (NSArray *)generatorHistory;
{
    @synchronized(self) { return [_argHistory copy]; }
}

@end


@implementation DMMemoizeTest

- (void)testBasicCaching;
{
    __weak NSString *cachedValue;
    @autoreleasepool {
        CacheTest *ct = [[CacheTest alloc] init];
        STAssertEqualObjects([ct morphString:@"a"], @"aa", nil);
        STAssertEqualObjects([ct uppercaseString:@"a"], @"A", nil);
        STAssertEqualObjects([ct uppercaseString:@"b"], @"B", nil);
        STAssertEqualObjects([ct morphString:@"b"], @"bb", nil);
        STAssertEqualObjects([ct morphString:@"b"], @"bb", nil);
        STAssertEqualObjects([ct uppercaseString:@"b"], @"B", nil);
        STAssertEqualObjects([ct morphString:@"a"], @"aa", nil);
        STAssertEqualObjects([ct uppercaseString:@"nil"], @"NIL", nil);

        STAssertNil([ct morphString:@"nil"], @"Cache should cache nil");
        STAssertEquals([ct morphString:@"NSNull"], [NSNull null], @"Cache should cache NSNull");
        STAssertNil([ct morphString:@"nil"], @"Cache should cache nil");
        STAssertEquals([ct morphString:@"NSNull"], [NSNull null], @"Cache should cache NSNull");

        STAssertEqualObjects([ct generatorHistory], (@[@"a", @"b", @"nil", @"NSNull"]), nil);

        cachedValue = [ct morphString:@"a"];
    }
    STAssertNil(cachedValue, @"Cached values should be released with owner");
}

- (void)testRecursiveGenerator;
{
    CacheTest *ct = [[CacheTest alloc] init];
    STAssertEqualObjects([ct morphString:@"recurse"], @"recursesubsub", @"Recursion musn't deadlock");
    STAssertEqualObjects([ct morphString:@"recurse"], @"recursesubsub", @"Recursion musn't deadlock");
    STAssertEqualObjects([ct generatorHistory], (@[@"recurse", @"sub"]), nil);
}

- (void)testConcurrency;
{
    CacheTest *ct = [[CacheTest alloc] init];

    const uint32_t maxArgs = 32;
    dispatch_block_t testBlock1 = [^{ @autoreleasepool {
        for (NSUInteger i = 0; i < 64; i++) {
            NSString *input = [NSString stringWithFormat:@"stress %u", (arc4random() % maxArgs)];
            STAssertEqualObjects([ct morphString:input], [input stringByAppendingString:input], nil);
        }
    }} copy];
    dispatch_block_t testBlock2 = [^{ @autoreleasepool {
        for (NSUInteger i = 0; i < 64; i++) {
            NSString *input = [NSString stringWithFormat:@"stress %u", (arc4random() % maxArgs)];
            STAssertEqualObjects([ct uppercaseString:input], [input uppercaseString], nil);
        }
    }} copy];

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    for (NSUInteger i = 0; i < 51200; i++) {
        dispatch_group_async(group, queue, testBlock1);
        dispatch_group_async(group, queue, testBlock2);
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    STAssertTrue([[ct generatorHistory] count] <= maxArgs, nil); // <= because there is randomness
}

@end
