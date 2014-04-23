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
    for (int i = 0; i < 1; i++) {
        BinarySerializer *serializer = [[BinarySerializer alloc] init];
        
        [serializer startSerializingWithByteCount:5];
        /*[serializer addUnsignedData:1549 maxValue:2500];
         [serializer addUnsignedData:543765 maxValue:600000];
         sint32 value = -43765;
         [serializer addSignedData:value maxValue:600000];
         [serializer addOnes:10];*/
        [serializer addMinimalString:@"This is ä test string öä and stuff yea"]; // ä and stuff"];
        
        for (int i = 0; i < 32; i++) {
            [serializer addUnsignedData:i bits:5];
        }
            //[serializer addZeros:5];
            //[serializer addOnes:31];
            
            //SerializedData *data = [serializer getData];
            SerializedData *data = [serializer finalizeSerializing];
        
        [self writeLine:[data bitString]];
        
        [serializer startDeserializingWith:data];

        /*for (int i = 0; i < 32; i++) {
            uint32 j = [serializer getUnsignedDataBits:5];
            NSLog(@"data: %u", j);
        }*/

        /*uint32 firstVal = [serializer getUnsignedDataMaxValue:2500];
         uint32 secondVal = [serializer getUnsignedDataMaxValue:600000];
         sint32 thirdVal = [serializer getSignedDataMaxValue:600000];
         [serializer getUnsignedDataBits:10];*/
        NSString *string = [serializer getMinimalString];
        
        [self writeLine:[NSString stringWithFormat:@"Got String: %@", string]];
        
        string = [serializer getMinimalString];
        
        [self writeLine:[NSString stringWithFormat:@"Got String: %@", string]];
        //[self writeLine:[NSString stringWithFormat:@"Test data: %u %d", thirdVal, thirdVal]];
        
        //[self writeLine:[NSString stringWithFormat:@"Got data: %u %u", firstVal, secondVal]];
        
        //[self writeLine:[NSString stringWithFormat:@"%u", (uint8)(0xff - (pow(2, 7) - 1))]];
        
        if (i == 99) {
            [self writeLine:[data bitString]];
        }
    }
    
    
}

- (void) writeLine:(NSString*)line
{
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", line]];
    [[_textView textStorage] appendAttributedString:astr];
}
@end
