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

- (void)vimController:(MMVimController *)controller showScrollbarWithIdentifier:(int32_t)identifier state:(BOOL)state data:(NSData *)data {
    [self.vimView showScrollbarWithIdentifier:identifier state:state];
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

- (void)vimController:(MMVimController *)controller showTabBarWithData:(NSData *)data {
    [self.vimView.tabBarControl setHidden:NO];
    // Here we should resize and -position the Vim view...
}

- (void)vimController:(MMVimController *)controller setScrollbarThumbValue:(float)value proportion:(float)proportion identifier:(int32_t)identifier data:(NSData *)data {
    // Here we should resize and -position the Vim view...
}

#pragma mark MMVimManagerDelegateProtocol
- (void)manager:(MMVimManager *)manager vimControllerCreated:(MMVimController *)controller {
    _vimController = controller;
    _vimController.delegate = self;
    _vimView = _vimController.vimView;
}

- (void)manager:(MMVimManager *)manager vimControllerRemovedWithControllerId:(unsigned int)identifier pid:(int)pid {
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
