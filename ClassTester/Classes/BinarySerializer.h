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

// Serializing
- (BOOL) startSerializing;
- (BOOL) startSerializingWithByteCount:(int) count;
- (BOOL) addData:(uint32)data maxValue:(uint32)maxValue;
- (BOOL) addData:(uint32) data bits:(uint32) bits;
- (SerializedData*) finalizeSerializing;

// Deserializing
- (BOOL) startDeserializingWith:(SerializedData*) data;
- (uint32) getDataMaxValue:(uint32)maxValue;
- (uint32) getDataBits:(uint32) bits;

- (BOOL) addOnes:(int) amount;
- (BOOL) addZeros:(int) amount;

- (SerializedData*) getData;

@end
