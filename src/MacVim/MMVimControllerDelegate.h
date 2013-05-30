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

@optional
- (void)vimController:(MMVimController *)controller openWindowWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller batchDrawWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller updateTabsWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller showTabBarWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller hideTabBarWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller setTextDimensionsWithRows:(int)rows columns:(int)columns isLive:(BOOL)live keepOnScreen:(BOOL)screen data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setWindowTitle:(NSString *)title data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setDocumentFilename:(NSString *)filename data:(NSData *)data;
- (void)vimController:(MMVimController *)controller showToolbar:(BOOL)enable size:(NSToolbarSizeMode)size mode:(NSToolbarDisplayMode)mode data:(NSData *)data;
- (void)vimController:(MMVimController *)controller createScrollbarWithIdentifier:(int32_t)identifier type:(int)type data:(NSData *)data;
- (void)vimController:(MMVimController *)controller destroyScrollbarWithIdentifier:(int32_t)identifier data:(NSData *)data;
- (void)vimController:(MMVimController *)controller showScrollbarWithIdentifier:(int32_t)identifier state:(BOOL)state data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setScrollbarPosition:(int)position length:(int)length identifier:(int32_t)identifier data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setScrollbarThumbValue:(float)value proportion:(float)proportion identifier:(int32_t)identifier data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setFont:(NSFont *)font data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setWideFont:(NSFont *)font data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setDefaultColorsBackground:(NSColor *)background foreground:(NSColor *)foreground data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setMouseShape:(int)shape data:(NSData *)data;
- (void)vimController:(MMVimController *)controller adjustLinespace:(int)linespace data:(NSData *)data;
- (void)vimController:(MMVimController *)controller activateWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller enterFullScreen:(int)screen backgroundColor:(NSColor *)color data:(NSData *)data;
- (void)vimController:(MMVimController *)controller leaveFullScreenWithData:(NSData *)data;
- (void)vimController:(MMVimController *)controller setBufferModified:(BOOL)modified data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setPreEditRow:(int)row column:(int)column data:(NSData *)data;
- (void)vimController:(MMVimController *)controller setAntialias:(BOOL)antialias data:(NSData *)data;
@end