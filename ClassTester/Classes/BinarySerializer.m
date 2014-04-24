//
//  BinarySerializer.m
//  ClassTester
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

//#import <objc/runtime.h>
#import "BinarySerializer.h"

// These values will define the bit size of variables to store the values in serialized data
#define MAX_OBJECTS_IN_NSARRAY          1023
#define MAX_OBJECTS_IN_NSDICTIONARY     1023
#define MAX_OBJECTS_IN_NSSET            1023
#define MAX_LENGTH_OF_NSSTRING          32767   // 2^15 - 1

/*
 *  Helper functions for string compression
 */

uint8 shortChar(char character)
{
    uint8 value;
    
    // Small chars
    if (character >= 'a' && character <= 'z') {
        value = character - 'a';
        return value * 2;
    }
    
    // Capital chars (Capital Z is a special character)
    if (character >= 'A' && character <= 'Y') {
        value = character - 'A';
        return value * 2 + 1;
    }
    
    // Numbers
    if (character >= '0' && character <= '9') {
        value = character - '0';
        return value + 51;
    }
    
    // Space
    if (character == ' ') {
        return 61;
    }
    
    // End of text
    if (character == '\0') {
        return 62;
    }
    
    // Other characters
    return 63;
}

uint8 minimalChar(char character)
{
    // Small letters
    if (character >= 'a' && character <= 'z') {
        return character - 'a';
    }
    
    // Capital letters become small letters
    if (character >= 'A' && character <= 'Z') {
        return character - 'A';
    }
    
    // .,;-?
    // TODO: Choose which characters belong here
    switch (character) {
        case '.':
            return 27;
            break;
            
        case ',':
            return 28;
            break;
            
        case ';':
            return 29;
            break;
            
        case '-':
            return 30;
            break;
            
        case '\0':
            return 31;
            break;
            
        default:
            break;
    }
    
    // Space
    return 26;
}

char charFromShortChar(uint8 shortChar)
{
    static char table[65] = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYz0123456789 \0*\0";
    if (shortChar < 64) {
        return table[shortChar];
    }
    return '*';
}

char charFromMinimalChar(uint8 shortChar)
{
    static char table[33] = "abcdefghijklmnopqrstuvwxyz .,;-\0\0";
    if (shortChar < 32) {
        return table[shortChar];
    }
    return ' ';
}

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
    _data = (uint8*)calloc(count, sizeof(uint8));
    
    // Test if allocation failed
    if (_data == NULL) {
        return NO;
    }
    
    _count = count;
    
    return YES;
}

- (NSString*) bitString
{
    // Create a string showing all the bits of the data byte by byte
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
    uint8 *newData = (uint8*)calloc(newSize, sizeof(uint8));
    // Test if allocation failed
    if (newData == NULL) {
        return NO;
    }
    
    // Copy old data
    for (uint32 i = 0; i < newSize && i < _count; i++) {
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
    
    BOOL _compressAllStrings;
    BOOL _useMinimalStringsForDictionaries;
}

- (id) init
{
    if (self = [super init]) {
        _compressAllStrings = NO;
        _useMinimalStringsForDictionaries = NO;
    }
    
    return self;
}

#pragma mark -
#pragma mark Helper methods
#pragma mark -

- (uint32) getMaxBitsForValue:(uint32)maxValue
{
    // Get the minimum amount of bits required to store the given value
    uint32 bits = 0;
    for (uint32 i = 0; i < 32; i++) {
        if (pow(2, i) > maxValue) {
            bits = i;
            break;
        }
    }
    
    return bits;
}

#pragma mark -
#pragma mark Serializing
#pragma mark -

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

/*
 *  Writing unsigned data
 */

- (BOOL) addUnsignedData:(uint32)value maxValue:(uint32)maxValue
{
    uint32 bits = [self getMaxBitsForValue:maxValue];
    
    if (bits == 0) {
        return NO;
    }
    
    // Sanity check
    uint32 edgeValue = bits >= 32 ? 0xffffffff : pow(2, bits) - 1;
    if (value > edgeValue)
    {
        // Trying to set a value which does not fit in the given amount of bits
        return NO;
    }
    
    return [self addData:value bits:bits];
}

- (BOOL) addUnsignedData:(uint32) value bits:(uint32) bits
{
    // Sanity check
    uint32 edgeValue = bits >= 32 ? 0xffffffff : pow(2, bits) - 1;
    if (value > edgeValue)
    {
        // Trying to set a value which does not fit in the given amount of bits
        return NO;
    }
    
    return [self addData:value bits:bits];
}

/*
 *  Writing signed data
 */

- (BOOL) addSignedData:(sint32)value maxValue:(uint32)maxValue
{
    uint32 bits = [self getMaxBitsForValue:maxValue] + 1;
    
    if (bits == 0) {
        return NO;
    }

    return [self addSignedData:(uint32)value bits:bits];
}

- (BOOL) addSignedData:(sint32) value bits:(uint32) bits
{
    // Sanity check
    sint32 edgeValue = bits >= 32 ? 0x7fffffff : pow(2, bits - 1) - 1;
    if (value >= edgeValue || value < -edgeValue) {
        return NO;
    }
    
    return [self addData:value bits:bits];
}

/*
 *  Special helpers (for e.g. booleans)
 */

- (BOOL) addBoolean:(BOOL)value
{
    uint32 boolean = value ? 1 : 0;
    return [self addData:boolean bits:1];
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

- (BOOL) addFloat:(float)value
{
    uint32 store = 0;
    
    // Copy bits to store
    memcpy(&store, &value, sizeof(float));
    
    // Add all bits
    return [self addData:store bits:32];
}

- (BOOL) addDouble:(double)value
{
    uint32 store[2] = {0, 0};
    
    // Copy bits to store
    memcpy(&store, &value, sizeof(double));
    
    // Add all bits in a very annoying order
    BOOL firstBits = [self addData:store[1] bits:32];
    return firstBits && [self addData:store[0] bits:32];
}

/*
 *  Writing string data
 */

- (BOOL) addASCIIString:(NSString*) string
{
    // Convert to chars
    const char *data = [[[NSString stringWithFormat:@"%@\0", string] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] bytes];
    
    // Add to data
    size_t i = 0;
    while (i <= 0 || data[i-1] != '\0') {
        if (!!![self addData:(uint32)data[i] bits:8]) {
            return NO;
        }
        i++;
    }
    
    //printf("%s", data);
    
    return YES;
}

- (BOOL) addCompressedString:(NSString*) string
{
    // Compress most characters to 6 bits, specials get extra 8 bits
    // All characters are available to use
    
    // Convert to chars
    const char *data = [[[NSString stringWithFormat:@"%@\0", string] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] bytes];
    
    // Add to data
    size_t i = 0;
    while (i <= 0 || data[i-1] != '\0') {
        // Get shorter char
        uint8 chr = shortChar(data[i]);
        if (!!![self addData:(uint32)chr bits:6]) {
            return NO;
        }
        
        // This char not in short dictionary, add full char for reference
        if (chr == 63) {
            if (!!![self addData:(uint32)data[i] bits:8]) {
                return NO;
            }
        }
        
        i++;
    }
    
    return YES;
}

- (BOOL) addMinimalString:(NSString*) string
{
    // Compress most characters to 5 bits, only a small list of characters available
    // No numbers, capital letters, etc.
    
    // Convert to chars
    const char *data = [[[NSString stringWithFormat:@"%@\0", string] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] bytes];
    
    // Add to data
    size_t i = 0;
    while (i <= 0 || data[i-1] != '\0') {
        // Get shorter char
        uint8 chr = minimalChar(data[i]);
        if (!!![self addData:(uint32)chr bits:5]) {
            return NO;
        }
        
        i++;
    }
    
    return YES;
}

/*
 *  Handling of objects
 */

- (BOOL) addObject:(NSObject*)object
{
    // Sanity check
    if (object == nil) {
        return NO;
    }
    
    //const char* className = class_getName([object class]);
    NSString *className = NSStringFromClass([object class]);
    
    // First encode class name in compressed chars
    [self addCompressedString:className];
    
    // Then act according to object type
    if ([[object class] conformsToProtocol:@protocol(BinarySerializing)]) {
        
        // Easy case, conforms to the defined protocol
        NSObject <BinarySerializing> *o = (NSObject<BinarySerializing>*)object;
        
        // Add the data the class wants to add
        return [o serializeWithSerializer:self];
    }
    
    /*
     *  Convenience handling of some of the Cocoa classes so no subclassing is required
     */
    
    else if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray*) object;
        
        // Encode amount of objects
        [self addUnsignedData:(uint32)array.count maxValue:MAX_OBJECTS_IN_NSARRAY];
        
        // Encode objects
        for (NSObject *o in array) {
            [self addObject:o];
        }
        
        if (_state == ss_serializing) {
            return YES;
        }
    }
    
    else if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary*) object;
        
        // Encode amount of objects
        [self addUnsignedData:(uint32)dictionary.count maxValue:MAX_OBJECTS_IN_NSDICTIONARY];
        
        // Encode objects and keys
        NSArray *keys = [dictionary allKeys];
        for (NSObject *key in keys) {
            
            // Key type
            
            // Special handling for NSStrings
            if ([key isKindOfClass:[NSString class]]) {
                // Add key type, then key in shortChar form
                [self addCompressedString:@"MDSCString"];
                
                // Key
                NSString *keyString = (NSString*) key;
                
                if (_useMinimalStringsForDictionaries) {
                    [self addMinimalString:keyString];
                } else {
                    [self addCompressedString:keyString];
                }
            }
            else {
                // If not NSString, add as object
                [self addObject:key];
            }
            
            // Key added, add data
            [self addObject:[dictionary objectForKey:key]];
        }
        
        // Added all objects, if everything is ok, we're done here
        if (_state == ss_serializing) {
            return YES;
        }
    }
    
    else if ([object isKindOfClass:[NSSet class]]) {
        NSSet *set = (NSSet*) object;
        
        // Encode amount of objects
        [self addUnsignedData:(uint32)set.count maxValue:MAX_OBJECTS_IN_NSSET];
        
        // Encode objects
        for (NSObject *o in set) {
            [self addObject:o];
        }
        
        if (_state == ss_serializing) {
            return YES;
        }
    }
    
    else if ([object isKindOfClass:[NSString class]]) {
        NSString *string = (NSString*) object;
        
        // Compressed string
        if (_compressAllStrings) {
            
            // Add compressed string data
            [self addCompressedString:string];
        }
        else {
            
            // Add uncompressed string data byte by byte
            const char *stringData = [string cStringUsingEncoding:NSUTF8StringEncoding];
            
            // Save string data
            uint32 length = (uint32)string.length;
            for (uint32 i = 0; i < length; i++) {
                [self addData:stringData[i] bits:8];
            }
            
            // Finalize the string
            [self addData:'\0' bits:8];
        }
        
        if (_state == ss_serializing) {
            return YES;
        }
    }
    
    // Not possible to serialize this object or serialization failed
    return NO;
}

/*
 *  Actual data adding method
 */

- (BOOL) addData:(uint32) value bits:(uint32) bits
{
    if (_state != ss_serializing) {
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
        
        
        // Trim to how many bits
        uint8 trim = bits + startBit >= 8 ? 0 : bits;
        
        uint8 byte = ((uint8)value);
        
        // Trim
        if (trim > 0) {
            byte = byte & (uint8)(pow(2, trim) - 1);
        }
        
        // Set bits
        uint8 tempValue = (uint8)(_data.data[i] | (byte << startBit));
        _data.data[i] = tempValue;
        
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
    if (_state != ss_serializing) {
        return NO;
    }

    // Trim the bytes
    uint32 newSize = _bitIndex % 8 > 0 ? _bitIndex / 8 + 1 : _bitIndex / 8;
    [_data resizeTo:newSize];
    
    _state = ss_doneSerializing;
    
    return _data;
}

- (BOOL) finalizeSerializingToFileURL:(NSURL*) url error:(NSError *__autoreleasing*) error
{
    return [self finalizeSerializingToFilePath:[url path] error:error];
}

- (BOOL) finalizeSerializingToFilePath:(NSString*) path error:(NSError *__autoreleasing*) error
{
    if (_state != ss_serializing) {
        return NO;
    }

    // Trim the bytes
    uint32 newSize = _bitIndex % 8 > 0 ? _bitIndex / 8 + 1 : _bitIndex / 8;
    [_data resizeTo:newSize];
    
    _state = ss_doneSerializing;
    
    // Save bytes to file
    NSData *data = [NSData dataWithBytes:_data.data length:_data.count];
    
    BOOL status = [data writeToFile:path options:NSDataWritingAtomic error:error];
    
    /*if (error != nil) {
        NSLog(@"#Error: %@", [error localizedDescription]);
    }*/
    
    return status;
}

- (SerializedData*) getData
{
    if (_state != ss_serializing) {
        return NO;
    }
    
    _state = ss_doneSerializing;
    return _data;
}

#pragma mark -
#pragma mark Deserializing
#pragma mark -

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

- (BOOL) startDeserializingWithFileURL:(NSURL*) url error:(NSError *__autoreleasing*) error
{
    return [self startDeserializingWithFilePath:[url path] error:error];
}

- (BOOL) startDeserializingWithFilePath:(NSString*) path error:(NSError *__autoreleasing*) error
{
    if (_state == ss_error || _state == ss_serializing || _state == ss_deserializing) {
        return NO;
    }
    
    // Read file to nsdata
    NSData *fileData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
    
    if (*error != nil) {
        return NO;
    }
    
    _data = [[SerializedData alloc] init];
    
    // Copy bytes
    uint32 length = (uint32)[fileData length];
    
    const uint8 *bytes = [fileData bytes];
    
    [_data mallocDataBytes:length];
    for (uint32 i = 0; i < length; i++) {
        _data.data[i] = bytes[i];
    }
    
    _bitIndex = 0;
    
    _state = ss_deserializing;
    
    return YES;
}

/*
 *  Unsigned getters
 */

- (uint32) getUnsignedDataMaxValue:(uint32)maxValue
{
    uint32 bits = [self getMaxBitsForValue:maxValue];
    
    if (bits == 0) {
        return 0;
    }
    
    return [self getDataBits:bits];
}

- (uint32) getUnsignedDataBits:(uint32) bits
{
    return [self getDataBits:bits];
}

/*
 *  Signed getters
 */

- (sint32) getSignedDataMaxValue:(uint32)maxValue
{
    uint32 bits = [self getMaxBitsForValue:maxValue] + 1;
    
    if (bits == 0) {
        return 0;
    }
    
    return [self getSignedDataBits:bits];
}


- (sint32) getSignedDataBits:(uint32) bits
{
    uint32 value = [self getDataBits:bits];
    
    // If negative (test most significant bit)
    if ((value & (uint32)pow(2, bits - 1)) > 0) {
        // Create two's complement in sint32 for the value
        uint32 mask = (uint32)0xffffffff - (uint32)(pow(2, bits) - 1);
        return (sint32)(mask | value);
    }
    
    // Positive
    return value;
}

/*
 *  String getters
 */

- (NSString*) getASCIIString
{
    // Start getting some
    size_t t = 32;
    size_t i = 0;
    char *string = (char*)calloc(t, sizeof(char));
    if (string == NULL) {
        _state = ss_error;
        return nil;
    }
    do {
        string[i] = (char)[self getDataBits:8];
        if (_state == ss_error) {
            free(string);
            return nil;
        }
        i++;
        
        // If string gets too short, double its size
        if (i >= t) {
            t *= 2;
            // Allocate new string
            char *newString = (char*)calloc(t, sizeof(char));
            
            if (newString == NULL) {
                free(string);
                _state = ss_error;
                return nil;
            }
            
            // Copy old data
            for (int j = 0; j < i; j++) {
                newString[j] = string[j];
            }

            free(string);
            string = NULL;
            string = newString;
        }
    } while (string[i-1] != '\0');
    
    NSString *str = [[NSString alloc] initWithBytes:string length:i - 1 encoding:NSASCIIStringEncoding];
    
    free(string);
    string = NULL;
    
    return str;
}

- (NSString*) getCompressedString
{
    // Start getting some
    size_t t = 32;
    size_t i = 0;
    char *string = (char*)calloc(t, sizeof(char));
    if (string == NULL) {
        _state = ss_error;
        return nil;
    }
    do {
        uint8 chr = [self getDataBits:6];
        
        if (_state == ss_error) {
            free(string);
            return nil;
        }
        
        // Char was not in dictionary, use full ascii from next 8 bits
        if (chr == 63) {
            chr = [self getDataBits:8];
            string[i] = (char)chr;
        }
        // Normally set dictionary char
        else {
            string[i] = charFromShortChar(chr);
        }
        
        i++;
        
        // If string gets too short, double its size
        if (i >= t) {
            t *= 2;
            // Allocate new string
            char *newString = (char*)calloc(t, sizeof(char));
            
            if (newString == NULL) {
                free(string);
                _state = ss_error;
                return nil;
            }
            
            // Copy old data
            for (int j = 0; j < i; j++) {
                newString[j] = string[j];
            }
            
            free(string);
            string = NULL;
            string = newString;
        }
    } while (string[i-1] != '\0');
    
    NSString *str = [[NSString alloc] initWithBytes:string length:i - 1 encoding:NSASCIIStringEncoding];
    
    free(string);
    string = NULL;
    
    return str;
}

- (NSString*) getMinimalString
{
    // Start getting some
    size_t t = 32;
    size_t i = 0;
    char *string = (char*)calloc(t, sizeof(char));
    if (string == NULL) {
        _state = ss_error;
        return nil;
    }
    do {
        uint8 chr = [self getDataBits:5];
        
        if (_state == ss_error) {
            free(string);
            return nil;
        }
        
        string[i] = charFromMinimalChar(chr);
        
        i++;
        
        // If string gets too short, double its size
        if (i >= t) {
            t *= 2;
            // Allocate new string
            char *newString = (char*)calloc(t, sizeof(char));
            
            if (newString == NULL) {
                free(string);
                _state = ss_error;
                return nil;
            }
            
            // Copy old data
            for (int j = 0; j < i; j++) {
                newString[j] = string[j];
            }
            
            free(string);
            string = NULL;
            string = newString;
        }
    } while (string[i-1] != '\0');
    
    NSString *str = [[NSString alloc] initWithBytes:string length:i - 1 encoding:NSASCIIStringEncoding];
    
    free(string);
    string = NULL;
    
    return str;
}

/*
 *  Special handlers
 */

- (BOOL) getBoolean
{
    uint8 b = [self getDataBits:1];
    return (b == 1);
}

- (float) getFloat
{
    uint32 store = [self getDataBits:32];
    float value;
    memcpy(&value, &store, sizeof(float));
    
    return value;
}

- (double) getDouble
{
    // Get data
    uint32 store[2] = {0, 0};
    store[1] = [self getDataBits:32];
    store[0] = [self getDataBits:32];
    
    // Copy to value
    double value;
    memcpy(&value, &store, sizeof(double));
    
    return value;
}

- (uint32) getToNextByte
{
    // Will get remaining bits of the current byte. If at end of byte, gets nothing.
    
    int currentBitInByte = _bitIndex % 8;
    
    if (currentBitInByte == 0) {
        return 0;
    }
    
    // Get value from the remaining bits of this byte
    return [self getDataBits:8 - currentBitInByte];
}

/*
 *  Object handling
 */

- (NSObject*) getObject
{
    // First get class name, which is stored as a compressed string
    NSString *className = [self getCompressedString];
    
    if (className == nil) {
        // State is already at error
        return nil;
    }
    
    return [self getObjectOfClassName:className];
}

- (NSObject*) getObjectOfClassName:(NSString*)className
{
    
    // Allocate the class from its name
    NSObject *object = [NSClassFromString(className) alloc];
    
    if ([[object class] conformsToProtocol:@protocol(BinarySerializing)]) {
        // Easy case: just use the method described in the protocol
        NSObject<BinarySerializing> *o = (NSObject<BinarySerializing>*) object;
        return [o initWithSerializer:self];
    }
    
    /*
     *  Convenience handling of some of the Cocoa classes so no subclassing is required
     */

    else if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        
        // Get length of array
        uint32 length = [self getUnsignedDataMaxValue:MAX_OBJECTS_IN_NSARRAY];
        
        // Iterate to get the objects
        for (uint32 i = 0; i < length; i++) {
            NSObject *o = [self getObject];
            if (o == nil) {
                return nil;
            }
            [array addObject:o];
        }
        
        // Got objects in array, return the stuff
        NSArray *a = (NSArray*)object;
        return [a initWithArray:array];
    }
    
    else if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        
        // Get amount of items
        uint32 length = [self getUnsignedDataMaxValue:MAX_OBJECTS_IN_NSDICTIONARY];
        
        // Iterate the objects and add to dictionary with keys
        for (uint32 i = 0; i < length; i++) {
            
            // First, get key
            
            NSString *name = [self getCompressedString];
            NSObject<NSCopying> *key = nil;
            
            // Special handling for NSString keys (to use shortChars)
            if ([name isEqualToString:@"MDSCString"]) {
                // Create a string from data
                NSString *keyData = nil;
                
                if (_useMinimalStringsForDictionaries) {
                    keyData = [self getMinimalString];
                } else {
                    keyData = [self getCompressedString];
                }
                
                // Initialize key
                NSString *actualKey = [NSString alloc];
                key = [actualKey initWithString:keyData];
            }
            // Other key objects are read as objects
            else {
                key = (NSObject<NSCopying>*)[self getObjectOfClassName:name];
            }
            
            // Key is now found, next get the saved object
            NSObject *o = [self getObject];
            
            if (key == nil || o == nil) {
                return nil;
            }
            
            // NOTE: NSCopying is not enforced in reading
            
            [dictionary setObject:o forKey:key];
        }
        
        // Got objects in dictionary, create and return the final piece
        NSDictionary *d = (NSDictionary*) object;
        return [d initWithDictionary:dictionary];
    }
    
    else if ([object isKindOfClass:[NSSet class]]) {
        NSMutableSet *set = [NSMutableSet set];
        
        // Get length of array
        uint32 length = [self getUnsignedDataMaxValue:MAX_OBJECTS_IN_NSSET];
        
        // Iterate to get the objects
        for (uint32 i = 0; i < length; i++) {
            NSObject *o = [self getObject];
            if (o == nil) {
                return nil;
            }
            [set addObject:o];
        }
        
        // Got objects in array, return the stuff
        NSSet *a = (NSSet*)object;
        return [a initWithSet:set];
    }
    
    else if ([object isKindOfClass:[NSString class]]) {
        if (_compressAllStrings) {
            // Read compressed string
            // NOTE: will not return NSMutableStrings!
            return [self getCompressedString];
        }
        else {
            // Full string saved in UTF8
            
            // Start getting some
            size_t t = 32;
            size_t i = 0;
            char *string = (char*)calloc(t, sizeof(char));
            if (string == NULL) {
                _state = ss_error;
                return nil;
            }
            do {
                string[i] = [self getDataBits:8];
                
                if (_state == ss_error) {
                    free(string);
                    return nil;
                }
                
                i++;
                
                // If string gets too short, double its size
                if (i >= t) {
                    t *= 2;
                    // Allocate new string
                    char *newString = (char*)calloc(t, sizeof(char));
                    
                    if (newString == NULL) {
                        free(string);
                        _state = ss_error;
                        return nil;
                    }
                    
                    // Copy old data
                    for (int j = 0; j < i; j++) {
                        newString[j] = string[j];
                    }
                    
                    free(string);
                    string = NULL;
                    string = newString;
                }
            } while (string[i-1] != '\0');

            NSString *str = [[NSString alloc] initWithBytes:string length:i - 1 encoding:NSUTF8StringEncoding];
            
            free(string);
            string = NULL;
            
            // NOTE: will not return NSMutableStrings!
            return str;

        }
    }
    
    // This object type cannot be deserialized
    return nil;
}

/*
 *  Actual getter method
 */

- (uint32) getDataBits:(uint32) bits
{
    if (_state != ss_deserializing) {
        _state = ss_error;
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
        trim = bits + startBit >= 8 ? 0 : bits;
        
        uint8 byte = _data.data[i] >> startBit;
        
        // Trim
        if (trim > 0) {
            byte = byte & (uint8)(pow(2, trim) - 1);
        }
        
        // Get bits
        value = value | (uint32)(byte << targetBit);
        
        // Change counters
        int bitsAdded = MIN(bits, 8 - startBit);
        bits -= bitsAdded;
        targetBit += bitsAdded;
        _bitIndex += bitsAdded;
    }
    
    // End deserializing when reached the end of data
    if (_bitIndex == 8 * _data.count) {
        _state = ss_doneDeserializing;
        //NSLog(@"Done deserializing");
    }
    
    return value;
}


@end
