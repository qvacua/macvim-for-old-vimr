/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import <Foundation/Foundation.h>


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
@end