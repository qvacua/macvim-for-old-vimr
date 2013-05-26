/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMCoreTextView.h"

/*
 * MMCoreTextView+ToolTip
 *
 * Cocoa's tool tip interface does not allow changing the tool tip without the
 * user moving the mouse outside the view and then back again.  This category
 * takes care of this problem.
 *
 * The tool tip code was borrowed from the Chromium project which in turn had
 * borrowed it from WebKit (copyright and comments are below).  Some minor
 * changes were made to adapt the code to MacVim.
 */
@interface MMCoreTextView (ToolTip)
- (void)setToolTipAtMousePoint:(NSString *)string;
@end