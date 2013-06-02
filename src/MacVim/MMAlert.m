/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMAlert.h"


static int MMAlertTextFieldHeight = 22;


@interface MMAlert ()

@property(readonly) NSTextField *textField;

@end


#pragma mark ARC
@implementation MMAlert

- (void)setTextFieldString:(NSString *)textFieldString {
    _textField = nil;

    _textField = [[NSTextField alloc] init];
    [self.textField setStringValue:textFieldString];
}

- (void)setInformativeText:(NSString *)text {
    if (self.textField) {
        // HACK! Add some space for the text field.
        [super setInformativeText:[text stringByAppendingString:@"\n\n\n"]];
    } else {
        [super setInformativeText:text];
    }
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)didEndSelector contextInfo:(void *)contextInfo {
    [super beginSheetModalForWindow:window modalDelegate:delegate didEndSelector:didEndSelector contextInfo:contextInfo];

    // HACK! Place the input text field at the bottom of the informative text
    // (which has been made a bit larger by adding newline characters).
    NSView *contentView = [self.window contentView];
    NSRect rect = contentView.frame;
    rect.origin.y = rect.size.height;

    for (NSView *view in contentView.subviews) {
        if ([view isKindOfClass:[NSTextField class]] && view.frame.origin.y < rect.origin.y) {
            // NOTE: The informative text field is the lowest NSTextField in the alert dialog.
            rect = [view frame];
        }
    }

    rect.size.height = MMAlertTextFieldHeight;
    [self.textField setFrame:rect];

    [contentView addSubview:self.textField];
    [self.textField becomeFirstResponder];
}

@end