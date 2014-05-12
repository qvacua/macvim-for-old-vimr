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


@class PSMTabBarControl;
@class MMScroller;
@class MMVimController;
@protocol MMTextViewProtocol;


/*
 * MMVimView
 *
 * A view class with a tabline, scrollbars, and a text view.  The tabline may
 * appear at the top of the view in which case it fills up the view from left
 * to right edge.  Any number of scrollbars may appear adjacent to all other
 * edges of the view (there may be more than one scrollbar per edge and
 * scrollbars may also be placed on the left edge of the view).  The rest of
 * the view is filled by the text view.
 */
@interface MMVimView : NSView {
    PSMTabBarControl    *tabBarControl;
    NSTabView           *tabView;
    BOOL                vimTaskSelectedTab;
    NSView <MMTextViewProtocol> *textView;
    NSMutableArray      *scrollbars;
}

@property (assign) MMVimController *vimController;

- (MMVimView *)initWithFrame:(NSRect)frame vimController:(MMVimController *)c;

- (NSView <MMTextViewProtocol> *)textView;
- (void)cleanup;

- (NSSize)desiredSize;
- (NSSize)minSize;
- (NSSize)constrainRows:(int *)r columns:(int *)c toSize:(NSSize)size;
- (void)setDesiredRows:(int)r columns:(int)c;

- (PSMTabBarControl *)tabBarControl;
- (IBAction)addNewTab:(id)sender;
- (void)updateTabsWithData:(NSData *)data;
- (void)selectTabWithIndex:(int)idx;
- (NSTabViewItem *)addNewTabViewItem;

- (void)createScrollbarWithIdentifier:(int32_t)ident type:(int)type;
- (BOOL)destroyScrollbarWithIdentifier:(int32_t)ident;
- (BOOL)showScrollbarWithIdentifier:(int32_t)ident state:(BOOL)visible;
- (void)setScrollbarThumbValue:(float)val proportion:(float)prop
                    identifier:(int32_t)ident;
- (void)setScrollbarPosition:(int)pos length:(int)len identifier:(int32_t)ident;

- (void)setDefaultColorsBackground:(NSColor *)back foreground:(NSColor *)fore;

- (void)viewWillStartLiveResize;
- (void)viewDidEndLiveResize;
- (void)setFrameSize:(NSSize)size;
- (void)setFrame:(NSRect)frame;
- (CGFloat)totalHorizontalInset;
- (CGFloat)totalVerticalInset;

@end
