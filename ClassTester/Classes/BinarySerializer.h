//
//  BinarySerializer.h
//  ClassTester
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    ss_none,
    ss_error,
    ss_serializing,
    ss_doneSerializing,
    ss_deserializing,
    ss_doneDeserializing,
} SerializingState;

@class BinarySerializer;


/*
 *  Interface, which must be conformed to by custom objects to be serialized
 */

@protocol BinarySerializing <NSObject>

@required
- (BOOL) serializeWithSerializer:(BinarySerializer*) serializer;
- (id) initWithSerializer:(BinarySerializer*) serializer;

@end



@interface SerializedData : NSObject

@property uint8* data;
@property uint32 count;

- (BOOL) mallocDataBytes:(uint32) size;
- (BOOL) doubleSize;
- (BOOL) resizeTo:(uint32) newSize;

- (NSString*) bitString;

@end


@interface BinarySerializer : NSObject

@property SerializingState state;
@property BOOL compressAllStrings;
@property BOOL useMinimalStringsForDictionaries;
@property BOOL forceOffsetOfNormalBytes;

/*
 *  Serializing
 */

- (BOOL) startSerializing;
- (BOOL) startSerializingWithByteCount:(int) count;

- (BOOL) addSignedData:(sint32)value maxValue:(uint32)maxValue;
- (BOOL) addSignedData:(sint32) value bits:(uint32) bits;

- (BOOL) addUnsignedData:(uint32)data maxValue:(uint32)maxValue;
- (BOOL) addUnsignedData:(uint32) data bits:(uint32) bits;

- (BOOL) addBoolean:(BOOL) value;
- (BOOL) addFloat:(float) value;
- (BOOL) addDouble:(double)value;

- (BOOL) addASCIIString:(NSString*) string;
- (BOOL) addCompressedString:(NSString*) string;
- (BOOL) addMinimalString:(NSString*) string;

/*
 *  NOTE: addObject: will not handle properly following object types:
 *  - Objects, which have non-ASCII characters in class name
 *  - NSDictionaries with keys, which are NSStrings with non-ASCII characters
 *
 *  These non-ASCII characters will be converted to ASCII (lossy conversion)
 *
 *  Supported Cocoa object types:
 *  - NSArray & NSMutableArray
 *  - NSDictionary & NSMutableDictionary
 *  - NSSet & NSMutableSet
 *  - NSString (mutable not available)
 */

- (BOOL) addObject:(NSObject*) object;

- (BOOL) addOnes:(int) amount;
- (BOOL) addZeros:(int) amount;

- (BOOL) addOnesToNextFullByte;

- (SerializedData*) finalizeSerializing;
- (BOOL) finalizeSerializingToFileURL:(NSURL*) url error:(NSError *__autoreleasing*) error;
- (BOOL) finalizeSerializingToFilePath:(NSString*) path error:(NSError *__autoreleasing*) error;


/*
 *  Deserializing
 */

- (BOOL) startDeserializingWith:(SerializedData*) data;
- (BOOL) startDeserializingWithFileURL:(NSURL*) url error:(NSError *__autoreleasing*) error;
- (BOOL) startDeserializingWithFilePath:(NSString*) path error:(NSError *__autoreleasing*) error;

- (uint32) getUnsignedDataMaxValue:(uint32)maxValue;
- (uint32) getUnsignedDataBits:(uint32) bits;

- (sint32) getSignedDataMaxValue:(uint32)maxValue;
- (sint32) getSignedDataBits:(uint32) bits;

- (BOOL) getBoolean;
- (float) getFloat;
- (double) getDouble;

- (uint32) getToNextByte;

- (NSString*) getASCIIString;
- (NSString*) getCompressedString;
- (NSString*) getMinimalString;

- (NSObject*) getObject;


@end
