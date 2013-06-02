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
#import "MacVim.h"

#import "MMUserDefaults.h"
#import "MMTypes.h"


// TODO: Remove this when the inline IM code has been tested
#define INCLUDE_OLD_IM_CODE


// NSUserDefaults keys
extern NSString *MMTopLeftPointKey;
extern NSString *MMOpenInCurrentWindowKey;
extern NSString *MMUntitledWindowKey;
extern NSString *MMTexturedWindowKey;
extern NSString *MMZoomBothKey;
extern NSString *MMCurrentPreferencePaneKey;
extern NSString *MMLastWindowClosedBehaviorKey;
#ifdef INCLUDE_OLD_IM_CODE
extern NSString *MMUseInlineImKey;
#endif // INCLUDE_OLD_IM_CODE
extern NSString *MMSuppressTerminationAlertKey;
extern NSString *MMNativeFullScreenKey;


// Enum for MMUntitledWindowKey
enum {
    MMUntitledWindowNever = 0,
    MMUntitledWindowOnOpen = 1,
    MMUntitledWindowOnReopen = 2,
    MMUntitledWindowAlways = 3
};

// Enum for MMLastWindowClosedBehaviorKey
enum {
    MMDoNothingWhenLastWindowClosed = 0,
    MMHideWhenLastWindowClosed = 1,
    MMTerminateWhenLastWindowClosed = 2,
};


@interface NSIndexSet (MMExtras)
+ (id)indexSetWithVimList:(NSString *)list;
@end


@interface NSDocumentController (MMExtras)
- (void)noteNewRecentFilePath:(NSString *)path;
- (void)noteNewRecentFilePaths:(NSArray *)paths;
@end


@interface NSSavePanel (MMExtras)
- (void)hiddenFilesButtonToggled:(id)sender;
#if (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6)
// This method is a part of a public API as of Mac OS X 10.6.  Only use this
// hack for earlier versions of Mac OS X.
- (void)setShowsHiddenFiles:(BOOL)show;
#endif
@end


@interface NSMenu (MMExtras)
- (int)indexOfItemWithAction:(SEL)action;
- (NSMenuItem *)itemWithAction:(SEL)action;
- (NSMenu *)findMenuContainingItemWithAction:(SEL)action;
- (NSMenu *)findWindowsMenu;
- (NSMenu *)findApplicationMenu;
- (NSMenu *)findServicesMenu;
- (NSMenu *)findFileMenu;
@end


@interface NSToolbar (MMExtras)
- (NSUInteger)indexOfItemWithItemIdentifier:(NSString *)identifier;
- (NSToolbarItem *)itemAtIndex:(NSUInteger)idx;
- (NSToolbarItem *)itemWithItemIdentifier:(NSString *)identifier;
@end


@interface NSNumber (MMExtras)
// HACK to allow font size to be changed via menu (bound to Cmd+/Cmd-)
- (NSInteger)tag;
@end



// Create a view with a "show hidden files" button to be used as accessory for
// open/save panels.  This function assumes ownership of the view so do not
// release it.
NSView *showHiddenFilesView();

