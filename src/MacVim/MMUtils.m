/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMUtils.h"
#import "MacVim.h"


// This is a private AppKit API gleaned from class-dump.
@interface NSKeyBindingManager : NSObject

+ (id)sharedKeyBindingManager;
- (id)dictionary;
- (void)setDictionary:(id)arg1;

@end


@implementation MMUtils

+ (void)setKeyHandlingUserDefaults {
    static BOOL prefSet = NO;

    if (prefSet) {
        return;
    }

    // HACK! The following user default must be reset, else Ctrl-q (or
    // whichever key is specified by the default) will be blocked by the input
    // manager (interpretKeyEvents: swallows that key).  (We can't use
    // NSUserDefaults since it only allows us to write to the registration
    // domain and this preference has "higher precedence" than that so such a
    // change would have no effect.)
    CFPreferencesSetAppValue(
            CFSTR("NSQuotedKeystrokeBinding"),
            CFSTR(""),
            kCFPreferencesCurrentApplication
    );

    // Also disable NSRepeatCountBinding -- it is not enabled by default, but
    // it does not make much sense to support it since Vim has its own way of
    // dealing with repeat counts.
    CFPreferencesSetAppValue(
            CFSTR("NSRepeatCountBinding"),
            CFSTR(""),
            kCFPreferencesCurrentApplication
    );

    prefSet = YES;
}

+ (void)setVimKeybindings {
    NSKeyBindingManager *mgr = [NSKeyBindingManager sharedKeyBindingManager];
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *path = [mainBundle pathForResource:@"KeyBinding"
                                          ofType:@"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (mgr && dict) {
        [mgr setDictionary:dict];
    } else {
        ASLogNotice(@"Failed to override the Cocoa key bindings.  Keyboard "
                "input may behave strangely as a result (path=%@).", path);
    }
}

@end


NSString *
normalizeFilename(NSString *filename)
{
    return [filename precomposedStringWithCanonicalMapping];
}

NSArray *
normalizeFilenames(NSArray *filenames)
{
    NSMutableArray *outnames = [NSMutableArray array];
    if (!filenames)
        return outnames;

    unsigned i, count = [filenames count];
    for (i = 0; i < count; ++i) {
        NSString *nfkc = normalizeFilename([filenames objectAtIndex:i]);
        [outnames addObject:nfkc];
    }

    return outnames;
}

// Create a string holding the labels of all messages in message queue for
// debugging purposes (condense some messages since there may typically be LOTS
// of them on a queue).
NSString *
debugStringForMessageQueue(NSArray *queue)
{
    NSMutableString *s = [NSMutableString new];
    unsigned i, count = [queue count];
    int item = 0, menu = 0, enable = 0, remove = 0;
    int sets = 0, sett = 0, shows = 0, cres = 0, dess = 0;
    for (i = 0; i < count; i += 2) {
        NSData *value = [queue objectAtIndex:i];
        int msgid = *((int*)[value bytes]);
        if (msgid < 1 || msgid >= LastMsgID)
            continue;
        if (msgid == AddMenuItemMsgID) ++item;
        else if (msgid == AddMenuMsgID) ++menu;
        else if (msgid == EnableMenuItemMsgID) ++enable;
        else if (msgid == RemoveMenuItemMsgID) ++remove;
        else if (msgid == SetScrollbarPositionMsgID) ++sets;
        else if (msgid == SetScrollbarThumbMsgID) ++sett;
        else if (msgid == ShowScrollbarMsgID) ++shows;
        else if (msgid == CreateScrollbarMsgID) ++cres;
        else if (msgid == DestroyScrollbarMsgID) ++dess;
        else [s appendFormat:@"%s ", MessageStrings[msgid]];
    }
    if (item > 0) [s appendFormat:@"AddMenuItemMsgID(%d) ", item];
    if (menu > 0) [s appendFormat:@"AddMenuMsgID(%d) ", menu];
    if (enable > 0) [s appendFormat:@"EnableMenuItemMsgID(%d) ", enable];
    if (remove > 0) [s appendFormat:@"RemoveMenuItemMsgID(%d) ", remove];
    if (sets > 0) [s appendFormat:@"SetScrollbarPositionMsgID(%d) ", sets];
    if (sett > 0) [s appendFormat:@"SetScrollbarThumbMsgID(%d) ", sett];
    if (shows > 0) [s appendFormat:@"ShowScrollbarMsgID(%d) ", shows];
    if (cres > 0) [s appendFormat:@"CreateScrollbarMsgID(%d) ", cres];
    if (dess > 0) [s appendFormat:@"DestroyScrollbarMsgID(%d) ", dess];

    return [s autorelease];
}