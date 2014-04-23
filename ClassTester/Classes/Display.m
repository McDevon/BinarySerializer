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

@end

@implementation TestObject
{
    int _testValue;
}

- (BOOL) serializeWithSerializer:(BinarySerializer *)serializer
{
    [serializer addSignedData:_testValue bits:10];
    
    return YES;
}

- (id) initWithSerializer:(BinarySerializer *)serializer
{
    if (self = [super init]) {
        _testValue = [serializer getSignedDataBits:10];
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
        
        [serializer addObject:t1];
        [serializer addObject:t2];
        
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
        [self writeLine:[NSString stringWithFormat:@"Got String: %@", string]];
        
        // 2. Get second string
        string = [serializer getMinimalString];
        [self writeLine:[NSString stringWithFormat:@"Got String: %@", string]];

        // 3. Get test objects
        /*TestObject *r1 = (TestObject*)[serializer getObject];
        TestObject *r2 = (TestObject*)[serializer getObject];
        
        [self writeLine:[NSString stringWithFormat:@"Got t1 with data: %d", r1.testValue]];
        [self writeLine:[NSString stringWithFormat:@"Got t2 with data: %d", r2.testValue]];*/
        
        // 3b. Get test object data
        string = [serializer getCompressedString];
        int value = [serializer getSignedDataBits:10];
        
        [self writeLine:[NSString stringWithFormat:@"Got %@ with data: %d", string, value]];
        
        string = [serializer getCompressedString];
        value = [serializer getSignedDataBits:10];
        
        [self writeLine:[NSString stringWithFormat:@"Got %@ with data: %d", string, value]];
        
        /*if (i == 99) {
            [self writeLine:[data bitString]];
        }*/
    }
    
    
}

- (void) writeLine:(NSString*)line
{
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", line]];
    [[_textView textStorage] appendAttributedString:astr];
}
@end
