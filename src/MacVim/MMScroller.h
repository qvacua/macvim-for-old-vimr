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


// Scroller type; these must match SBAR_* in gui.h
enum {
    MMScrollerTypeLeft = 0,
    MMScrollerTypeRight,
    MMScrollerTypeBottom
};


@interface MMScroller : NSScroller {
    int32_t identifier;
    int type;
    NSRange range;
}

@property (assign) MMVimController *vimController;

- (id)initWithIdentifier:(int32_t)ident type:(int)type;
- (int32_t)scrollerId;
- (int)type;
- (NSRange)range;
- (void)setRange:(NSRange)newRange;

@end