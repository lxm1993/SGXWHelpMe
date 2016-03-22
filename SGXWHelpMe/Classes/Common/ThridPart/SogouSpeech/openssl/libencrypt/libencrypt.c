#include "libencrypt.h"


static char   basis_64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

int s_cookie_encrypt(const char *plain_text, char *encrypt_data, 
        int *encrypt_data_len)
{
    if(NULL == plain_text || strlen(plain_text) == 0 || NULL == encrypt_data)
    {
#ifdef __DEBUG__
        printf("[%s:%d] Illegal params in s_cookie_encrypt().\n", 
                __FILE__, __LINE__);
#endif
        return -1;
    }
    int rand_int = get_rand();
#ifdef __DEBUG__
    printf("rand:%d\n", rand_int);
#endif
    char cur_time[TIME_LEN + 1] = {'\0'};
    if(get_cur_time(cur_time) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] get_cur_time error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("cur_time:%s\n", cur_time);
#endif
    const Byte key_1[KEY_LEN + 1] = "6E09C97EB8798EEB";
    char message_1[MAX_TEXT_LEN + 1] = {0};
    snprintf(message_1, MAX_TEXT_LEN + 1, "%s%d%s", 
            cur_time, rand_int, plain_text);
    char raw_rand_mask[MD5_RES_LEN + 1] = {'\0'};
    if(get_md5((Byte *)message_1, strlen(message_1), raw_rand_mask) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] get_md5 error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("raw_rand_mask:%s\n", raw_rand_mask);
#endif
    char rand_mask[RAND_MASK_LEN + 1] = {'\0'};
    strncpy(rand_mask, raw_rand_mask, RAND_MASK_LEN);
    rand_mask[RAND_MASK_LEN] = '\0';
#ifdef __DEBUG__
    printf("rand_mask:%s\n", rand_mask);
#endif
    char message_2[MAX_TEXT_LEN + 1] = {'\0'};
    snprintf(message_2, MAX_TEXT_LEN + 1, "%s%d%s", cur_time, rand_int, key_1);
    char raw_key_2[MD5_RES_LEN + 1] = {'\0'};
    if(get_md5((Byte *)message_2, strlen(message_2), raw_key_2) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] get_md5 error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
    char key_2[KEY_LEN + 1] = {'\0'};
    strncpy(key_2, raw_key_2 + MD5_RES_LEN - 16, KEY_LEN);
    key_2[KEY_LEN] = '\0';
#ifdef __DEBUG__
    printf("key_2:%s\n", key_2);
#endif
    char upload_raw_data[MAX_TEXT_LEN + 1] = {'\0'};
    snprintf(upload_raw_data, MAX_TEXT_LEN + 1, "%s|%s", plain_text, rand_mask);
    
    //process1:zip
    Byte zip_data[MAX_DATA_LEN + 1] = {0};
    int zip_data_len = MAX_DATA_LEN + 1;
    if(zip_compress((Byte *)upload_raw_data, strlen(upload_raw_data),
                zip_data, &zip_data_len) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] zip_compress error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("zip_data_len:%d\n", zip_data_len);
#endif
#ifdef __DEBUG__
    printf("zip_data:");
    for(int i = 0; i < zip_data_len; i++)
    {
        char tmp_char = (char) zip_data[i];
        if(i < zip_data_len - 1)
            printf("%d,", (int)tmp_char);
        else 
            printf("%d\n", (int)tmp_char);
    }
#endif

    //process2:ase encrypt with key_2
    Byte zip_key2aes_data[MAX_DATA_LEN + 1] = {0};
    int zip_key2aes_data_len = MAX_DATA_LEN + 1;
    if(aes_encrypt(zip_data, zip_data_len, zip_key2aes_data, 
                &zip_key2aes_data_len, (Byte *)key_2) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] aes with key_2 error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("zip_key2aes_data_len:%d\n", zip_key2aes_data_len);
#endif
#ifdef __DEBUG__
    printf("zip_key2aes_data:");
    for(int i = 0; i < zip_key2aes_data_len; i++)
    {
        char tmp_char = (char)zip_key2aes_data[i];
        if(i < zip_key2aes_data_len - 1)
            printf("%d,", (int)tmp_char);
        else
            printf("%d\n", (int)tmp_char);
    }
#endif

    //process3:first base64
    char zip_key2aes_base64_data[MAX_DATA_LEN + 1] = {0} ;
    int zip_key2aes_base64_data_len = MAX_DATA_LEN + 1;
    if(base64_encode_openssl(zip_key2aes_data, zip_key2aes_data_len,
                zip_key2aes_base64_data, &zip_key2aes_base64_data_len) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] first base64 error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("zip_key2aes_base64_data:%s\n", zip_key2aes_base64_data);
#endif

    //process4:aes encrpyt with key_1
    char tmp_aes_enc_input_str[MAX_TEXT_LEN + 1] = {'\0'};
    snprintf(tmp_aes_enc_input_str, MAX_TEXT_LEN + 1, "%s|%d|%s", 
            cur_time, rand_int, zip_key2aes_base64_data);
    Byte upload_byte_data[MAX_DATA_LEN + 1] = {0};
    int upload_byte_data_len = MAX_DATA_LEN + 1;
    if(aes_encrypt((Byte *)tmp_aes_enc_input_str, strlen(tmp_aes_enc_input_str), 
                upload_byte_data, &upload_byte_data_len, key_1) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] second aes encrypt error.\n", __FILE__, __LINE__);    
#endif
        return -1;
    }


    //process5:second base64
    if(base64_encode_openssl(upload_byte_data, upload_byte_data_len,
                encrypt_data, encrypt_data_len) < 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] second base64 encode error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
#ifdef __DEBUG__
    printf("upload_data:%s\n", upload_byte_data);
#endif
    return 0;
}

int get_md5(Byte *src, int src_len, char *md5_res)
{
    if(NULL == src || src_len <= 0 || NULL == md5_res)
    {
#ifdef __DEBUG__
        printf("[%s:%d] Illegal params in get_md5.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
    Byte raw_md5[16] = {0};
    MD5(src, src_len, raw_md5);
    char tmp[3] = {0};
    int i = 0;
    for (i = 0; i < 16; i++)
    {
        snprintf(tmp, sizeof(tmp)/sizeof(char), "%2.2x", raw_md5[i]);
        tmp[2] = '\0';
        strncat(md5_res, tmp, 3);
    }
    md5_res[MD5_RES_LEN] = '\0';
    return 0;
}

/**
 * function: zip module, get the zip data from the raw data.
 * return: 0:success; -1:error; >0:unhandled raw data length
 * caution: if the raw_data is a string, raw_data_len=strlen(raw_data)
 */
int zip_compress(Byte *raw_data, int raw_data_len, Byte *zip_data, 
    int *zip_data_len)
{
    if(NULL == raw_data || raw_data_len <= 0 || NULL == zip_data || 
        NULL == zip_data_len || *zip_data_len <= 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d]Illegal param in zip_compress.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
    z_stream work_stream;
    int err = 0;
    work_stream.zalloc = (alloc_func)0;
    work_stream.zfree = (free_func)0;
    work_stream.opaque = (voidpf)0;
    if(deflateInit(&work_stream, Z_DEFAULT_COMPRESSION) != Z_OK) 
    {
#ifdef __DEBUG__
        printf("[%s:%d] Init zip_stream error.\n", 
                __FILE__, __LINE__);
#endif
        return -1;
    }
    work_stream.next_in = raw_data;
    work_stream.avail_in = raw_data_len;
    work_stream.next_out = zip_data;
    work_stream.avail_out = *zip_data_len;
    while (work_stream.avail_in != 0 && work_stream.total_out < *zip_data_len)
    {
        if(deflate(&work_stream, Z_NO_FLUSH) != Z_OK)
        {
#ifdef __DEBUG__
            printf("[%s:%d] zip error.\n", __FILE__, __LINE__);
#endif
            return -1;
        }
    }
    if(work_stream.avail_in != 0) 
    {
#ifdef __DEBUG__
        printf("[%s:%d] no enough place to store the zip data.\n", 
                __FILE__, __LINE__);
#endif
        return work_stream.avail_in;
    }
    for (;;)
    {
        if((err = deflate(&work_stream, Z_FINISH)) == Z_STREAM_END) 
            break;
        if(err != Z_OK) 
        {
#ifdef __DEBUG__
            printf("[%s:%d] zip error.\n", __FILE__, __LINE__);
#endif
            return -1;
        }
    }
    if(deflateEnd(&work_stream) != Z_OK) 
    {
#ifdef __DEBUG__
        printf("[%s:%d] zip error.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
    *zip_data_len = work_stream.total_out;
    return  0;
}

int aes_encrypt(Byte *raw_data, int raw_data_len, Byte *aes_enc_data, 
        int *aes_enc_data_len, const Byte *key_str)
{
    if(NULL == raw_data || raw_data_len <= 0 || NULL == aes_enc_data ||
            NULL == aes_enc_data_len || NULL == key_str || 
            0 == strlen((const char *)key_str))
    {
#ifdef __DEBUG__
        printf("[%s:%d] Illegal param in aes_encrypt().\n", 
                __FILE__, __LINE__);
#endif
        return -1;
    }
    AES_KEY aes_encrypt_key;
    if (AES_set_encrypt_key(key_str, 128, &aes_encrypt_key) < 0) 
    {
#ifdef __DEBUG__
        printf("[%s:%d] Unable to set ase_encrypt_key.\n", __FILE__, __LINE__);
#endif
        return -1;
    }
    int block_num = (raw_data_len - 1) / AES_BLOCK_SIZE + 1;
#ifdef __DEBUG__
    printf("block_num:%d\n", block_num);
#endif
    int i = 0;
    for(i = 0; i < block_num; i++)
    {
        if((i + 1)* AES_BLOCK_SIZE > *aes_enc_data_len)
        {
            *aes_enc_data_len = i * AES_BLOCK_SIZE;
#ifdef __DEBUG__
            printf("[%s:%d] Not enough place to store aes_enc_data.\n", 
                    __FILE__, __LINE__);
#endif
            return -1;
        }
        AES_ecb_encrypt(raw_data + i * AES_BLOCK_SIZE, 
                aes_enc_data + i * AES_BLOCK_SIZE, 
                &aes_encrypt_key, AES_ENCRYPT);
    }
    *aes_enc_data_len = block_num * AES_BLOCK_SIZE;
    return 0;
}



int base64_encode_openssl(Byte *raw_data, int raw_data_len, char *base64_enc_data,
        int *base64_enc_data_len)
{
    if(NULL == raw_data || raw_data_len <= 0 || NULL == base64_enc_data ||
            NULL == base64_enc_data_len || *base64_enc_data_len <= 0)
    {
#ifdef __DEBUG__
        printf("[%s:%d] Illegal params in base64_encode_openssl().\n", 
                __FILE__, __LINE__);
#endif
        return -1;
    }
    // change base64_enc_data_len to 0, add by yuanbin on 2013-08-07
    *base64_enc_data_len = 0;
    while(raw_data_len >= 3)
    {
       *base64_enc_data++ = basis_64[raw_data[0] >> 2];
       *base64_enc_data++ = basis_64[((raw_data[0] << 4) & 0x30) | 
           (raw_data[1] >> 4)];
       *base64_enc_data++ = basis_64[((raw_data[1] << 2) & 0x3C) | 
           (raw_data[2] >> 6)];
       *base64_enc_data++ = basis_64[raw_data[2] & 0x3F];
       raw_data += 3;
       raw_data_len -= 3;
       // change base64_enc_data_len, add by yuanbin on 2013-08-07
       *base64_enc_data_len += 4;
    }
    if(raw_data_len > 0)
    {
        *base64_enc_data++ = basis_64[raw_data[0] >> 2];
        int tmp_index = (raw_data[0] << 4) & 0x30 ;
        if(raw_data_len > 1)
            tmp_index |= raw_data[1] >> 4;
        *base64_enc_data++ = basis_64[tmp_index];
        *base64_enc_data++ = (raw_data_len < 2) ? '=' : 
            basis_64[(raw_data[1] << 2) & 0x3C];
        *base64_enc_data++ = '=';
        // add by yuanbin on 20123-08-07
        *base64_enc_data_len += 4;
    }
    *base64_enc_data = '\0';
    return 0;
}


/**
 * return a number between 10000~99999
 */
int get_rand()
{
    srand((unsigned int)time(NULL));
    int rand_int = rand() % 90000 + 10000;
    return rand_int;
}


int get_cur_time(char *cur_time_str)
{
    if(NULL == cur_time_str)
    {
#ifdef __DEBUG__
        printf("[%s:%d] Illegal param in get_cur_time().\n",
                __FILE__, __LINE__);
#endif
        return -1;
    }

    //replace tm pointer with tm, and replace localtime with localtime_r, 2013-07-29
    time_t raw_time;
    struct tm time_info;
    time(&raw_time);
    localtime_r(&raw_time, &time_info);
    snprintf(cur_time_str, TIME_LEN + 1, "%04d%02d%02d%02d%02d%02d", 
            time_info.tm_year + 1900,
            time_info.tm_mon + 1,
            time_info.tm_mday,
            time_info.tm_hour,
            time_info.tm_min,
            time_info.tm_sec);
    return 0;
}
