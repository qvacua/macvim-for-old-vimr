/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMCocoaCategories.h"


@implementation NSString (MMExtras)

- (NSString *)stringByEscapingSpecialFilenameCharacters {
    // NOTE: This code assumes that no characters already have been escaped.
    NSMutableString *string = [self mutableCopy];

    [string replaceOccurrencesOfString:@"\\"
                            withString:@"\\\\"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@" "
                            withString:@"\\ "
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"\t"
                            withString:@"\\\t "
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"%"
                            withString:@"\\%"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"#"
                            withString:@"\\#"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"|"
                            withString:@"\\|"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"\""
                            withString:@"\\\""
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];

    return [string autorelease];
}

- (NSString *)stringByRemovingFindPatterns {
    // Remove some common patterns added to search strings that other apps are
    // not aware of.

    NSMutableString *string = [self mutableCopy];

    // Added when doing * search
    [string replaceOccurrencesOfString:@"\\<"
                            withString:@""
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"\\>"
                            withString:@""
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    // \V = match whole word
    [string replaceOccurrencesOfString:@"\\V"
                            withString:@""
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];
    // \c = case insensitive, \C = case sensitive
    [string replaceOccurrencesOfString:@"\\c"
                            withString:@""
                               options:NSCaseInsensitiveSearch | NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];

    return [string autorelease];
}

- (NSString *)stringBySanitizingSpotlightSearch {
    // Limit length of search text
    NSUInteger len = [self length];
    if (len > 1024) len = 1024;
    else if (len == 0) return self;

    NSMutableString *string = [[[self substringToIndex:len] mutableCopy]
            autorelease];

    // Ignore strings with control characters
    NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
    NSRange r = [string rangeOfCharacterFromSet:controlChars];
    if (r.location != NSNotFound)
        return nil;

    // Replace ' with '' since it is used as a string delimeter in the command
    // that we pass on to Vim to perform the search.
    [string replaceOccurrencesOfString:@"'"
                            withString:@"''"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];

    // Replace \ with \\ to avoid Vim interpreting it as the beginning of a
    // character class.
    [string replaceOccurrencesOfString:@"\\"
                            withString:@"\\\\"
                               options:NSLiteralSearch
                                 range:NSMakeRange(0, [string length])];

    return string;
}

@end // NSString (MMExtras)



@implementation NSColor (MMExtras)

+ (NSColor *)colorWithRgbInt:(unsigned)rgb {
    float r = ((rgb >> 16) & 0xff) / 255.0f;
    float g = ((rgb >> 8) & 0xff) / 255.0f;
    float b = (rgb & 0xff) / 255.0f;

    return [NSColor colorWithDeviceRed:r green:g blue:b alpha:1.0f];
}

+ (NSColor *)colorWithArgbInt:(unsigned)argb {
    float a = ((argb >> 24) & 0xff) / 255.0f;
    float r = ((argb >> 16) & 0xff) / 255.0f;
    float g = ((argb >> 8) & 0xff) / 255.0f;
    float b = (argb & 0xff) / 255.0f;

    return [NSColor colorWithDeviceRed:r green:g blue:b alpha:a];
}

@end // NSColor (MMExtras)


@implementation NSDictionary (MMExtras)

+ (id)dictionaryWithData:(NSData *)data {
    id plist = [NSPropertyListSerialization
            propertyListFromData:data
                mutabilityOption:NSPropertyListImmutable
                          format:NULL
                errorDescription:NULL];

    return [plist isKindOfClass:[NSDictionary class]] ? plist : nil;
}

- (NSData *)dictionaryAsData {
    return [NSPropertyListSerialization dataFromPropertyList:self
                                                      format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
}

@end


@implementation NSMutableDictionary (MMExtras)

+ (id)dictionaryWithData:(NSData *)data {
    id plist = [NSPropertyListSerialization
            propertyListFromData:data
                mutabilityOption:NSPropertyListMutableContainers
                          format:NULL
                errorDescription:NULL];

    return [plist isKindOfClass:[NSMutableDictionary class]] ? plist : nil;
}

@end


@implementation NSMenuItem (MMExtras)

- (NSData *)descriptorAsDataForVim {
    NSMutableArray *desc = [NSMutableArray arrayWithObject:[self title]];

    NSMenu *menu = [self menu];
    while (menu) {
        [desc insertObject:[menu title] atIndex:0];
        menu = [menu supermenu];
    }

    // The "MainMenu" item is part of the Cocoa menu and should not be part of
    // the descriptor.
    if ([[desc objectAtIndex:0] isEqual:@"MainMenu"])
        [desc removeObjectAtIndex:0];

    return [@{@"descriptor" : desc} dictionaryAsData];
}

@end


@implementation NSTabView (MMExtras)

- (void)removeAllTabViewItems {
    NSArray *existingItems = [self tabViewItems];
    NSEnumerator *e = [existingItems objectEnumerator];
    NSTabViewItem *item;
    while ((item = [e nextObject])) {
        [self removeTabViewItem:item];
    }
}

@end