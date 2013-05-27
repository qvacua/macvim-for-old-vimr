/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */
/*
 * MMAppController
 *
 * MMAppController is the delegate of NSApp and as such handles file open
 * requests, application termination, etc.  It sets up a named NSConnection on
 * which it listens to incoming connections from Vim processes.  It also
 * coordinates all MMVimControllers and takes care of the main menu.
 *
 * A new Vim process is started by calling launchVimProcessWithArguments:.
 * When the Vim process is initialized it notifies the app controller by
 * sending a connectBackend:pid: message.  At this point a new MMVimController
 * is allocated.  Afterwards, the Vim process communicates directly with its
 * MMVimController.
 *
 * A Vim process started from the command line connects directly by sending the
 * connectBackend:pid: message (launchVimProcessWithArguments: is never called
 * in this case).
 *
 * The main menu is handled as follows.  Each Vim controller keeps its own main
 * menu.  All menus except the "MacVim" menu are controlled by the Vim process.
 * The app controller also keeps a reference to the "default main menu" which
 * is set up in MainMenu.nib.  When no editor window is open the default main
 * menu is used.  When a new editor window becomes main its main menu becomes
 * the new main menu, this is done in -[MMAppController setMainMenu:].
 *   NOTE: Certain heuristics are used to find the "MacVim", "Windows", "File",
 * and "Services" menu.  If MainMenu.nib changes these heuristics may have to
 * change as well.  For specifics see the find... methods defined in the NSMenu
 * category "MMExtras".
 */

#import "MMVimManager.h"

#import "MMAppController.h"
#import "MMPreferenceController.h"
#import "MMVimController.h"
#import "MMWindowController.h"
#import "Miscellaneous.h"
#import "MMUtils.h"


#define MM_HANDLE_XCODE_MOD_EVENT 0


static NSString *MMWebsiteString = @"http://code.google.com/p/macvim/";

static float MMCascadeHorizontalOffset = 21;
static float MMCascadeVerticalOffset = 23;


#pragma pack(push,1)
// The alignment and sizes of these fields are based on trial-and-error.  It
// may be necessary to adjust them to fit if Xcode ever changes this struct.
typedef struct
{
    int16_t unused1;      // 0 (not used)
    int16_t lineNum;      // line to select (< 0 to specify range)
    int32_t startRange;   // start of selection range (if line < 0)
    int32_t endRange;     // end of selection range (if line < 0)
    int32_t unused2;      // 0 (not used)
    int32_t theDate;      // modification date/time
} MMXcodeSelectionRange;
#pragma pack(pop)


@interface MMAppController (MMServices)
- (void)openSelection:(NSPasteboard *)pboard userData:(NSString *)userData
                error:(NSString **)error;
- (void)openFile:(NSPasteboard *)pboard userData:(NSString *)userData
           error:(NSString **)error;
- (void)newFileHere:(NSPasteboard *)pboard userData:(NSString *)userData
              error:(NSString **)error;
@end


@interface MMAppController (Private)
- (MMVimController *)topmostVimController;
- (NSArray *)filterFilesAndNotify:(NSArray *)files;
- (NSArray *)filterOpenFiles:(NSArray *)filenames
               openFilesDict:(NSDictionary **)openFiles;
#if MM_HANDLE_XCODE_MOD_EVENT
- (void)handleXcodeModEvent:(NSAppleEventDescriptor *)event
                 replyEvent:(NSAppleEventDescriptor *)reply;
#endif
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
               replyEvent:(NSAppleEventDescriptor *)reply;
- (NSMutableDictionary *)extractArgumentsFromOdocEvent:
    (NSAppleEventDescriptor *)desc;
- (MMVimController *)takeVimControllerFromCache;
- (BOOL)openVimControllerWithArguments:(NSDictionary *)arguments;
- (void)activateWhenNextWindowOpens;
- (NSScreen *)screenContainingTopLeftPoint:(NSPoint)pt;
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)
- (void)inputSourceChanged:(NSNotification *)notification;
#endif
@end


@implementation MMAppController

+ (void)initialize
{
    static BOOL initDone = NO;
    if (initDone) return;
    initDone = YES;

    ASLInit();

    [MMUtils setKeyHandlingUserDefaults];

    NSDictionary *dict = @{
            MMNoWindowKey                 : @NO,
            MMTabMinWidthKey              : @64,
            MMTabMaxWidthKey              : @(6 * 64),
            MMTabOptimumWidthKey          : @132,
            MMShowAddTabButtonKey         : @YES,
            MMTextInsetLeftKey            : @2,
            MMTextInsetRightKey           : @1,
            MMTextInsetTopKey             : @1,
            MMTextInsetBottomKey          : @1,
            MMTypesetterKey               : @"MMTypesetter",
            MMCellWidthMultiplierKey      : @1,
            MMBaselineOffsetKey           : @(-1),
            MMTranslateCtrlClickKey       : @YES,
            MMOpenInCurrentWindowKey      : @0,
            MMNoFontSubstitutionKey       : @NO,
            MMLoginShellKey               : @YES,
            MMRendererKey                 : @(MMRendererCoreText),
            MMUntitledWindowKey           : @(MMUntitledWindowAlways),
            MMTexturedWindowKey           : @NO,
            MMZoomBothKey                 : @NO,
            MMLoginShellCommandKey        : @"",
            MMLoginShellArgumentKey       : @"",
            MMDialogsTrackPwdKey          : @YES,
            MMOpenLayoutKey               : @3,
            MMVerticalSplitKey            : @NO,
            MMPreloadCacheSizeKey         : @0,
            MMLastWindowClosedBehaviorKey : @0,
            MMSuppressTerminationAlertKey : @NO,
            MMNativeFullScreenKey         : @YES,
#ifdef INCLUDE_OLD_IM_CODE
            MMUseInlineImKey              : @YES,
#endif // INCLUDE_OLD_IM_CODE
    };

    [[NSUserDefaults standardUserDefaults] registerDefaults:dict];

    NSArray *types = @[NSStringPboardType];
    [NSApp registerServicesMenuSendTypes:types returnTypes:types];

    // NOTE: Set the current directory to user's home directory, otherwise it
    // will default to the root directory.  (This matters since new Vim
    // processes inherit MacVim's environment variables.)
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:
            NSHomeDirectory()];
}

- (id)init
{
    if (!(self = [super init])) return nil;

#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7)
    // Disable automatic relaunching
    if ([NSApp respondsToSelector:@selector(disableRelaunchOnLogin)])
        [NSApp disableRelaunchOnLogin];
#endif

    vimManager = [MMVimManager sharedManager];

    return self;
}

- (void)dealloc
{
    ASLogDebug(@"");

    [openSelectionString release];  openSelectionString = nil;
    [recentFilesMenuItem release];  recentFilesMenuItem = nil;
    [defaultMainMenu release];  defaultMainMenu = nil;
    [appMenuItemTemplate release];  appMenuItemTemplate = nil;

    [super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Remember the default menu so that it can be restored if the user closes
    // all editor windows.
    defaultMainMenu = [[NSApp mainMenu] retain];

    // Store a copy of the default app menu so we can use this as a template
    // for all other menus.  We make a copy here because the "Services" menu
    // will not yet have been populated at this time.  If we don't we get
    // problems trying to set key equivalents later on because they might clash
    // with items on the "Services" menu.
    appMenuItemTemplate = [defaultMainMenu itemAtIndex:0];
    appMenuItemTemplate = [appMenuItemTemplate copy];

    // Set up the "Open Recent" menu. See
    //   http://lapcatsoftware.com/blog/2007/07/10/
    //     working-without-a-nib-part-5-open-recent-menu/
    // and
    //   http://www.cocoabuilder.com/archive/message/cocoa/2007/8/15/187793
    // for more information.
    //
    // The menu itself is created in MainMenu.nib but we still seem to have to
    // hack around a bit to get it to work.  (This has to be done in
    // applicationWillFinishLaunching at the latest, otherwise it doesn't
    // work.)
    NSMenu *fileMenu = [defaultMainMenu findFileMenu];
    if (fileMenu) {
        int idx = [fileMenu indexOfItemWithAction:@selector(fileOpen:)];
        if (idx >= 0 && idx+1 < [fileMenu numberOfItems])

        recentFilesMenuItem = [fileMenu itemWithTitle:@"Open Recent"];
        [[recentFilesMenuItem submenu] performSelector:@selector(_setMenuName:)
                                        withObject:@"NSRecentDocumentsMenu"];

        // Note: The "Recent Files" menu must be moved around since there is no
        // -[NSApp setRecentFilesMenu:] method.  We keep a reference to it to
        // facilitate this move (see setMainMenu: below).
        [recentFilesMenuItem retain];
    }

#if MM_HANDLE_XCODE_MOD_EVENT
    [[NSAppleEventManager sharedAppleEventManager]
            setEventHandler:self
                andSelector:@selector(handleXcodeModEvent:replyEvent:)
              forEventClass:'KAHL'
                 andEventID:'MOD '];
#endif

    // Register 'mvim://' URL handler
    [[NSAppleEventManager sharedAppleEventManager]
            setEventHandler:self
                andSelector:@selector(handleGetURLEvent:replyEvent:)
              forEventClass:kInternetEventClass
                 andEventID:kAEGetURL];

    [MMUtils setVimKeybindings];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [NSApp setServicesProvider:self];

    [vimManager setUp];

    ASLogInfo(@"MacVim finished launching");
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSAppleEventManager *aem = [NSAppleEventManager sharedAppleEventManager];
    NSAppleEventDescriptor *desc = [aem currentAppleEvent];

    // The user default MMUntitledWindow can be set to control whether an
    // untitled window should open on 'Open' and 'Reopen' events.
    int untitledWindowFlag = [ud integerForKey:MMUntitledWindowKey];

    BOOL isAppOpenEvent = [desc eventID] == kAEOpenApplication;
    if (isAppOpenEvent && (untitledWindowFlag & MMUntitledWindowOnOpen) == 0)
        return NO;

    BOOL isAppReopenEvent = [desc eventID] == kAEReopenApplication;
    if (isAppReopenEvent
            && (untitledWindowFlag & MMUntitledWindowOnReopen) == 0)
        return NO;

    // When a process is started from the command line, the 'Open' event may
    // contain a parameter to surpress the opening of an untitled window.
    desc = [desc paramDescriptorForKeyword:keyAEPropData];
    desc = [desc paramDescriptorForKeyword:keyMMUntitledWindow];
    if (desc && ![desc booleanValue])
        return NO;

    // Never open an untitled window if there is at least one open window.
    if (vimManager.countOfVimControllers > 0)
        return NO;

    if ([vimManager processesAboutToLaunch]) {
        return NO;
    }

    // NOTE!  This way it possible to start the app with the command-line
    // argument '-nowindow yes' and no window will be opened by default but
    // this argument will only be heeded when the application is opening.
    if (isAppOpenEvent && [ud boolForKey:MMNoWindowKey] == YES)
        return NO;

    return YES;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender
{
    ASLogDebug(@"Opening untitled window...");
    [self newWindow:self];
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    ASLogInfo(@"Opening files %@", filenames);

    // Extract ODB/Xcode/Spotlight parameters from the current Apple event,
    // sort the filenames, and then let openFiles:withArguments: do the heavy
    // lifting.

    if (!(filenames && [filenames count] > 0))
        return;

    // Sort filenames since the Finder doesn't take care in preserving the
    // order in which files are selected anyway (and "sorted" is more
    // predictable than "random").
    if ([filenames count] > 1)
        filenames = [filenames sortedArrayUsingSelector:
                @selector(localizedCompare:)];

    // Extract ODB/Xcode/Spotlight parameters from the current Apple event
    NSMutableDictionary *arguments = [self extractArgumentsFromOdocEvent:
            [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent]];

    if ([self openFiles:filenames withArguments:arguments]) {
        [NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
    } else {
        // TODO: Notify user of failure?
        [NSApp replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return (MMTerminateWhenLastWindowClosed ==
            [[NSUserDefaults standardUserDefaults]
                integerForKey:MMLastWindowClosedBehaviorKey]);
}

- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication *)sender
{
    // TODO: Follow Apple's guidelines for 'Graceful Application Termination'
    // (in particular, allow user to review changes and save).
    int reply = NSTerminateNow;
    BOOL modifiedBuffers = NO;

    // Go through Vim controllers, checking for modified buffers.
    NSEnumerator *e = [vimManager enumeratorOfVimControllers];
    id vc;
    while ((vc = [e nextObject])) {
        if ([vc hasModifiedBuffer]) {
            modifiedBuffers = YES;
            break;
        }
    }

    if (modifiedBuffers) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert addButtonWithTitle:NSLocalizedString(@"Quit",
                @"Dialog button")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel",
                @"Dialog button")];
        [alert setMessageText:NSLocalizedString(@"Quit without saving?",
                @"Quit dialog with changed buffers, title")];
        [alert setInformativeText:NSLocalizedString(
                @"There are modified buffers, "
                "if you quit now all changes will be lost.  Quit anyway?",
                @"Quit dialog with changed buffers, text")];

        if ([alert runModal] != NSAlertFirstButtonReturn)
            reply = NSTerminateCancel;

        [alert release];
    } else if (![[NSUserDefaults standardUserDefaults]
                                boolForKey:MMSuppressTerminationAlertKey]) {
        // No unmodified buffers, but give a warning if there are multiple
        // windows and/or tabs open.
        int numWindows = [vimManager countOfVimControllers];
        int numTabs = 0;

        // Count the number of open tabs
        e = [vimManager enumeratorOfVimControllers];
        while ((vc = [e nextObject]))
            numTabs += [[vc objectForVimStateKey:@"numTabs"] intValue];

        if (numWindows > 1 || numTabs > 1) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert addButtonWithTitle:NSLocalizedString(@"Quit",
                    @"Dialog button")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel",
                    @"Dialog button")];
            [alert setMessageText:NSLocalizedString(
                    @"Are you sure you want to quit MacVim?",
                    @"Quit dialog with no changed buffers, title")];
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)
            [alert setShowsSuppressionButton:YES];
#endif

            NSString *info = nil;
            if (numWindows > 1) {
                if (numTabs > numWindows)
                    info = [NSString stringWithFormat:NSLocalizedString(
                            @"There are %d windows open in MacVim, with a "
                            "total of %d tabs. Do you want to quit anyway?",
                            @"Quit dialog with no changed buffers, text"),
                         numWindows, numTabs];
                else
                    info = [NSString stringWithFormat:NSLocalizedString(
                            @"There are %d windows open in MacVim. "
                            "Do you want to quit anyway?",
                            @"Quit dialog with no changed buffers, text"),
                        numWindows];

            } else {
                info = [NSString stringWithFormat:NSLocalizedString(
                        @"There are %d tabs open in MacVim. "
                        "Do you want to quit anyway?",
                        @"Quit dialog with no changed buffers, text"), 
                     numTabs];
            }

            [alert setInformativeText:info];

            if ([alert runModal] != NSAlertFirstButtonReturn)
                reply = NSTerminateCancel;

#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5)
            if ([[alert suppressionButton] state] == NSOnState) {
                [[NSUserDefaults standardUserDefaults]
                            setBool:YES forKey:MMSuppressTerminationAlertKey];
            }
#endif

            [alert release];
        }
    }


    // Tell all Vim processes to terminate now (otherwise they'll leave swap
    // files behind).
    if (NSTerminateNow == reply) {
        [vimManager terminateAllVimProcesses];
    }

    return (NSApplicationTerminateReply) reply;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    ASLogInfo(@"Terminating MacVim...");

#if MM_HANDLE_XCODE_MOD_EVENT
    [[NSAppleEventManager sharedAppleEventManager]
            removeEventHandlerForEventClass:'KAHL'
                                 andEventID:'MOD '];
#endif

    [vimManager cleanUp];
    [NSApp setDelegate:nil];
}

+ (MMAppController *)sharedInstance
{
    // Note: The app controller is a singleton which is instantiated in
    // MainMenu.nib where it is also connected as the delegate of NSApp.
    id delegate = [NSApp delegate];
    return [delegate isKindOfClass:self] ? (MMAppController*)delegate : nil;
}

- (NSMenu *)defaultMainMenu
{
    return defaultMainMenu;
}

- (NSMenuItem *)appMenuItemTemplate
{
    return appMenuItemTemplate;
}

- (void)removeVimController:(id)controller
{
    [vimManager removeVimController:controller];

    if (![vimManager countOfVimControllers]) {
        // The last editor window just closed so restore the main menu back to
        // its default state (which is defined in MainMenu.nib).
        [self setMainMenu:defaultMainMenu];

        BOOL hide = (MMHideWhenLastWindowClosed ==
                    [[NSUserDefaults standardUserDefaults]
                        integerForKey:MMLastWindowClosedBehaviorKey]);
        if (hide)
            [NSApp hide:self];
    }
}

- (void)windowControllerWillOpen:(MMWindowController *)windowController
{
    NSPoint topLeft = NSZeroPoint;
    NSWindow *cascadeFrom = [[[self topmostVimController] windowController]
                                                                    window];
    NSWindow *win = [windowController window];

    if (!win) return;

    // Heuristic to determine where to position the window:
    //   1. Use the default top left position (set using :winpos in .[g]vimrc)
    //   2. Cascade from an existing window
    //   3. Use autosaved position
    // If all of the above fail, then the window position is not changed.
    if ([windowController getDefaultTopLeft:&topLeft]) {
        // Make sure the window is not cascaded (note that topLeft was set in
        // the above call).
        cascadeFrom = nil;
    } else if (cascadeFrom) {
        NSRect frame = [cascadeFrom frame];
        topLeft = NSMakePoint(frame.origin.x, NSMaxY(frame));
    } else {
        NSString *topLeftString = [[NSUserDefaults standardUserDefaults]
            stringForKey:MMTopLeftPointKey];
        if (topLeftString)
            topLeft = NSPointFromString(topLeftString);
    }

    if (!NSEqualPoints(topLeft, NSZeroPoint)) {
        // Try to tile from the correct screen in case the user has multiple
        // monitors ([win screen] always seems to return the "main" screen).
        //
        // TODO: Check for screen _closest_ to top left?
        NSScreen *screen = [self screenContainingTopLeftPoint:topLeft];
        if (!screen)
            screen = [win screen];

        if (cascadeFrom) {
            // Do manual cascading instead of using
            // -[MMWindow cascadeTopLeftFromPoint:] since it is rather
            // unpredictable.
            topLeft.x += MMCascadeHorizontalOffset;
            topLeft.y -= MMCascadeVerticalOffset;
        }

        if (screen) {
            // Constrain the window so that it is entirely visible on the
            // screen.  If it sticks out on the right, move it all the way
            // left.  If it sticks out on the bottom, move it all the way up.
            // (Assumption: the cascading offsets are positive.)
            NSRect screenFrame = [screen frame];
            NSSize winSize = [win frame].size;
            NSRect winFrame =
                { { topLeft.x, topLeft.y - winSize.height }, winSize };

            if (NSMaxX(winFrame) > NSMaxX(screenFrame))
                topLeft.x = NSMinX(screenFrame);
            if (NSMinY(winFrame) < NSMinY(screenFrame))
                topLeft.y = NSMaxY(screenFrame);
        } else {
            ASLogNotice(@"Window not on screen, don't constrain position");
        }

        [win setFrameTopLeftPoint:topLeft];
    }

    if (1 == [vimManager countOfVimControllers]) {
        // The first window autosaves its position.  (The autosaving
        // features of Cocoa are not used because we need more control over
        // what is autosaved and when it is restored.)
        [windowController setWindowAutosaveKey:MMTopLeftPointKey];
    }

    if (openSelectionString) {
        // TODO: Pass this as a parameter instead!  Get rid of
        // 'openSelectionString' etc.
        //
        // There is some text to paste into this window as a result of the
        // services menu "Open selection ..." being used.
        [[windowController vimController] dropString:openSelectionString];
        [openSelectionString release];
        openSelectionString = nil;
    }

    if ([vimManager readAndResetLastVimControllerHasArgs] || shouldActivateWhenNextWindowOpens) {
        [NSApp activateIgnoringOtherApps:YES];
        shouldActivateWhenNextWindowOpens = NO;
    }
}

- (void)setMainMenu:(NSMenu *)mainMenu
{
    if ([NSApp mainMenu] == mainMenu) return;

    // If the new menu has a "Recent Files" dummy item, then swap the real item
    // for the dummy.  We are forced to do this since Cocoa initializes the
    // "Recent Files" menu and there is no way to simply point Cocoa to a new
    // item each time the menus are swapped.
    NSMenu *fileMenu = [mainMenu findFileMenu];
    if (recentFilesMenuItem && fileMenu) {
        int dummyIdx =
                [fileMenu indexOfItemWithAction:@selector(recentFilesDummy:)];
        if (dummyIdx >= 0) {
            NSMenuItem *dummyItem = [[fileMenu itemAtIndex:dummyIdx] retain];
            [fileMenu removeItemAtIndex:dummyIdx];

            NSMenu *recentFilesParentMenu = [recentFilesMenuItem menu];
            int idx = [recentFilesParentMenu indexOfItem:recentFilesMenuItem];
            if (idx >= 0) {
                [[recentFilesMenuItem retain] autorelease];
                [recentFilesParentMenu removeItemAtIndex:idx];
                [recentFilesParentMenu insertItem:dummyItem atIndex:idx];
            }

            [fileMenu insertItem:recentFilesMenuItem atIndex:dummyIdx];
            [dummyItem release];
        }
    }

    // Now set the new menu.  Notice that we keep one menu for each editor
    // window since each editor can have its own set of menus.  When swapping
    // menus we have to tell Cocoa where the new "MacVim", "Windows", and
    // "Services" menu are.
    [NSApp setMainMenu:mainMenu];

    // Setting the "MacVim" (or "Application") menu ensures that it is typeset
    // in boldface.  (The setAppleMenu: method used to be public but is now
    // private so this will have to be considered a bit of a hack!)
    NSMenu *appMenu = [mainMenu findApplicationMenu];
    [NSApp performSelector:@selector(setAppleMenu:) withObject:appMenu];

    NSMenu *servicesMenu = [mainMenu findServicesMenu];
    [NSApp setServicesMenu:servicesMenu];

    NSMenu *windowsMenu = [mainMenu findWindowsMenu];
    if (windowsMenu) {
        // Cocoa isn't clever enough to get rid of items it has added to the
        // "Windows" menu so we have to do it ourselves otherwise there will be
        // multiple menu items for each window in the "Windows" menu.
        //   This code assumes that the only items Cocoa add are ones which
        // send off the action makeKeyAndOrderFront:.  (Cocoa will not add
        // another separator item if the last item on the "Windows" menu
        // already is a separator, so we needen't worry about separators.)
        int i, count = [windowsMenu numberOfItems];
        for (i = count-1; i >= 0; --i) {
            NSMenuItem *item = [windowsMenu itemAtIndex:i];
            if ([item action] == @selector(makeKeyAndOrderFront:))
                [windowsMenu removeItem:item];
        }
    }
    [NSApp setWindowsMenu:windowsMenu];
}

- (NSArray *)filterOpenFiles:(NSArray *)filenames
{
    return [self filterOpenFiles:filenames openFilesDict:nil];
}

- (BOOL)openFiles:(NSArray *)filenames withArguments:(NSDictionary *)args
{
    // Opening files works like this:
    //  a) filter out any already open files
    //  b) open any remaining files
    //
    // Each launching Vim process has a dictionary of arguments that are passed
    // to the process when in checks in (via connectBackend:pid:).  The
    // arguments for each launching process can be looked up by its PID (in the
    // pidArguments dictionary).

    NSMutableDictionary *arguments = (args ? [[args mutableCopy] autorelease]
                                           : [NSMutableDictionary dictionary]);

    filenames = normalizeFilenames(filenames);

    //
    // a) Filter out any already open files
    //
    NSString *firstFile = [filenames objectAtIndex:0];
    NSDictionary *openFilesDict = nil;
    filenames = [self filterOpenFiles:filenames openFilesDict:&openFilesDict];

    // The meaning of "layout" is defined by the WIN_* defines in main.c.
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    int layout = [ud integerForKey:MMOpenLayoutKey];
    BOOL splitVert = [ud boolForKey:MMVerticalSplitKey];
    BOOL openInCurrentWindow = [ud boolForKey:MMOpenInCurrentWindowKey];

    if (splitVert && MMLayoutHorizontalSplit == layout)
        layout = MMLayoutVerticalSplit;
    if (layout < 0 || (layout > MMLayoutTabs && openInCurrentWindow))
        layout = MMLayoutTabs;

    // Pass arguments to vim controllers that had files open.
    id key;
    NSEnumerator *e = [openFilesDict keyEnumerator];

    // (Indicate that we do not wish to open any files at the moment.)
    [arguments setObject:[NSNumber numberWithBool:YES] forKey:@"dontOpen"];

    while ((key = [e nextObject])) {
        MMVimController *vc = [key pointerValue];
        NSArray *files = [openFilesDict objectForKey:key];
        [arguments setObject:files forKey:@"filenames"];

        if ([filenames count] == 0 && [files containsObject:firstFile]) {
            // Raise the window containing the first file that was already
            // open, and make sure that the tab containing that file is
            // selected.  Only do this when there are no more files to open,
            // otherwise sometimes the window with 'firstFile' will be raised,
            // other times it might be the window that will open with the files
            // in the 'filenames' array.
            //
            // NOTE: Raise window before passing arguments, otherwise the
            // selection will be lost when selectionRange is set.
            firstFile = [firstFile stringByEscapingSpecialFilenameCharacters];

            NSString *bufCmd = @"tab sb";
            switch (layout) {
                case MMLayoutHorizontalSplit: bufCmd = @"sb"; break;
                case MMLayoutVerticalSplit:   bufCmd = @"vert sb"; break;
                case MMLayoutArglist:         bufCmd = @"b"; break;
            }

            NSString *input = [NSString stringWithFormat:@"<C-\\><C-N>"
                    ":let oldswb=&swb|let &swb=\"useopen,usetab\"|"
                    "%@ %@|let &swb=oldswb|unl oldswb|"
                    "cal foreground()<CR>", bufCmd, firstFile];

            [vc addVimInput:input];
        }

        [vc passArguments:arguments];
    }

    // Add filenames to "Recent Files" menu, unless they are being edited
    // remotely (using ODB).
    if ([arguments objectForKey:@"remoteID"] == nil) {
        [[NSDocumentController sharedDocumentController]
                noteNewRecentFilePaths:filenames];
    }

    if ([filenames count] == 0)
        return YES; // No files left to open (all were already open)

    //
    // b) Open any remaining files
    //

    [arguments setObject:[NSNumber numberWithInt:layout] forKey:@"layout"];
    [arguments setObject:filenames forKey:@"filenames"];
    // (Indicate that files should be opened from now on.)
    [arguments setObject:[NSNumber numberWithBool:NO] forKey:@"dontOpen"];

    MMVimController *vc;
    if (openInCurrentWindow && (vc = [self topmostVimController])) {
        // Open files in an already open window.
        [[[vc windowController] window] makeKeyAndOrderFront:self];
        [vc passArguments:arguments];
        return YES;
    }

    BOOL openOk = YES;
    int numFiles = [filenames count];
    if (MMLayoutWindows == layout && numFiles > 1) {
        // Open one file at a time in a new window, but don't open too many at
        // once (at most cap+1 windows will open).  If the user has increased
        // the preload cache size we'll take that as a hint that more windows
        // should be able to open at once.
        int cap = [vimManager maxPreloadCacheSize] - 1;
        if (cap < 4) cap = 4;
        if (cap > numFiles) cap = numFiles;

        int i;
        for (i = 0; i < cap; ++i) {
            NSArray *a = [NSArray arrayWithObject:[filenames objectAtIndex:i]];
            [arguments setObject:a forKey:@"filenames"];

            // NOTE: We have to copy the args since we'll mutate them in the
            // next loop and the below call may retain the arguments while
            // waiting for a process to start.
            NSDictionary *args = [[arguments copy] autorelease];

            openOk = [self openVimControllerWithArguments:args];
            if (!openOk) break;
        }

        // Open remaining files in tabs in a new window.
        if (openOk && numFiles > cap) {
            NSRange range = { i, numFiles-cap };
            NSArray *a = [filenames subarrayWithRange:range];
            [arguments setObject:a forKey:@"filenames"];
            [arguments setObject:[NSNumber numberWithInt:MMLayoutTabs]
                          forKey:@"layout"];

            openOk = [self openVimControllerWithArguments:arguments];
        }
    } else {
        // Open all files at once.
        openOk = [self openVimControllerWithArguments:arguments];
    }

    return openOk;
}

- (IBAction)newWindow:(id)sender
{
    ASLogDebug(@"Open new window");

    // A cached controller requires no loading times and results in the new
    // window popping up instantaneously.  If the cache is empty it may take
    // 1-2 seconds to start a new Vim process.
    MMVimController *vc = [self takeVimControllerFromCache];
    if (vc) {
        [[vc backendProxy] acknowledgeConnection];
    } else {
        [vimManager launchVimProcessWithArguments:nil workingDirectory:nil];
    }
}

- (IBAction)newWindowAndActivate:(id)sender
{
    [self activateWhenNextWindowOpens];
    [self newWindow:sender];
}

- (IBAction)fileOpen:(id)sender
{
    ASLogDebug(@"Show file open panel");

    NSString *dir = nil;
    BOOL trackPwd = [[NSUserDefaults standardUserDefaults]
            boolForKey:MMDialogsTrackPwdKey];
    if (trackPwd) {
        MMVimController *vc = [self keyVimController];
        if (vc) dir = [vc objectForVimStateKey:@"pwd"];
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:YES];
    [panel setAccessoryView:showHiddenFilesView()];
#if (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6)
    // NOTE: -[NSOpenPanel runModalForDirectory:file:types:] is deprecated on
    // 10.7 but -[NSOpenPanel setDirectoryURL:] requires 10.6 so jump through
    // the following hoops on 10.6+.
    dir = [dir stringByExpandingTildeInPath];
    if (dir) {
        NSURL *dirURL = [NSURL fileURLWithPath:dir isDirectory:YES];
        if (dirURL)
            [panel setDirectoryURL:dirURL];
    }

    NSInteger result = [panel runModal];
#else
    NSInteger result = [panel runModalForDirectory:dir file:nil types:nil];
#endif
    if (NSOKButton == result) {
        // NOTE: -[NSOpenPanel filenames] is deprecated on 10.7 so use
        // -[NSOpenPanel URLs] instead.  The downside is that we have to check
        // that each URL is really a path first.
        NSMutableArray *filenames = [NSMutableArray array];
        NSArray *urls = [panel URLs];
        NSUInteger i, count = [urls count];
        for (i = 0; i < count; ++i) {
            NSURL *url = [urls objectAtIndex:i];
            if ([url isFileURL]) {
                NSString *path = [url path];
                if (path)
                    [filenames addObject:path];
            }
        }

        if ([filenames count] > 0)
            [self application:NSApp openFiles:filenames];
    }
}

- (IBAction)selectNextWindow:(id)sender
{
    ASLogDebug(@"Select next window");

    unsigned i, count = [vimManager countOfVimControllers];
    if (!count) return;

    NSWindow *keyWindow = [NSApp keyWindow];
    for (i = 0; i < count; ++i) {
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
        if ([[[vc windowController] window] isEqual:keyWindow])
            break;
    }

    if (i < count) {
        if (++i >= count)
            i = 0;
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
        [[vc windowController] showWindow:self];
    }
}

- (IBAction)selectPreviousWindow:(id)sender
{
    ASLogDebug(@"Select previous window");

    unsigned i, count = [vimManager countOfVimControllers];
    if (!count) return;

    NSWindow *keyWindow = [NSApp keyWindow];
    for (i = 0; i < count; ++i) {
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
        if ([[[vc windowController] window] isEqual:keyWindow])
            break;
    }

    if (i < count) {
        if (i > 0) {
            --i;
        } else {
            i = count - 1;
        }
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
        [[vc windowController] showWindow:self];
    }
}

- (IBAction)orderFrontPreferencePanel:(id)sender
{
    ASLogDebug(@"Show preferences panel");
    [[MMPreferenceController sharedPrefsWindowController] showWindow:self];
}

- (IBAction)openWebsite:(id)sender
{
    ASLogDebug(@"Open MacVim website");
    [[NSWorkspace sharedWorkspace] openURL:
            [NSURL URLWithString:MMWebsiteString]];
}

- (IBAction)showVimHelp:(id)sender
{
    ASLogDebug(@"Open window with Vim help");
    // Open a new window with the help window maximized.
    [vimManager launchVimProcessWithArguments:[NSArray arrayWithObjects:
                                    @"-c", @":h gui_mac", @"-c", @":res", nil]
                       workingDirectory:nil];
}

- (IBAction)zoomAll:(id)sender
{
    ASLogDebug(@"Zoom all windows");
    [NSApp makeWindowsPerform:@selector(performZoom:) inOrder:YES];
}

- (IBAction)atsuiButtonClicked:(id)sender
{
    ASLogDebug(@"Toggle ATSUI renderer");
    NSInteger renderer = MMRendererDefault;
    BOOL enable = ([sender state] == NSOnState);

    if (enable) {
        renderer = MMRendererCoreText;
    }

    // Update the user default MMRenderer and synchronize the change so that
    // any new Vim process will pick up on the changed setting.
    CFPreferencesSetAppValue(
            (CFStringRef)MMRendererKey,
            (CFPropertyListRef)[NSNumber numberWithInt:renderer],
            kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);

    ASLogInfo(@"Use renderer=%ld", renderer);

    // This action is called when the user clicks the "use ATSUI renderer"
    // button in the advanced preferences pane.
    [vimManager rebuildPreloadCache];
}

- (IBAction)loginShellButtonClicked:(id)sender
{
    ASLogDebug(@"Toggle login shell option");
    // This action is called when the user clicks the "use login shell" button
    // in the advanced preferences pane.
    [vimManager rebuildPreloadCache];
}

- (IBAction)quickstartButtonClicked:(id)sender
{
    ASLogDebug(@"Toggle Quickstart option");
    [vimManager toggleQuickStart];
}

- (MMVimController *)keyVimController
{
    NSWindow *keyWindow = [NSApp keyWindow];
    if (keyWindow) {
        unsigned i, count = [vimManager countOfVimControllers];
        for (i = 0; i < count; ++i) {
            MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
            if ([[[vc windowController] window] isEqual:keyWindow])
                return vc;
        }
    }

    return nil;
}

@end // MMAppController




@implementation MMAppController (MMServices)

- (void)openSelection:(NSPasteboard *)pboard userData:(NSString *)userData
                error:(NSString **)error
{
    if (![[pboard types] containsObject:NSStringPboardType]) {
        ASLogNotice(@"Pasteboard contains no NSStringPboardType");
        return;
    }

    ASLogInfo(@"Open new window containing current selection");

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL openInCurrentWindow = [ud boolForKey:MMOpenInCurrentWindowKey];
    MMVimController *vc;

    if (openInCurrentWindow && (vc = [self topmostVimController])) {
        [vc sendMessage:AddNewTabMsgID data:nil];
        [vc dropString:[pboard stringForType:NSStringPboardType]];
    } else {
        // Save the text, open a new window, and paste the text when the next
        // window opens.  (If this is called several times in a row, then all
        // but the last call may be ignored.)
        if (openSelectionString) [openSelectionString release];
        openSelectionString = [[pboard stringForType:NSStringPboardType] copy];

        [self newWindow:self];
    }
}

- (void)openFile:(NSPasteboard *)pboard userData:(NSString *)userData
           error:(NSString **)error
{
    if (![[pboard types] containsObject:NSStringPboardType]) {
        ASLogNotice(@"Pasteboard contains no NSStringPboardType");
        return;
    }

    // TODO: Parse multiple filenames and create array with names.
    NSString *string = [pboard stringForType:NSStringPboardType];
    string = [string stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    string = [string stringByStandardizingPath];

    ASLogInfo(@"Open new window with selected file: %@", string);

    NSArray *filenames = [self filterFilesAndNotify:
            [NSArray arrayWithObject:string]];
    if ([filenames count] == 0)
        return;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL openInCurrentWindow = [ud boolForKey:MMOpenInCurrentWindowKey];
    MMVimController *vc;

    if (openInCurrentWindow && (vc = [self topmostVimController])) {
        [vc dropFiles:filenames forceOpen:YES];
    } else {
        [self openFiles:filenames withArguments:nil];
    }
}

- (void)newFileHere:(NSPasteboard *)pboard userData:(NSString *)userData
              error:(NSString **)error
{
    if (![[pboard types] containsObject:NSFilenamesPboardType]) {
        ASLogNotice(@"Pasteboard contains no NSFilenamesPboardType");
        return;
    }

    NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *path = [filenames lastObject];

    BOOL dirIndicator;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path
                                              isDirectory:&dirIndicator]) {
        ASLogNotice(@"Invalid path. Cannot open new document at: %@", path);
        return;
    }

    ASLogInfo(@"Open new file at path=%@", path);

    if (!dirIndicator)
        path = [path stringByDeletingLastPathComponent];

    path = [path stringByEscapingSpecialFilenameCharacters];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL openInCurrentWindow = [ud boolForKey:MMOpenInCurrentWindowKey];
    MMVimController *vc;

    if (openInCurrentWindow && (vc = [self topmostVimController])) {
        NSString *input = [NSString stringWithFormat:@"<C-\\><C-N>"
                ":tabe|cd %@<CR>", path];
        [vc addVimInput:input];
    } else {
        [vimManager launchVimProcessWithArguments:nil workingDirectory:path];
    }
}

@end // MMAppController (MMServices)




@implementation MMAppController (Private)

- (MMVimController *)topmostVimController
{
    // Find the topmost visible window which has an associated vim controller
    // as follows:
    //
    // 1. Search through ordered windows as determined by NSApp.  Unfortunately
    //    this method can fail, e.g. if a full-screen window is on another
    //    "Space" (in this case NSApp returns no windows at all), so we have to
    //    fall back on ...
    // 2. Search through all Vim controllers and return the first visible
    //    window.

    NSEnumerator *e = [[NSApp orderedWindows] objectEnumerator];
    id window;
    while ((window = [e nextObject]) && [window isVisible]) {
        unsigned i, count = [vimManager countOfVimControllers];
        for (i = 0; i < count; ++i) {
            MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
            if ([[[vc windowController] window] isEqual:window])
                return vc;
        }
    }

    unsigned i, count = [vimManager countOfVimControllers];
    for (i = 0; i < count; ++i) {
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];
        if ([[[vc windowController] window] isVisible]) {
            return vc;
        }
    }

    return nil;
}

- (NSArray *)filterFilesAndNotify:(NSArray *)filenames
{
    // Go trough 'filenames' array and make sure each file exists.  Present
    // warning dialog if some file was missing.

    NSString *firstMissingFile = nil;
    NSMutableArray *files = [NSMutableArray array];
    unsigned i, count = [filenames count];

    for (i = 0; i < count; ++i) {
        NSString *name = [filenames objectAtIndex:i];
        if ([[NSFileManager defaultManager] fileExistsAtPath:name]) {
            [files addObject:name];
        } else if (!firstMissingFile) {
            firstMissingFile = name;
        }
    }

    if (firstMissingFile) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"OK",
                @"Dialog button")];

        NSString *text;
        if ([files count] >= count-1) {
            [alert setMessageText:NSLocalizedString(@"File not found",
                    @"File not found dialog, title")];
            text = [NSString stringWithFormat:NSLocalizedString(
                    @"Could not open file with name %@.",
                    @"File not found dialog, text"), firstMissingFile];
        } else {
            [alert setMessageText:NSLocalizedString(@"Multiple files not found",
                    @"File not found dialog, title")];
            text = [NSString stringWithFormat:NSLocalizedString(
                    @"Could not open file with name %@, and %d other files.",
                    @"File not found dialog, text"),
                firstMissingFile, count-[files count]-1];
        }

        [alert setInformativeText:text];
        [alert setAlertStyle:NSWarningAlertStyle];

        [alert runModal];
        [alert release];

        [NSApp replyToOpenOrPrint:NSApplicationDelegateReplyFailure];
    }

    return files;
}

- (NSArray *)filterOpenFiles:(NSArray *)filenames
               openFilesDict:(NSDictionary **)openFiles
{
    // Filter out any files in the 'filenames' array that are open and return
    // all files that are not already open.  On return, the 'openFiles'
    // parameter (if non-nil) will point to a dictionary of open files, indexed
    // by Vim controller.

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableArray *files = [filenames mutableCopy];

    // TODO: Escape special characters in 'files'?
    NSString *expr = [NSString stringWithFormat:
            @"map([\"%@\"],\"bufloaded(v:val)\")",
            [files componentsJoinedByString:@"\",\""]];

    unsigned i, count = [vimManager countOfVimControllers];
    for (i = 0; i < count && [files count] > 0; ++i) {
        MMVimController *vc = [vimManager objectInVimControllersAtIndex:i];

        // Query Vim for which files in the 'files' array are open.
        NSString *eval = [vc evaluateVimExpression:expr];
        if (!eval) continue;

        NSIndexSet *idxSet = [NSIndexSet indexSetWithVimList:eval];
        if ([idxSet count] > 0) {
            [dict setObject:[files objectsAtIndexes:idxSet]
                     forKey:[NSValue valueWithPointer:vc]];

            // Remove all the files that were open in this Vim process and
            // create a new expression to evaluate.
            [files removeObjectsAtIndexes:idxSet];
            expr = [NSString stringWithFormat:
                    @"map([\"%@\"],\"bufloaded(v:val)\")",
                    [files componentsJoinedByString:@"\",\""]];
        }
    }

    if (openFiles != nil)
        *openFiles = dict;

    return [files autorelease];
}

#if MM_HANDLE_XCODE_MOD_EVENT
- (void)handleXcodeModEvent:(NSAppleEventDescriptor *)event
                 replyEvent:(NSAppleEventDescriptor *)reply
{
#if 0
    // Xcode sends this event to query MacVim which open files have been
    // modified.
    ASLogDebug(@"reply:%@", reply);
    ASLogDebug(@"event:%@", event);

    NSEnumerator *e = [vimControllers objectEnumerator];
    id vc;
    while ((vc = [e nextObject])) {
        DescType type = [reply descriptorType];
        unsigned len = [[type data] length];
        NSMutableData *data = [NSMutableData data];

        [data appendBytes:&type length:sizeof(DescType)];
        [data appendBytes:&len length:sizeof(unsigned)];
        [data appendBytes:[reply data] length:len];

        [vc sendMessage:XcodeModMsgID data:data];
    }
#endif
}
#endif

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
               replyEvent:(NSAppleEventDescriptor *)reply
{
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject]
        stringValue];
    // NOTE: URLWithString requires string to be percent escaped.
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:
                                                        NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:urlString];

    // We try to be compatible with TextMate's URL scheme here, as documented
    // at http://blog.macromates.com/2007/the-textmate-url-scheme/ . Currently,
    // this means that:
    //
    // The format is: mvim://open?<arguments> where arguments can be:
    //
    // * url — the actual file to open (i.e. a file://… URL), if you leave
    //         out this argument, the frontmost document is implied.
    // * line — line number to go to (one based).
    // * column — column number to go to (one based).
    //
    // Example: mvim://open?url=file:///etc/profile&line=20

    if ([[url host] isEqualToString:@"open"]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        // Parse query ("url=file://...&line=14") into a dictionary
        NSArray *queries = [[url query] componentsSeparatedByString:@"&"];
        NSEnumerator *enumerator = [queries objectEnumerator];
        NSString *param;
        while ((param = [enumerator nextObject])) {
            NSArray *arr = [param componentsSeparatedByString:@"="];
            if ([arr count] == 2) {
                [dict setValue:[[arr lastObject]
                            stringByReplacingPercentEscapesUsingEncoding:
                                NSUTF8StringEncoding]
                        forKey:[[arr objectAtIndex:0]
                            stringByReplacingPercentEscapesUsingEncoding:
                                NSUTF8StringEncoding]];
            }
        }

        // Actually open the file.
        NSString *file = [dict objectForKey:@"url"];
        if (file != nil) {
            NSURL *fileUrl= [NSURL URLWithString:file];
            // TextMate only opens files that already exist.
            if ([fileUrl isFileURL]
                    && [[NSFileManager defaultManager] fileExistsAtPath:
                           [fileUrl path]]) {
                // Strip 'file://' path, else application:openFiles: might think
                // the file is not yet open.
                NSArray *filenames = [NSArray arrayWithObject:[fileUrl path]];

                // Look for the line and column options.
                NSDictionary *args = nil;
                NSString *line = [dict objectForKey:@"line"];
                if (line) {
                    NSString *column = [dict objectForKey:@"column"];
                    if (column)
                        args = [NSDictionary dictionaryWithObjectsAndKeys:
                                line, @"cursorLine",
                                column, @"cursorColumn",
                                nil];
                    else
                        args = [NSDictionary dictionaryWithObject:line
                                forKey:@"cursorLine"];
                }

                [self openFiles:filenames withArguments:args];
            }
        }
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"OK",
            @"Dialog button")];

        [alert setMessageText:NSLocalizedString(@"Unknown URL Scheme",
            @"Unknown URL Scheme dialog, title")];
        [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(
            @"This version of MacVim does not support \"%@\""
            @" in its URL scheme.",
            @"Unknown URL Scheme dialog, text"),
            [url host]]];

        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        [alert release];
    }
}

- (NSMutableDictionary *)extractArgumentsFromOdocEvent:
    (NSAppleEventDescriptor *)desc
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // 1. Extract ODB parameters (if any)
    NSAppleEventDescriptor *odbdesc = desc;
    if (![odbdesc paramDescriptorForKeyword:keyFileSender]) {
        // The ODB paramaters may hide inside the 'keyAEPropData' descriptor.
        odbdesc = [odbdesc paramDescriptorForKeyword:keyAEPropData];
        if (![odbdesc paramDescriptorForKeyword:keyFileSender])
            odbdesc = nil;
    }

    if (odbdesc) {
        NSAppleEventDescriptor *p =
                [odbdesc paramDescriptorForKeyword:keyFileSender];
        if (p)
            [dict setObject:[NSNumber numberWithUnsignedInt:[p typeCodeValue]]
                     forKey:@"remoteID"];

        p = [odbdesc paramDescriptorForKeyword:keyFileCustomPath];
        if (p)
            [dict setObject:[p stringValue] forKey:@"remotePath"];

        p = [odbdesc paramDescriptorForKeyword:keyFileSenderToken];
        if (p) {
            [dict setObject:[NSNumber numberWithUnsignedLong:[p descriptorType]]
                     forKey:@"remoteTokenDescType"];
            [dict setObject:[p data] forKey:@"remoteTokenData"];
        }
    }

    // 2. Extract Xcode parameters (if any)
    NSAppleEventDescriptor *xcodedesc =
            [desc paramDescriptorForKeyword:keyAEPosition];
    if (xcodedesc) {
        NSRange range;
        NSData *data = [xcodedesc data];
        NSUInteger length = [data length];

        if (length == sizeof(MMXcodeSelectionRange)) {
            MMXcodeSelectionRange *sr = (MMXcodeSelectionRange*)[data bytes];
            ASLogDebug(@"Xcode selection range (%d,%d,%d,%d,%d,%d)",
                    sr->unused1, sr->lineNum, sr->startRange, sr->endRange,
                    sr->unused2, sr->theDate);

            if (sr->lineNum < 0) {
                // Should select a range of characters.
                range.location = sr->startRange + 1;
                range.length = sr->endRange > sr->startRange
                             ? sr->endRange - sr->startRange : 1;
            } else {
                // Should only move cursor to a line.
                range.location = sr->lineNum + 1;
                range.length = 0;
            }

            [dict setObject:NSStringFromRange(range) forKey:@"selectionRange"];
        } else {
            ASLogErr(@"Xcode selection range size mismatch! got=%ld "
                     "expected=%ld", length, sizeof(MMXcodeSelectionRange));
        }
    }

    // 3. Extract Spotlight search text (if any)
    NSAppleEventDescriptor *spotlightdesc =
            [desc paramDescriptorForKeyword:keyAESearchText];
    if (spotlightdesc) {
        NSString *s = [[spotlightdesc stringValue]
                                            stringBySanitizingSpotlightSearch];
        if (s && [s length] > 0)
            [dict setObject:s forKey:@"searchText"];
    }

    return dict;
}

- (MMVimController *)takeVimControllerFromCache
{
    MMVimController *vc = [vimManager getVimController];

    // If the Vim process has finished loading then the window will displayed
    // now, otherwise it will be displayed when the OpenWindowMsgID message is
    // received.
    [[vc windowController] presentWindow:nil];

    return vc;
}

- (BOOL)openVimControllerWithArguments:(NSDictionary *)arguments
{
    MMVimController *vc = [self takeVimControllerFromCache];

    return [vimManager openVimController:vc withArguments:arguments];
}

- (void)activateWhenNextWindowOpens
{
    ASLogDebug(@"Activate MacVim when next window opens");
    shouldActivateWhenNextWindowOpens = YES;
}


- (NSScreen *)screenContainingTopLeftPoint:(NSPoint)pt
{
    // NOTE: The top left point has y-coordinate which lies one pixel above the
    // window which must be taken into consideration (this method used to be
    // called screenContainingPoint: but that method is "off by one" in
    // y-coordinate).

    NSArray *screens = [NSScreen screens];
    NSUInteger i, count = [screens count];
    for (i = 0; i < count; ++i) {
        NSScreen *screen = [screens objectAtIndex:i];
        NSRect frame = [screen frame];
        if (pt.x >= frame.origin.x && pt.x < NSMaxX(frame)
                // NOTE: inequalities below are correct due to this being a top
                // left test (see comment above)
                && pt.y > frame.origin.y && pt.y <= NSMaxY(frame))
            return screen;
    }

    return nil;
}


@end // MMAppController (Private)
