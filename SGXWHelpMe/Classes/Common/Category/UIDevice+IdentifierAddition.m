//
//  UIDevice+IdentifierAddition.m
//  GlobalSources
//
//  Created by ChengPu on 14-5-27.
//  Copyright (c) 2014年 ChengPu. All rights reserved.
//

#import "UIDevice+IdentifierAddition.h"
#import "NSString+md5String.h"
#import "SSKeychain.h"

@interface UIDevice (Private)

- (NSString *) MACAddress;      //ios7+ 废弃
- (NSString *) vendorAddress;

@end

@implementation UIDevice (IdentifierAddition)

#pragma mark- private Methods

// Return the local MAC addy
// Courtesy of FreeBSD hackers email list
// Accidentally munged during previous update. Fixed thanks to erica sadun & mlamb.

// iOS7+废弃
//- (NSString *) MACAddress
//{
//    int                 mib[6];
//    size_t              len;
//    char                *buf;
//    unsigned char       *ptr;
//    struct if_msghdr    *ifm;
//    struct sockaddr_dl  *sdl;
//    
//    mib[0] = CTL_NET;
//    mib[1] = AF_ROUTE;
//    mib[2] = 0;
//    mib[3] = AF_LINK;
//    mib[4] = NET_RT_IFLIST;
//    
//    if ((mib[5] = if_nametoindex("en0")) == 0) {
//        printf("Error: if_nametoindex error\n");
//        return NULL;
//    }
//    
//    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0){
//        printf("Error: sysctl, take 1\n");
//        return NULL;
//    }
//    
//    if ((buf = malloc(len)) == NULL) {
//        printf("Could not allocate memory. error!\n");
//        return NULL;
//    }
//    
//    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
//        printf("Error: sysctl, take 2");
//        free(buf);
//        return NULL;
//    }
//    
//    ifm = (struct if_msghdr *)buf;
//    sdl = (struct sockaddr_dl *) (ifm + 1);
//    ptr = (unsigned char *)LLADDR(sdl);
//    NSString *outstring  = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X:",*ptr,*(ptr+1),*(ptr+2),*(ptr+3),*(ptr+4),*(ptr+5)];
//    free(buf);
//    
//    return outstring;
//}

- (NSString *) vendorAddress
{
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

    NSString *retrieveuuid = nil;
    
    NSError *error = nil;
    SSKeychainQuery *query = [[SSKeychainQuery alloc] init];
    query.service = bundleIdentifier;
    query.account = kDEVICEID;
    [query fetch:&error];
    
    if ([error code] == errSecItemNotFound) {
        NSLog(@"Password not found");
        retrieveuuid = self.identifierForVendor.UUIDString;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            query.password = retrieveuuid;
            BOOL isSaved = [query save:NULL];
            if (isSaved) {
                DLog(@"Password writed");
            }else{
                DLog(@"Password writed fail");
            }

        });
        
    } else if (error != nil) {
        NSLog(@"Some other error occurred: %@", [error localizedDescription]);
    }else{
        retrieveuuid = query.password;
    }
    
    return retrieveuuid;
}

#pragma mark- public Methods
- (NSString *) uniqueDeviceIdentifier
{
    NSString *vendorID = [self vendorAddress];
    NSAssert(vendorID != nil,@"唯一标示为空");
    DLog(@"VendorID == %@",vendorID);
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    NSString *stringToHash = [NSString stringWithFormat:@"%@+%@",vendorID,bundleIdentifier];
    
//    NSString *uniqueIdentifier = [stringToHash md5HexDigest];

    return stringToHash;
}

- (NSString *) uniqueGlobalDeviceIdentifier
{
    NSString *vendorID = [self vendorAddress];
    NSAssert(vendorID != nil,@"唯一标示为空");
    DLog(@"VendorID == %@",vendorID);

//    NSString *uniqueIdentifier = [vendorID md5HexDigest];
    return vendorID;
}

@end
