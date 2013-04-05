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

@end
