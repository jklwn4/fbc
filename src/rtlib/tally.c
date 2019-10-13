/* tally, count how many times t is in src */

#include "fb.h"

FBCALL ssize_t fb_StrTally ( char *src, int any, char *t )
{
    ssize_t n, x, y, slen, tlen;
    char *a, *c, *d;

    if( src != NULL )
        slen = strlen( src );
    else
        return 0;

    if( t != NULL )
        tlen = strlen( t );
    else
        return 0;

    a = src;
    n = 0;

    if (any == 0x414E59)                              //"any" prefixed
    {
        for (x = 0; x < slen; x++)
        {
            d = t;

            for (y = 0; y < tlen; y++)
            {
                if (*a == *d)
                {
                    n = n + 1;
                    goto exit1;
                }    
                d++;
            }  
exit1:
            a++;
        } 
    }
    else
    {  
        for (x = 0; x < slen - tlen + 1; x++)
        {
            if (*a == *t)
            {
                c = a + 1;
                d = t + 1;

                for (y = 1; y < tlen; y++)
                {
                    if (*c != *d) goto exit2;
                    c++;
                    d++;
                }  
                n = n + 1;
                a = a + tlen - 1;
            }
exit2:
            a++;
        } 
    }

    return n;
}

FBCALL ssize_t fb_WstrTally ( FB_WCHAR *src, int any, FB_WCHAR *t )
{
    ssize_t n, x, y, slen, tlen;
    FB_WCHAR *a, *c, *d;

    if( src != NULL )
        slen = fb_wstr_Len( src );
    else
        return 0;

    if( t != NULL )
        tlen = fb_wstr_Len( t );
    else
        return 0;

    a = src;
    n = 0;

    if (any == 0x414E59)                              //"any" prefixed
    {
        for (x = 0; x < slen; x++)
        {
            d = t;

            for (y = 0; y < tlen; y++)
            {
                if (*a == *d)
                {
                    n = n + 1;
                    goto exit1;
                }    
                d++;
            }  
exit1:
            a++;
        } 
    }
    else
    {  
        for (x = 0; x < slen - tlen + 1; x++)
        {
            if (*a == *t)
            {
                c = a + 1;
                d = t + 1;

                for (y = 1; y < tlen; y++)
                {
                    if (*c != *d) goto exit2;
                    c++;
                    d++;
                }  
                n = n + 1;
                a = a + tlen - 1;
            }
exit2:
            a++;
        } 
    }

    return n;
}
