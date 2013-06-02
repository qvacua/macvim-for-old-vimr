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


@interface NSString (MMExtras)

- (NSString *)stringByEscapingSpecialFilenameCharacters;
- (NSString *)stringByRemovingFindPatterns __unused;
- (NSString *)stringBySanitizingSpotlightSearch;

@end


@interface NSColor (MMExtras)

+ (NSColor *)colorWithRgbInt:(unsigned)rgb;
+ (NSColor *)colorWithArgbInt:(unsigned)argb;

@end


@interface NSDictionary (MMExtras)

+ (id)dictionaryWithData:(NSData *)data;
- (NSData *)dictionaryAsData;

@end


@interface NSMutableDictionary (MMExtras)

+ (id)dictionaryWithData:(NSData *)data;

@end


@interface NSMenuItem (MMExtras)

- (NSData *)descriptorAsDataForVim;

@end


@interface NSTabView (MMExtras)

- (void)removeAllTabViewItems;

@end