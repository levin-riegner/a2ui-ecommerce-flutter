#import <Availability.h>

// Duo's full display area and reserved regions require the iOS 27.1 SDK.
#if !defined(__IPHONE_27_1) || __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_27_1
#error "Alder requires the iOS 27.1 SDK or newer. Select Xcode 27.1 or newer in Xcode, or set DEVELOPER_DIR for Flutter builds."
#endif

#import "GeneratedPluginRegistrant.h"
