/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import <Cocoa/Cocoa.h>
#import <asl.h>

#import "MMLog.h"
#import "MMTypes.h"
#import "MMCocoaCategories.h"
#import "MMVimBackendProtocol.h"
#import "MMAppProtocol.h"

// Taken from /usr/include/AvailabilityMacros.h
#ifndef MAC_OS_X_VERSION_10_4
# define MAC_OS_X_VERSION_10_4 1040
#endif
#ifndef MAC_OS_X_VERSION_10_5
# define MAC_OS_X_VERSION_10_5 1050
#endif
#ifndef MAC_OS_X_VERSION_10_6
# define MAC_OS_X_VERSION_10_6 1060
#endif
#ifndef MAC_OS_X_VERSION_10_7
# define MAC_OS_X_VERSION_10_7 1070
#endif


enum {
    ClearAllDrawType = 1,
    ClearBlockDrawType,
    DeleteLinesDrawType,
    DrawStringDrawType,
    InsertLinesDrawType,
    DrawCursorDrawType,
    SetCursorPosDrawType,
    DrawInvertedRectDrawType,
    DrawSignDrawType,
};

enum {
    MMInsertionPointBlock,
    MMInsertionPointHorizontal,
    MMInsertionPointVertical,
    MMInsertionPointHollow,
    MMInsertionPointVerticalRight,
};


enum {
    ToolbarLabelFlag = 1,
    ToolbarIconFlag = 2,
    ToolbarSizeRegularFlag = 4
};


enum {
    MMTabLabel = 0,
    MMTabToolTip,
    MMTabInfoCount
};

enum {
    MMGestureSwipeLeft,
    MMGestureSwipeRight,
    MMGestureSwipeUp,
    MMGestureSwipeDown,
};


// Create a string holding the labels of all messages in message queue for
// debugging purposes (condense some messages since there may typically be LOTS
// of them on a queue).
NSString *debugStringForMessageQueue(NSArray *queue);


// Shared user defaults (most user defaults are in Miscellaneous.h).
// Contrary to the user defaults in Miscellaneous.h these defaults are not
// intitialized to any default values.  That is, unless the user sets them
// these keys will not be present in the user default database.

// Argument used to stop MacVim from opening an empty window on startup
// (techincally this is a user default but should not be used as such).
extern NSString *MMNoWindowKey;

extern NSString *MMAutosaveRowsKey;
extern NSString *MMAutosaveColumnsKey;
extern NSString *MMRendererKey;

enum {
    MMRendererDefault = 0,
    MMRendererATSUI,
    MMRendererCoreText
};


extern NSString *VimFindPboardType;

// ODB Editor Suite Constants (taken from ODBEditorSuite.h)
#define	keyFileSender		'FSnd'
#define	keyFileSenderToken	'FTok'
#define	keyFileCustomPath	'Burl'
#define	kODBEditorSuite		'R*ch'
#define	kAEModifiedFile		'FMod'
#define	keyNewLocation		'New?'
#define	kAEClosedFile		'FCls'
#define	keySenderToken		'Tokn'


// MacVim Apple Event Constants
#define keyMMUntitledWindow       'MMuw'




#ifndef NSINTEGER_DEFINED
// NSInteger was introduced in 10.5
# if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
# else
typedef int NSInteger;
typedef unsigned int NSUInteger;
# endif
# define NSINTEGER_DEFINED 1
#endif

#ifndef NSAppKitVersionNumber10_4  // Needed for pre-10.5 SDK
# define NSAppKitVersionNumber10_4 824
#endif

#ifndef CGFLOAT_DEFINED
    // On Leopard, CGFloat is float on 32bit and double on 64bit. On Tiger,
    // we can't use this anyways, so it's just here to keep the compiler happy.
    // However, when we're compiling for Tiger and running on Leopard, we
    // might need the correct typedef, so this piece is copied from ATSTypes.h
# ifdef __LP64__
    typedef double CGFloat;
# else
    typedef float CGFloat;
# endif
#endif

