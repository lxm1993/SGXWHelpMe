//
//  NSString+md5String.h
//  Need
//
//  Created by Cheng Jimmy on 14-12-22.
//  Copyright (c) 2014年 weplanter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
@interface NSString (md5String)

-(NSString *) md5HexDigest;

@end
