#ifndef __VAD_H__
#define __VAD_H__

#include <math.h>
#include <stdio.h>
#include "detectvadres.h"

const float pi = 3.1415926;
const float eps = 2.2204e-16; 

class Client_Vad
{
private:
    int m_max_wav_len; 
    short *m_raw_wav;
    int m_reserve_len;
    int m_wav_len;
    
    short *m_out_wav;
    int m_out_wav_len;

    int m_pre_reserve_len;
    short *m_out_wav_pre;
    int m_out_wav_pre_len;

    int m_frame_sum;
    int m_win_size;
    int m_shift_size;
    float *m_ana_win;

    float m_alfa_ff;
    float m_alfa_sf;
    float m_beta_sf;
    float m_alfa_snr;

    int m_fft_size;         // fft size
    int m_log_fft_size;     // log of fft size
    int *m_rev;             // reverse data for fft
    float *m_sin_fft;       // sine data for fft
    float *m_cos_fft;       // cosine data for fft
    
    float *m_win_wav;
    float *m_v_re;
    float *m_v_im;
    int m_sp_size;
    float *m_sp;
    float *m_sp_smooth;
    float *m_sp_ff;
    float *m_sp_sf;
    float *m_sp_ff_pre;
    float *m_sp_snr;
    int m_freq_win_len;
    float *m_freq_win;
    
    int m_fs;
    int m_ind_2k;
    int m_ind_4k;
    int m_ind_6k;
    float m_thres_02;
    float m_thres_24;
    float m_thres_46;
    float m_thres_68;

    int initial_fft();
    int fft_dit( const float *x, float *v_re, float *v_im );
    int detect_sp_ratio( int pack_id, int &speech_num, int &non_speech_num );
    
public:
    Client_Vad( int fs, int win_size, int shift_size, int seg_max_len, int pre_reserve_len,
                float alfa_ff, float alfa_sf, float beta_sf, float alfa_snr,
                float thres02, float thres24, float thres46, float thres68, 
                int fft_size, int freq_win_len );
    ~Client_Vad();
     
    int detect_speech(  short raw_wav[], int length, int pack_id, CVadRes &res );
    int output_speech(  short out_wav[], int &length ); 
    int reserve_pre_speech();
    int output_pre_speech( short out_wav[], int &length );
};

#endif
