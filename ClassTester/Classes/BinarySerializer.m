//
//  BinarySerializer.m
//  ClassTester
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

#import "BinarySerializer.h"

@implementation SerializedData
{
    uint8 *_data;
    uint32 _count;
}

- (id) init
{
    if (self = [super init])
    {
        _data = NULL;
        _count = 0;
    }
    
    return self;
}

- (BOOL) mallocDataBytes:(uint32) count
{
    _data = malloc(sizeof(uint8) * count);
    
    // Test if allocation failed
    if (_data == NULL) {
        return NO;
    }
    
    _count = count;
    
    return YES;
}

- (NSString*) bitString
{
    NSMutableString *bitString = [[NSMutableString alloc] init];
    
    for (int i = 0; i < _count; i++)
    {
        for (int j = 0; j < 8; j++)
        {
            uint8 mask = (uint8)(1 << j);
            if ((_data[i] & mask) > 0)
            {
                [bitString appendFormat:@"1"];
            }
            else
            {
                [bitString appendFormat:@"0"];
            }
        }
        if (i < _count - 1)
        {
            [bitString appendFormat:@" "];
        }
    }
    
    return bitString;
}

- (BOOL) doubleSize
{
    return [self increaseSizeTo:_count * 2];
}

- (BOOL) increaseSizeTo:(uint32) newSize
{
    if (newSize <= _count) {
        // New size not larger
        return NO;
    }
    
    return [self resizeTo:newSize];
}

- (BOOL) resizeTo:(uint32) newSize
{
    uint8 *newData = malloc(sizeof(uint8) * newSize);
    // Test if allocation failed
    if (newData == NULL) {
        return NO;
    }
    
    // Copy old data
    for (uint32 i = 0; i < _count; i++) {
        newData[i] = _data[i];
    }
    
    free(_data);
    _data = newData;
    _count = newSize;
    
    return YES;
}

- (void) dealloc
{
    if (_data != NULL) {
        free(_data);
    }
}

@end

@implementation BinarySerializer
{
    SerializedData *_data;
    uint32 _bitIndex;
    
    SerializingState _state;
}

- (BOOL) startSerializing
{
    return [self startSerializingWithByteCount:8];
}

- (BOOL) startSerializingWithByteCount:(int) count
{
    if (_state == ss_error || _state == ss_serializing || _state == ss_deserializing) {
        return NO;
    }
    
    if (count < 1) {
        return NO;
    }
    
    _state = ss_serializing;
    
    _data = [[SerializedData alloc] init];
    if (!!! [_data mallocDataBytes:count]) {
        return NO;
    }
    
    _bitIndex = 0;
    
    return YES;
}

- (BOOL) addData:(uint32)data maxValue:(uint32)maxValue
{
    uint32 bits = 0;
    for (uint32 i = 0; i < 32; i++) {
        if (pow(2, i) - 1 > maxValue) {
            bits = i;
            break;
        }
    }
    if (bits == 0) {
        return NO;
    }
    return [self addData:data bits:bits];
}

- (BOOL) addData:(uint32) value bits:(uint32) bits
{
    if (_state != ss_serializing) {
        return NO;
    }
    
    // Sanity check
    if (value > pow(2, bits))
    {
        // Trying to set a value which does not fit in the given amount of bits
        return NO;
    }
    while (bits + _bitIndex > 8 * _data.count)
    {
        // Bit index goes beyond message boundaries
        // Enlargen the message
        
        if (!!![_data doubleSize]) {
            _state = ss_error;
            return NO;
        }
    }
    
    // Put the right bits in place
    
    // Start from bit index, get first byte
    int byteIndex = _bitIndex / 8;
    
    // Get required byte amount
    int startBit = _bitIndex % 8;
    int byteAmount = (bits + startBit) / 8 + 1;
    
    // Current bit index in the value
    //int currentBit = 0;
    
    // Loop through bytes and add bits
    for (int i = byteIndex; i < byteIndex + byteAmount && bits > 0 && i < _data.count; i++)
    {
        // Get start bit
        startBit = _bitIndex % 8;
        
        // Set bits
        _data.data[i] = (uint8)(_data.data[i] | ((uint8)value << startBit));
        
        // Change counters
        int bitsAdded = MIN(bits, 8 - startBit);
        bits -= bitsAdded;
        _bitIndex += bitsAdded;
        
        value = value >> bitsAdded;
    }
    
    return YES;
}

- (SerializedData*) finalizeSerializing
{
    // Trim the bytes
    uint32 newSize = _bitIndex % 8 > 0 ? _bitIndex / 8 + 1 : _bitIndex / 8;
    [_data resizeTo:newSize];
    
    _state = ss_doneSerializing;
    
    return _data;
}

- (BOOL) startDeserializingWith:(SerializedData*) data
{
    if (_state == ss_error || _state == ss_serializing || _state == ss_deserializing
        || data == nil) {
        return NO;
    }
    
    _data = data;
    _bitIndex = 0;
    
    _state = ss_deserializing;
    
    return YES;
}

- (uint32) getDataMaxValue:(uint32)maxValue
{
    uint32 bits = 0;
    for (uint32 i = 0; i < 32; i++) {
        if (pow(2, i) - 1 > maxValue) {
            bits = i;
            break;
        }
    }
    if (bits == 0) {
        return 0;
    }
    return [self getDataBits:bits];
}

- (uint32) getDataBits:(uint32) bits
{
    if (_state != ss_deserializing) {
        return 0;
    }
    
    if (bits + _bitIndex > 8 * _data.count) {
        // Reaching end of data, cannot read that many bits
        _state = ss_error;
        return 0;
    }
    
    uint32 value = 0;
    
    // Start from bit index, get first byte
    int byteIndex = _bitIndex / 8;
    
    // Get required byte amount
    int startBit = _bitIndex % 8;
    int trim;
    int targetBit = 0;
    int byteAmount = (bits + startBit) / 8 + 1;
    
    // Loop through bytes and get bits
    for (int i = byteIndex; i < byteIndex + byteAmount && bits > 0 && i < _data.count; i++)
    {
        // Get start bit
        startBit = _bitIndex % 8;
        
        // Trim to how many bits
        trim = bits + startBit > 8 ? 0 : bits;
        
        uint8 byte = _data.data[i];
        
        // Trim
        if (trim > 0) {
            byte = byte & (uint8)(pow(2, trim) - 1);
        }
        
        // Get bits
        value = value | (uint32)(byte >> startBit) << targetBit;
        
        // Change counters
        int bitsAdded = MIN(bits, 8 - startBit);
        bits -= bitsAdded;
        targetBit += bitsAdded;
        _bitIndex += bitsAdded;
    }
    
    // End deserializing when reached the end of data
    if (_bitIndex == 8 * _data.count) {
        _state = ss_doneDeserializing;
        NSLog(@"Done deserializing");
    }
    
    return value;
}

- (BOOL) addOnes:(int) amount
{
    int value = (int)(pow(2, amount) - 1);
    return [self addData:value bits:amount];
}

- (BOOL) addZeros:(int) amount
{
    int value = 0;
    return [self addData:value bits:amount];
}


- (SerializedData*) getData
{
    _state = ss_doneSerializing;
    return _data;
}

@end
