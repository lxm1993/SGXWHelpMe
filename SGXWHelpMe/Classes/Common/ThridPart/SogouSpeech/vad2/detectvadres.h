#ifndef __DETECTVADRES_H__
#define __DETECTVADRES_H__

#include <stdio.h>

class CVadRes
{
public :
    bool m_success;
    bool m_is_speech_found;
    bool m_is_speech;
    bool m_is_first_found;
    float m_begin_wait_time;
    float m_end_wait_time;
    
public :
    
    CVadRes( bool success = false, bool is_speech_found = false, 
             bool is_speech = false, bool is_first_found = false,
             float begin_wait_time = 0, float end_wait_time = 0 )
    : m_success(success), m_is_speech_found(is_speech_found), m_is_speech(is_speech_found), m_is_first_found( is_first_found ),
      m_begin_wait_time(begin_wait_time), m_end_wait_time(end_wait_time)
    {}


};



#endif
