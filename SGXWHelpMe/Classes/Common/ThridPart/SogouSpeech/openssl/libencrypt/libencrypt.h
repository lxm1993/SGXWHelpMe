#ifndef __LIBENCRYPT__H__
#define __LIBENCRYPT__H__

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include "md5.h"
#include "aes.h"
#include "zlib.h"

//just for debug, must delete it in standard version!!!
//#define __DEBUG__

#define MAX_TEXT_LEN    1024
#define MAX_DATA_LEN    1024
#define KEY_LEN         16
#define TIME_LEN        14
#define MD5_RES_LEN     32
#define RAND_MASK_LEN   10

typedef unsigned char   Byte;


int s_cookie_encrypt(const char *plain_text, char *encrypt_data, 
        int *encrypt_data_len);
int get_md5(Byte *src, int src_len, char *md5_res);
int zip_compress(Byte *raw_data, int raw_data_len, Byte *zip_data,
    int *zip_data_len);
int aes_encrypt(Byte *raw_data, int raw_data_len, Byte *aes_enc_data,
    int *aes_enc_data_len, const Byte *key_str);
int base64_encode_openssl(Byte *raw_data, int raw_data_len, char *base64_enc_data,
    int *base64_enc_data_len);
int get_rand();
int get_cur_time(char *cur_time_str);
#endif
