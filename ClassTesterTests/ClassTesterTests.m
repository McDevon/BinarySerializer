//
//  ClassTesterTests.m
//  ClassTesterTests
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BinarySerializer.h"

@interface ClassTesterTests : XCTestCase

@end

@implementation ClassTesterTests
{
    BinarySerializer *_serializer;
}

- (void) setUp
{
    [super setUp];
    // This method is called before the invocation of each test method in the class.
    
    _serializer = [[BinarySerializer alloc] init];
}

- (void) tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testExpanding
{
    [_serializer startSerializingWithByteCount:1];
    [_serializer addData:10 bits:25];
    SerializedData *data = [_serializer finalizeSerializing];
    
    if (data.count != 4) {
        XCTFail(@"Wrong byte count in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testDeserializer
{
    // Create data
    
    [_serializer startSerializingWithByteCount:1];
    [_serializer addData:10 bits:25];
    [_serializer addOnes:15];
    [_serializer addData:424736893 maxValue:500000000];
    
    uint32 dataLength = 14;
    [_serializer addData:dataLength maxValue:31];
    [_serializer addData:8657 bits:dataLength + 1];
    [_serializer addData:31 maxValue:5000];
    [_serializer addData:10 maxValue:10];
    [_serializer addZeros:4];
    SerializedData *data = [_serializer finalizeSerializing];

    // Display data in log
    //NSLog(@"Data: %@", [data bitString]);
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    uint32 d01 = [_serializer getDataBits:25];
    if (d01 != 10) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getDataBits:15];
    
    d01 = [_serializer getDataMaxValue:500000000];
    if (d01 != 424736893) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    uint32 readLength = [_serializer getDataMaxValue:31];
    if (readLength != 14) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getDataBits:readLength + 1];
    if (d01 != 8657) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getDataMaxValue:5000];
    if (d01 != 31) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }

    d01 = [_serializer getDataMaxValue:10];
    if (d01 != 10) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Get final zeros (Must finish the last byte)
    [_serializer getDataBits:5];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

@end
