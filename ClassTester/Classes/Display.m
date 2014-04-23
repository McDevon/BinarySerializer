//
//  Display.m
//  ClassTester
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

#import "Display.h"
#import "BinarySerializer.h"

@interface TestObject : NSObject <BinarySerializing>

@property int testValue;
@property BOOL testBool;

@end

@implementation TestObject
{
    int _testValue;
    BOOL _testBool;
}

- (BOOL) serializeWithSerializer:(BinarySerializer *)serializer
{
    [serializer addSignedData:_testValue bits:10];
    [serializer addBoolean:_testBool];
    
    return YES;
}

- (id) initWithSerializer:(BinarySerializer *)serializer
{
    if (self = [super init]) {
        _testValue = [serializer getSignedDataBits:10];
        _testBool = [serializer getBoolean];
    }
    
    return self;
}

@end

@interface Display ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation Display

-(void)awakeFromNib
{
    for (int i = 0; i < 1; i++) {
        BinarySerializer *serializer = [[BinarySerializer alloc] init];
        
        [serializer startSerializingWithByteCount:5];
        //serializer.compressAllStrings = YES;
        
        // 1. Add test string
        [serializer addCompressedString:@"This is ä test string öä and stuff yea"]; // ä and stuff"];
        
        // 2. Add minimal test string of all characters
        for (int i = 0; i < 32; i++) {
            [serializer addUnsignedData:i bits:5];
        }
        
        // 3. Create and add two test objects
        TestObject *t1 = [[TestObject alloc] init];
        TestObject *t2 = [[TestObject alloc] init];
       
        t1.testValue = -426;
        t2.testValue = 33;
        
        t1.testBool = YES;
        t2.testBool = NO;
        
        [serializer addObject:t1];
        [serializer addObject:t2];
        
        // 4. Various test items
        [serializer addBoolean:NO];
        
        // 5. Array tests
        NSMutableArray *a1 = [NSMutableArray array];
        
        for (int i = 0; i < 20; i++) {
            TestObject *o = [[TestObject alloc] init];
            o.testValue = i - 10;
            [a1 addObject:o];
        }
        
        [serializer addObject:a1];
        
        for (int i = 0; i < 5; i++) {
            [a1 removeObjectAtIndex:4];
        }
        
        [serializer addObject:[NSArray arrayWithArray:a1]];
        
        // 6. Dictionary tests
        NSMutableDictionary *d1 = [NSMutableDictionary dictionary];
        
        [d1 setObject:t1 forKey:@"Firstkey"];
        [d1 setObject:t2 forKey:@"Second key"];
        
        [serializer addObject:d1];
        
        // 7. String tests
        
        [serializer addObject:@"Test string with ^+32öäåÖÄÅûü and ;:_$€÷ß≈ç∂¸√éΩüıœ"];
        
        // 8. Set tests
        NSMutableSet *s1 = [NSMutableSet set];
        
        for (int i = 0; i < 15; i++) {
            TestObject *o = [[TestObject alloc] init];
            o.testValue = (i - 10) * 3;
            o.testBool = i % 2 == 0;
            [s1 addObject:o];
        }
        
        [serializer addObject:s1];
        
        
        //SerializedData *data = [serializer getData];
        //SerializedData *data = [serializer finalizeSerializing];
        
        // Serialize to a file
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        
        // Should find something
        if (paths.count <= 0) {
            break;
        }
        
        NSURL *url = [NSURL URLWithString:(NSString*)[paths objectAtIndex:0]];
        
        url = [url URLByAppendingPathComponent:@"file.tst"];
        
        NSError *error = nil;
        
        BOOL done = [serializer finalizeSerializingToFileURL:url error:&error];
        
        if (error != nil) {
            NSLog(@"#Error: %@", [error localizedDescription]);
        }
        
        if (!!!done) {
            NSLog(@"Did not write to file");
        }
        
        
        /*
         *  Read the data
         */
        
        //[self writeLine:[data bitString]];
        //[serializer startDeserializingWith:data];
        
        done = [serializer startDeserializingWithFileURL:url error:&error];
        
        if (error != nil) {
            NSLog(@"#Error: %@", [error localizedDescription]);
        }
        
        if (!!!done) {
            NSLog(@"Did not read from file");
        }
        
        // 1. Get first string
        NSString *string = [serializer getCompressedString];
        [self writeLine:@"Got String: %@", string];
        
        // 2. Get second string
        string = [serializer getMinimalString];
        [self writeLine:@"Got String: %@", string];

        // 3a. Get test objects
        TestObject *r1 = (TestObject*)[serializer getObject];
        TestObject *r2 = (TestObject*)[serializer getObject];
        
        [self writeLine:@"Got t1 with data: %d", r1.testValue];
        [self writeLine:@"Got t2 with data: %d", r2.testValue];
        
        // 3b. Get test object data
        /*string = [serializer getCompressedString];
        int value = [serializer getSignedDataBits:10];
        
        [self writeLine:@"Got %@ with data: %d", string, value];
        
        string = [serializer getCompressedString];
        value = [serializer getSignedDataBits:10];
        
        [self writeLine:@"Got %@ with data: %d", string, value];*/
        
        // 4. Get various test items
        BOOL b = [serializer getBoolean];
        
        if (b) {
            [self writeLine:@"Yes!"];
        } else {
            [self writeLine:@"No!"];
        }
        
        // 5. Get test array
        
        NSMutableArray *a2 = (NSMutableArray*)[serializer getObject];
        
        [a2 addObject:[[TestObject alloc] init]];
        
        for (TestObject *o in a2) {
            [self writeLine:@"Test object in mutable array has data: %d", o.testValue];
        }
        
        NSArray *a3 = (NSArray*)[serializer getObject];
        
        for (TestObject *o in a3) {
            [self writeLine:@"Test object in array has data: %d", o.testValue];
        }
        
        // 6. Dictionary tests
        
        NSMutableDictionary *d2 = (NSMutableDictionary*)[serializer getObject];
        
        for (NSString *key in [d2 allKeys]) {
            TestObject *o = [d2 objectForKey:key];
            
            [self writeLine:@"Key: %@ value: %d", key, o.testValue];
        }
        
        // 7. String tests
        
        NSString *testString = (NSString*)[serializer getObject];
        [self writeLine:@"%@", testString];
        
        // 8. Set tests
        NSMutableSet *s2 = (NSMutableSet*)[serializer getObject];
        for (TestObject *o in s2) {
            if (o.testBool) {
                [self writeLine:@"YES: %d", o.testValue];
            } else {
                [self writeLine:@"NO: %d", o.testValue];
            }
        }
        
        /*if (i == 99) {
            [self writeLine:[data bitString]];
        }*/
    }
    
    
}

- (void) writeLine:(NSString*)line, ...
{
    va_list args;
    
    // Get args from argument list
    va_start(args, line);
    
    // Pass argument list to NSString's initWithFormat:arguments:
    NSString *string = [[NSString alloc] initWithFormat:line arguments:args];
    
    // Done with arguments
    va_end(args);
    
    // Add endline and push to textView's buffer
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", string]];
    [[_textView textStorage] appendAttributedString:astr];
}
@end
