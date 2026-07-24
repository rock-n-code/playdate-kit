//
//  CPlaydate.h
//  Umbrella header exposing the Playdate C API to Swift.
//
//  pd_api.h is resolved through the "playdate" pkg-config module, which
//  points at $PLAYDATE_SDK_PATH/C_API. Run Scripts/install-pkgconfig.sh
//  once to set that up.
//

#ifndef CPLAYDATE_H
#define CPLAYDATE_H

// The C API only declares the event/system types for extension builds.
#ifndef TARGET_EXTENSION
#define TARGET_EXTENSION 1
#endif

#include "pd_api.h"

// Swift cannot call variadic C function pointers such as
// playdate->system->logToConsole. These shims route a plain string through
// the "%s" format, which also avoids format-string injection.

static inline void cplaydate_log(PlaydateAPI *playdate, const char *message)
{
	playdate->system->logToConsole("%s", message);
}

static inline void cplaydate_error(PlaydateAPI *playdate, const char *message)
{
	playdate->system->error("%s", message);
}

#endif /* CPLAYDATE_H */
