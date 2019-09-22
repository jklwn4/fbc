/* flush file buffers to disk (or writable device)*/

#include "fb.h"

int fb_FileFlushEx( FB_FILE *handle )
{
    int res;

    FB_LOCK();

    if( !FB_HANDLE_USED(handle) )
    {
        FB_UNLOCK();
        return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );
    }

    switch( handle->mode )
    {
    case FB_FILE_MODE_BINARY:
    case FB_FILE_MODE_RANDOM:
    case FB_FILE_MODE_OUTPUT:
    case FB_FILE_MODE_APPEND:
        break;
    default:
        FB_UNLOCK();
        return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );
        break;
    }

    if( handle->hooks && handle->hooks->pfnFlush )
    {
        res = handle->hooks->pfnFlush( handle );
    }
    else
    {
        res = fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );
    }

    FB_UNLOCK();

    return res;
}

/*:::::*/
FBCALL int fb_FileFlush( int fnum )
{
    return fb_FileFlushEx(FB_FILE_TO_HANDLE(fnum));
}