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


@class MMVimController;


@protocol MMVimControllerDelegate <NSObject>

@required
- (void)controller:(MMVimController *)controller openWindowWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller handleShowDialogWithButtonTitles:(NSArray *)buttonTitles style:(NSAlertStyle)style message:(NSString *)message text:(NSString *)text textFieldString:(NSString *)string data:(NSData *)data;
- (void)controller:(MMVimController *)controller showScrollbarWithIdentifier:(int32_t)identifier state:(BOOL)state data:(NSData *)data; // TODO: make this optional
- (void)controller:(MMVimController *)controller setTextDimensionsWithRows:(int)rows columns:(int)columns isLive:(BOOL)live keepOnScreen:(BOOL)screen data:(NSData *)data; // TODO: make this optional
- (void)controller:(MMVimController *)controller showTabBarWithData:(NSData *)data;

@optional
- (void)controller:(MMVimController *)controller setVimState:(NSDictionary *)vimState data:(NSData *)data;
- (void)controller:(MMVimController *)controller setScrollbarThumbValue:(float)value proportion:(float)proportion identifier:(int32_t)identifier data:(NSData *)data;
- (void)controller:(MMVimController *)controller processFinishedForInputQueue:(NSArray *)inputQueue;
- (void)controller:(MMVimController *)controller setDefaultColorsBackground:(NSColor *)background foreground:(NSColor *)foreground data:(NSData *)data;
- (void)controller:(MMVimController *)controller adjustLinespace:(int)linespace data:(NSData *)data;
- (void)controller:(MMVimController *)controller setFont:(NSFont *)font data:(NSData *)data;
- (void)controller:(MMVimController *)controller setWideFont:(NSFont *)font data:(NSData *)data;
- (void)controller:(MMVimController *)controller createScrollbarWithIdentifier:(int32_t)identifier type:(int)type data:(NSData *)data;
- (void)controller:(MMVimController *)controller setMouseShape:(int)shape data:(NSData *)data;
- (void)controller:(MMVimController *)controller setStateToolbarItemWithIdentifier:(NSString *)identifier state:(BOOL)state;
- (void)controller:(MMVimController *)controller addToolbarItemWithLabel:(NSString *)label tip:(NSString *)tip icon:(NSString *)icon atIndex:(int)idx;
- (void)controller:(MMVimController *)controller showToolbar:(BOOL)enable flags:(int)flags data:(NSData *)data;
- (void)controller:(MMVimController *)controller setBufferModified:(BOOL)modified data:(NSData *)data;
- (void)controller:(MMVimController *)controller setWindowTitle:(NSString *)title data:(NSData *)data;
- (void)controller:(MMVimController *)controller setDocumentFilename:(NSString *)filename data:(NSData *)data;
- (void)controller:(MMVimController *)controller setScrollbarPosition:(int)position length:(int)length identifier:(int32_t)identifier data:(NSData *)data;
- (void)controller:(MMVimController *)controller setPreEditRow:(int)row column:(int)column data:(NSData *)data;
- (void)controller:(MMVimController *)controller setAntialias:(BOOL)antialias data:(NSData *)data;
- (void)controller:(MMVimController *)controller activateIm:(BOOL)activate data:(NSData *)data;
- (void)controller:(MMVimController *)controller setImControl:(BOOL)control data:(NSData *)data;
- (void)controller:(MMVimController *)controller addToMru:(NSArray *)filenames data:(NSData *)data;
- (void)controller:(MMVimController *)controller tabShouldUpdateWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller tabDidUpdateWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller tabDraggedWithData:(NSData *)data;

// evaluate whether optional or required...
- (void)controller:(MMVimController *)controller setWindowPosition:(NSPoint)position data:(NSData *)data; // Vim measures Y-coordinates from top of screen.
- (void)controller:(MMVimController *)controller hideTabBarWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller destroyScrollbarWithIdentifier:(int32_t)identifier data:(NSData *)data;
- (void)controller:(MMVimController *)controller activateWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller enterFullScreen:(int)screen backgroundColor:(NSColor *)color data:(NSData *)data;
- (void)controller:(MMVimController *)controller leaveFullScreenWithData:(NSData *)data;
- (void)controller:(MMVimController *)controller setFullScreenBackgroundColor:(NSColor *)color data:(NSData *)data;
- (void)controller:(MMVimController *)controller showFindReplaceDialogWithText:(id)text flags:(int)flags data:(NSData *)data;
- (void)controller:(MMVimController *)controller zoomWithRows:(int)rows columns:(int)columns state:(int)state data:(NSData *)data;
- (void)controller:(MMVimController *)controller handleBrowseWithDirectoryUrl:(NSURL *)url browseDir:(BOOL)dir saving:(BOOL)saving data:(NSData *)data;
- (void)controller:(MMVimController *)controller dropFiles:(NSArray *)filenames forceOpen:(BOOL)force;
- (void)controller:(MMVimController *)controller removeToolbarItemWithIdentifier:(NSString *)identifier;
- (void)controller:(MMVimController *)controller setTooltipDelay:(float)delay;

@end
