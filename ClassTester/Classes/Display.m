//
//  Display.m
//  ClassTester
//
//  Created by Jussi Enroos on 19.4.2014.
//  Copyright (c) 2014 Jussi Enroos. All rights reserved.
//

#import "Display.h"
#import "BinarySerializer.h"

@interface Display ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation Display

-(void)awakeFromNib
{
    BinarySerializer *serializer = [[BinarySerializer alloc] init];
    
    [serializer startSerializingWithByteCount:5];
    [serializer addData:1549 maxValue:2500];
    [serializer addData:543765 maxValue:600000];
    [serializer addOnes:10];
    [serializer addZeros:5];
    [serializer addOnes:31];
    
    //SerializedData *data = [serializer getData];
    SerializedData *data = [serializer finalizeSerializing];
    
    [self writeLine:[data bitString]];
    
    [serializer startDeserializingWith:data];
    uint32 firstVal = [serializer getDataMaxValue:2500];
    uint32 secondVal = [serializer getDataMaxValue:600000];
    
    [self writeLine:[NSString stringWithFormat:@"Got data: %u %u", firstVal, secondVal]];
    
    [self writeLine:[NSString stringWithFormat:@"%u", (uint8)(0xff - (pow(2, 7) - 1))]];
    
}

- (void) writeLine:(NSString*)line
{
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", line]];
    [[_textView textStorage] appendAttributedString:astr];
}
@end
