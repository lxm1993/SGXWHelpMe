//
//  NSString+md5String.m
//  Need
//
//  Created by Cheng Jimmy on 14-12-22.
//  Copyright (c) 2014年 weplanter. All rights reserved.
//

#import "NSString+md5String.h"

@implementation NSString (md5String)

-(NSString *) md5HexDigest
{
    if(self == nil || [self length] == 0)
        return nil;
    
    const char *original_str = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(original_str, (CC_LONG)strlen(original_str), result);
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD2_DIGEST_LENGTH *2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [hash appendFormat:@"%02X", result[i]];
    return [hash lowercaseString];
}

@end
