//
// Created by Tae Won Ha on 5/30/13.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "MMAlert.h"
#import "MMLog.h"


static int MMAlertTextFieldHeight = 22;


@implementation MMAlert

- (void)dealloc {
    ASLogDebug(@"");

    [textField release];
    textField = nil;
    [super dealloc];
}

- (void)setTextFieldString:(NSString *)textFieldString {
    [textField release];
    textField = [[NSTextField alloc] init];
    [textField setStringValue:textFieldString];
}

- (NSTextField *)textField {
    return textField;
}

- (void)setInformativeText:(NSString *)text {
    if (textField) {
        // HACK! Add some space for the text field.
        [super setInformativeText:[text stringByAppendingString:@"\n\n\n"]];
    } else {
        [super setInformativeText:text];
    }
}

- (void)beginSheetModalForWindow:(NSWindow *)window
                   modalDelegate:(id)delegate
                  didEndSelector:(SEL)didEndSelector
                     contextInfo:(void *)contextInfo {
    [super beginSheetModalForWindow:window
                      modalDelegate:delegate
                     didEndSelector:didEndSelector
                        contextInfo:contextInfo];

    // HACK! Place the input text field at the bottom of the informative text
    // (which has been made a bit larger by adding newline characters).
    NSView *contentView = [[self window] contentView];
    NSRect rect = [contentView frame];
    rect.origin.y = rect.size.height;

    NSArray *subviews = [contentView subviews];
    unsigned i, count = [subviews count];
    for (i = 0; i < count; ++i) {
        NSView *view = [subviews objectAtIndex:i];
        if ([view isKindOfClass:[NSTextField class]]
                && [view frame].origin.y < rect.origin.y) {
            // NOTE: The informative text field is the lowest NSTextField in
            // the alert dialog.
            rect = [view frame];
        }
    }

    rect.size.height = MMAlertTextFieldHeight;
    [textField setFrame:rect];
    [contentView addSubview:textField];
    [textField becomeFirstResponder];
}

@end