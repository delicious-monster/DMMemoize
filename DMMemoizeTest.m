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
        if (!_argHistory)
            _argHistory = [NSMutableArray array];
        if (!_argSet)
            _argSet = [NSMutableSet set];

        [_argHistory addObject:str];
        hasSeenKey = [_argSet containsObject:str];
        [_argSet addObject:str];

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
    return [_argHistory copy];
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

@end
