/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMScroller.h"
#import "MMWindowController.h"
#import "MMVimController.h"
#import "MMVimView.h"
#import "MMTextView.h"


@implementation MMScroller

- (id)initWithIdentifier:(int32_t)ident type:(int)theType {
    // HACK! NSScroller creates a horizontal scroller if it is init'ed with a
    // frame whose with exceeds its height; so create a bogus rect and pass it
    // to initWithFrame.
    NSRect frame = theType == MMScrollerTypeBottom
            ? NSMakeRect(0, 0, 1, 0)
            : NSMakeRect(0, 0, 0, 1);

    self = [super initWithFrame:frame];
    if (!self) return nil;

    identifier = ident;
    type = theType;
    [self setHidden:YES];
    [self setEnabled:YES];
    [self setAutoresizingMask:NSViewNotSizable];

    return self;
}

- (int32_t)scrollerId {
    return identifier;
}

- (int)type {
    return type;
}

- (NSRange)range {
    return range;
}

- (void)setRange:(NSRange)newRange {
    range = newRange;
}

- (void)scrollWheel:(NSEvent *)event {
    // HACK! Pass message on to the text view.
    NSView *vimView = [self superview];
    if ([vimView isKindOfClass:[MMVimView class]])
        [[(MMVimView *) vimView textView] scrollWheel:event];
}

- (void)mouseDown:(NSEvent *)event {
    // TODO: This is an ugly way of getting the connection to the backend.
    NSConnection *connection = nil;
    id wc = [[self window] windowController];
    if ([wc isKindOfClass:[MMWindowController class]]) {
        MMVimController *vc = [(MMWindowController *) wc vimController];
        id proxy = [vc backendProxy];
        connection = [(NSDistantObject *) proxy connectionForProxy];
    }

    // NOTE: The scroller goes into "event tracking mode" when the user clicks
    // (and holds) the mouse button.  We have to manually add the backend
    // connection to this mode while the mouse button is held, else DO messages
    // from Vim will not be processed until the mouse button is released.
    [connection addRequestMode:NSEventTrackingRunLoopMode];
    [super mouseDown:event];
    [connection removeRequestMode:NSEventTrackingRunLoopMode];
}

@end