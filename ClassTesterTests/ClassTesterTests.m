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
    //_serializer.forceOffsetOfNormalBytes = YES;
}

- (void) tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testExpanding
{
    [_serializer startSerializingWithByteCount:1];
    [_serializer addUnsignedData:10 bits:25];
    SerializedData *data = [_serializer finalizeSerializing];
    
    if (data.count != 4) {
        XCTFail(@"Wrong byte count in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testDeserializer
{
    // Create data
    
    [_serializer startSerializingWithByteCount:1];
    [_serializer addUnsignedData:10 bits:25];
    [_serializer addOnes:15];
    [_serializer addUnsignedData:424736893 maxValue:500000000];
    
    uint32 dataLength = 14;
    [_serializer addUnsignedData:dataLength maxValue:31];
    [_serializer addUnsignedData:8657 bits:dataLength + 1];
    [_serializer addUnsignedData:31 maxValue:5000];
    [_serializer addUnsignedData:10 maxValue:10];
    [_serializer addZeros:4];
    SerializedData *data = [_serializer finalizeSerializing];

    // Display data in log
    //NSLog(@"Data: %@", [data bitString]);
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    uint32 d01 = [_serializer getUnsignedDataBits:25];
    if (d01 != 10) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:15];
    
    d01 = [_serializer getUnsignedDataMaxValue:500000000];
    if (d01 != 424736893) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    uint32 readLength = [_serializer getUnsignedDataMaxValue:31];
    if (readLength != 14) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getUnsignedDataBits:readLength + 1];
    if (d01 != 8657) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getUnsignedDataMaxValue:5000];
    if (d01 != 31) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }

    d01 = [_serializer getUnsignedDataMaxValue:10];
    if (d01 != 10) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Get final zeros (Must finish the last byte)
    [_serializer getUnsignedDataBits:6];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testSignedData
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    
    [_serializer addOnes:3];
    [_serializer addSignedData:34 bits:7];
    [_serializer addSignedData:350 maxValue:500];
    [_serializer addOnes:3];
    [_serializer addSignedData:-845372 maxValue:900000];
    [_serializer addSignedData:-56 bits:32];
    [_serializer addSignedData:-789432519 bits:32];
    [_serializer addOnes:4];
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:3];
    
    sint32 d01 = [_serializer getSignedDataBits:7];
    if (d01 != 34) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getSignedDataMaxValue:500];
    if (d01 != 350) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:3];
    
    d01 = [_serializer getSignedDataMaxValue:900000];
    if (d01 != -845372) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getSignedDataBits:32];
    if (d01 != -56) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    d01 = [_serializer getSignedDataBits:32];
    if (d01 != -789432519) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:4];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testASCIIStrings
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    
    [_serializer addASCIIString:@"Test string 1"];
    [_serializer addOnes:2];
    [_serializer addASCIIString:@"Test string 2"];
    [_serializer addASCIIString:@"Quite a bit longer string for testing purposes."];
    [_serializer addZeros:1];
    [_serializer addASCIIString:@"Final string of testing is also quite long to test the capabilities of the string handler and special letters öäåÖÄÅû<Z;:_2"];
    //[_serializer addZeros:5];
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    NSString *s01 = [_serializer getASCIIString];
    if (!!![s01 isEqualToString:@"Test string 1"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:2];
    
    s01 = [_serializer getASCIIString];
    if (!!![s01 isEqualToString:@"Test string 2"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    s01 = [_serializer getASCIIString];
    if (!!![s01 isEqualToString:@"Quite a bit longer string for testing purposes."]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip zero
    [_serializer getUnsignedDataBits:1];
    
    s01 = [_serializer getASCIIString];
    if (!!![s01 isEqualToString:@"Final string of testing is also quite long to test the capabilities of the string handler and special letters oaaOAAu<Z;:_2"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    //NSLog(@"%@", s01);
    
    // Skip final zeros
    [_serializer getToNextByte];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testCompressedStrings
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    
    [_serializer addCompressedString:@"Test string 1"];
    [_serializer addOnes:2];
    [_serializer addCompressedString:@"Test string 2"];
    [_serializer addCompressedString:@"Quite a bit longer string for testing purposes."];
    [_serializer addZeros:1];
    [_serializer addCompressedString:@"Final string of testing is also quite long to test the capabilities of the string handler and special letters öäåÖÄÅû<Z;:_2"];
    [_serializer addZeros:5];
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    NSString *s01 = [_serializer getCompressedString];
    if (!!![s01 isEqualToString:@"Test string 1"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:2];
    
    s01 = [_serializer getCompressedString];
    if (!!![s01 isEqualToString:@"Test string 2"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    s01 = [_serializer getCompressedString];
    if (!!![s01 isEqualToString:@"Quite a bit longer string for testing purposes."]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip zero
    [_serializer getUnsignedDataBits:1];
    
    s01 = [_serializer getCompressedString];
    if (!!![s01 isEqualToString:@"Final string of testing is also quite long to test the capabilities of the string handler and special letters oaaOAAu<Z;:_2"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    //NSLog(@"%@", s01);
    
    // Skip final zeros
    [_serializer getUnsignedDataBits:5];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testMinimalStrings
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    
    [_serializer addMinimalString:@"Test string 1"];
    [_serializer addOnes:2];
    [_serializer addMinimalString:@"Test string 2"];
    [_serializer addMinimalString:@"Quite a bit longer string for testing purposes."];
    [_serializer addZeros:1];
    [_serializer addMinimalString:@"Final string of testing is also quite long to test the capabilities of the string handler and special letters öäåÖÄÅû<Z;:_2"];
    [_serializer addZeros:5];
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    NSString *s01 = [_serializer getMinimalString];
    if (!!![s01 isEqualToString:@"test string  "]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip ones
    [_serializer getUnsignedDataBits:2];
    
    s01 = [_serializer getMinimalString];
    if (!!![s01 isEqualToString:@"test string  "]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    s01 = [_serializer getMinimalString];
    if (!!![s01 isEqualToString:@"quite a bit longer string for testing purposes."]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip zero
    [_serializer getUnsignedDataBits:1];
    
    s01 = [_serializer getMinimalString];
    //NSLog(@"%@", s01);
    
    if (!!![s01 isEqualToString:@"final string of testing is also quite long to test the capabilities of the string handler and special letters oaaoaau z;   "]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Skip final zeros
    [_serializer getUnsignedDataBits:5];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testHelpers
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    
    [_serializer addBoolean:NO];
    [_serializer addBoolean:YES];
    
    [_serializer addFloat:3.141f];
    [_serializer addDouble:23843244.9823];
    
    [_serializer addOnes:6];
    
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Test booleans
    if ([_serializer getBoolean]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    if (!!![_serializer getBoolean]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Float and double
    float f01 = [_serializer getFloat];
    if (f01 - 3.141f > 0.00001f) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    double d01 = [_serializer getDouble];
    if (d01 - 23843244.9823 > 0.0000001) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    
    // Get trailing ones
    [_serializer getToNextByte];
    
    // Test that this method does not jump forward
    [_serializer getToNextByte];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }
}

- (void) testOffsetForcing
{
    // Create data
    [_serializer startSerializingWithByteCount:3];
    _serializer.forceOffsetOfNormalBytes = YES;
    
    [_serializer addFloat:3.141f];
    
    [_serializer addOnesToNextFullByte];
    [_serializer addDouble:23843244.9823];
    
    [_serializer addOnesToNextFullByte];
    [_serializer addOnes:2];
    [_serializer addObject:@"Full test string with some length and lots of special characters !#€%&/()=?©@£$∞§|[]≈±ß∂–…‚"];

    [_serializer addOnesToNextFullByte];
    
    
    SerializedData *data = [_serializer finalizeSerializing];
    
    // Read data
    if (!!![_serializer startDeserializingWith:data]) {
        XCTFail(@"Deserializer did not start in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Float and double
    float f01 = [_serializer getFloat];
    if (f01 - 3.141f > 0.00001f) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Compensate for ones
    [_serializer getToNextByte];
    
    double d01 = [_serializer getDouble];
    if (d01 - 23843244.9823 > 0.0000001) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }

    // Compensate for ones
    [_serializer getToNextByte];
    [_serializer getUnsignedDataBits:2];
    
    NSString *s01 = (NSString*)[_serializer getObject];
    
    NSLog(@"String: %@", s01);
    
    if (!!! [s01 isEqualToString:@"Full test string with some length and lots of special characters !#€%&/()=?©@£$∞§|[]≈±ß∂–…‚"]) {
        XCTFail(@"Failed data read with deserializer in \"%s\"", __PRETTY_FUNCTION__);
    }
    
    // Get trailing ones
    [_serializer getToNextByte];
    
    // Test if done deserializing
    if (_serializer.state != ss_doneDeserializing) {
        XCTFail(@"Deserializing did not end in \"%s\"", __PRETTY_FUNCTION__);
    }

}

@end
