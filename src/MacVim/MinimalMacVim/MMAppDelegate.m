#import <MacVimFramework/MacVimFramework.h>
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "MMAppDelegate.h"
#import "MMUtil.h"


@interface MMAppDelegate ()

@property (readonly) MMVimManager *vimManager;
@property (readonly) MMVimController *vimController;
@property (readonly) MMVimView *vimView;

@end


@implementation MMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Necessary initialization calls for MacVimFramework {
    ASLInit();

    [MMUtils setKeyHandlingUserDefaults];
    [MMUtils setInitialUserDefaults];

    [[NSFileManager defaultManager] changeCurrentDirectoryPath:NSHomeDirectory()];
    // } Necessary initialization calls for MacVimFramework

    // Vim wants to track mouse movements
    [self.window setAcceptsMouseMovedEvents:YES];

    _vimManager = [MMVimManager sharedManager];
    _vimManager.delegate = self;
    [_vimManager setUp];

    // Create a new Vim controller. This creates a new Vim process in the background and calls
    // -manager:vimControllerCreated: of MMVimManagerDelegateProtocol
    [_vimManager openVimController:nil withArguments:nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (self.vimController != nil) {
        [self.vimController sendMessage:VimShouldCloseMsgID data:nil];
        [self.vimManager removeVimController:self.vimController];
    }

    [self.vimManager cleanUp];
    [self.vimManager terminateAllVimProcesses];

    return NSTerminateNow;
}

#pragma mark NSWindowDelegate
- (void)windowDidBecomeMain:(NSNotification *)notification {
    [self.vimController sendMessage:GotFocusMsgID data:nil];
}

- (void)windowDidResignMain:(NSNotification *)notification {
    [self.vimController sendMessage:LostFocusMsgID data:nil];
}

- (BOOL)windowShouldClose:(id)sender {
    // Don't close the window now; Instead let Vim decide whether to close the window or not.
    [self.vimController sendMessage:VimShouldCloseMsgID data:nil];
    return NO;
}

#pragma mark MMVimControllerDelegate
- (void)vimController:(MMVimController *)controller handleShowDialogWithButtonTitles:(NSArray *)buttonTitles style:(NSAlertStyle)style message:(NSString *)message text:(NSString *)text textFieldString:(NSString *)string data:(NSData *)data {
    // 3 = don't save
    // 1 = save
    [self.vimController tellBackend:@[@3]];
}

- (void)vimController:(MMVimController *)controller createScrollbarWithIdentifier:(int32_t)identifier type:(int)type data:(NSData *)data {
    [self.vimView createScrollbarWithIdentifier:identifier type:type];
}

- (void)vimController:(MMVimController *)controller addToolbarItemWithLabel:(NSString *)label tip:(NSString *)tip icon:(NSString *)icon atIndex:(int)idx {
    log4Debug(@"%@, %@, %@, %@", label, tip, icon, @(idx));
}

- (void)vimController:(MMVimController *)controller showScrollbarWithIdentifier:(int32_t)identifier state:(BOOL)state data:(NSData *)data {
    [self.vimView showScrollbarWithIdentifier:identifier state:state];
}

- (void)vimController:(MMVimController *)controller showToolbar:(BOOL)enable flags:(int)flags data:(NSData *)data {
    log4Debug(@"%@: %@", @(enable), @(flags));
}

- (void)vimController:(MMVimController *)controller setTextDimensionsWithRows:(int)rows columns:(int)columns isLive:(BOOL)live keepOnScreen:(BOOL)screen data:(NSData *)data {
    [self.vimView setDesiredRows:rows columns:columns];
}

- (void)vimController:(MMVimController *)controller openWindowWithData:(NSData *)data {
    self.vimView.frameSize = [self.window contentRectForFrameRect:self.window.frame].size;

    [self.window.contentView addSubview:self.vimView];
    [self.window setInitialFirstResponder:self.vimView.textView];

    [self.vimView addNewTabViewItem];
    [self.window makeKeyAndOrderFront:self];
}

- (void)vimController:(MMVimController *)controller setStateToolbarItemWithIdentifier:(NSString *)identifier state:(BOOL)state {
    log4Debug(@"%@: %@", identifier, @(state));
}

- (void)vimController:(MMVimController *)controller processFinishedForInputQueue:(NSArray *)inputQueue {
    // noop
    // this gets called very very often...
}

- (void)vimController:(MMVimController *)controller setScrollbarPosition:(int)position length:(int)length identifier:(int32_t)identifier data:(NSData *)data {
    [self.vimView setScrollbarPosition:position length:length identifier:identifier];
}

- (void)vimController:(MMVimController *)controller setPreEditRow:(int)row column:(int)column data:(NSData *)data {
    [self.vimView.textView setPreEditRow:row column:column];
}

- (void)vimController:(MMVimController *)controller setMouseShape:(int)shape data:(NSData *)data {
    self.vimView.textView.mouseShape = shape;
}

- (void)vimController:(MMVimController *)controller setBufferModified:(BOOL)modified data:(NSData *)data {
    log4Debug(@"%@", @(modified));
}

- (void)vimController:(MMVimController *)controller setWindowTitle:(NSString *)title data:(NSData *)data {
    log4Debug(@"%@", title);
}

- (void)vimController:(MMVimController *)controller setDocumentFilename:(NSString *)filename data:(NSData *)data {
    log4Debug(@"%@", filename);
}

- (void)vimController:(MMVimController *)controller showTabBarWithData:(NSData *)data {
    [self.vimView.tabBarControl setHidden:NO];
    // Here we should resize and -position the Vim view...
}

#pragma mark MMVimManagerDelegateProtocol
- (void)manager:(MMVimManager *)manager vimControllerCreated:(MMVimController *)controller {
    _vimController = controller;
    _vimController.delegate = self;
    _vimView = _vimController.vimView;
}

- (void)manager:(MMVimManager *)manager vimControllerRemovedWithIdentifier:(unsigned int)identifier {
    [self.vimView removeFromSuperviewWithoutNeedingDisplay];
    [self.vimView cleanup];

    [self.window orderOut:self];

    _vimView = nil;
    _vimController = nil;
}

- (NSMenuItem *)menuItemTemplateForManager:(MMVimManager *)manager {
    // Return a dummy menu item, otherwise it will not work.
    return [[NSMenuItem alloc] init];
}

@end
