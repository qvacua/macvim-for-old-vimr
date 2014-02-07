/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMLog.h"
#import "MMVimControllerDelegate.h"
#import "MMVimController.h"
#import "MMVimView.h"
#import "MMUserDefaults.h"
#import "MMUtils.h"
#import "MMTextViewProtocol.h"
#import "MMVimManager.h"
#import "MMTypes.h"
#import "MMCocoaCategories.h"
#import "MMVimBackendProtocol.h"


// NOTE: By default a message sent to the backend will be dropped if it cannot
// be delivered instantly; otherwise there is a possibility that MacVim will
// 'beachball' while waiting to deliver DO messages to an unresponsive Vim
// process.  This means that you cannot rely on any message sent with
// sendMessage: to actually reach Vim.
static NSTimeInterval MMBackendProxyRequestTimeout = 0;

// Timeout used for setDialogReturn:.
static NSTimeInterval MMSetDialogReturnTimeout = 1.0;

static unsigned identifierCounter = 1;

static BOOL isUnsafeMessage(int msgid);


@interface MMVimController (Private)

- (void)doProcessInputQueue:(NSArray *)queue;
- (void)handleMessage:(int)msgid data:(NSData *)data;
- (NSMenuItem *)menuItemForDescriptor:(NSArray *)desc;
- (NSMenu *)parentMenuForDescriptor:(NSArray *)desc;
- (void)addMenuWithDescriptor:(NSArray *)desc atIndex:(int)index;
- (void)addMenuItemWithDescriptor:(NSArray *)desc
                          atIndex:(int)index
                              tip:(NSString *)tip
                             icon:(NSString *)icon
                    keyEquivalent:(NSString *)keyEquivalent
                     modifierMask:(int)modifierMask
                           action:(NSString *)action
                      isAlternate:(BOOL)isAlternate;
- (void)removeMenuItemWithDescriptor:(NSArray *)desc;
- (void)enableMenuItemWithDescriptor:(NSArray *)desc state:(BOOL)on;
- (void)popupMenuWithDescriptor:(NSArray *)desc atRow:(NSNumber *)row column:(NSNumber *)col;
- (void)popupMenuWithAttributes:(NSDictionary *)attrs;
- (void)connectionDidDie:(NSNotification *)notification;
- (void)scheduleClose;
- (void)handleBrowseForFile:(NSDictionary *)attr data:(NSData *)data;
- (void)handleShowDialog:(NSDictionary *)attr data:(NSData *)data;
- (void)handleDeleteSign:(NSDictionary *)attr;

@end


@implementation MMVimController

- (id)initWithBackend:(id)backend pid:(int)processIdentifier {
    ASLogInfo(@"initing vim controller");
    if (!(self = [super init]))
        return nil;

    // TODO: Come up with a better way of creating an identifier.
    identifier = identifierCounter++;

    _vimView = [[MMVimView alloc] initWithFrame:NSMakeRect(0, 0, 640, 480) vimController:self];

    backendProxy = [backend retain];
    popupMenuItems = [[NSMutableArray alloc] init];
    pid = processIdentifier;
    creationDate = [[NSDate alloc] init];

    NSConnection *connection = [backendProxy connectionForProxy];

    // TODO: Check that this will not set the timeout for the root proxy (in MMAppController).
    [connection setRequestTimeout:MMBackendProxyRequestTimeout];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connectionDidDie:)
                                                 name:NSConnectionDidDieNotification object:connection];

    // Set up a main menu with only a "MacVim" menu (copied from a template
    // which itself is set up in MainMenu.nib).  The main menu is populated
    // by Vim later on.
    mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
    NSMenuItem *appMenuItem = [MMVimManager sharedManager].menuItemTemplate;
    appMenuItem = [[appMenuItem copy] autorelease];
    [mainMenu addItem:appMenuItem];

    isInitialized = YES;

    return self;
}

- (void)dealloc {
    ASLogDebug(@"");

    isInitialized = NO;

    [serverName release];
    [backendProxy release];

    [popupMenuItems release];

    [vimState release];
    [mainMenu release];
    [creationDate release];

    [_vimView release];

    [super dealloc];
}

- (unsigned)vimControllerId {
    return identifier;
}

- (NSDictionary *)vimState {
    return vimState;
}

- (id)objectForVimStateKey:(NSString *)key {
    return [vimState objectForKey:key];
}

- (NSMenu *)mainMenu {
    return mainMenu;
}

- (BOOL)isPreloading {
    return isPreloading;
}

- (void)setIsPreloading:(BOOL)yn {
    isPreloading = yn;
}

- (BOOL)hasModifiedBuffer {
    return hasModifiedBuffer;
}

- (NSDate *)creationDate {
    return creationDate;
}

- (void)setServerName:(NSString *)name {
    if (name != serverName) {
        [serverName release];
        serverName = [name copy];
    }
}

- (NSString *)serverName {
    return serverName;
}

- (int)pid {
    return pid;
}

- (void)dropFiles:(NSArray *)filenames forceOpen:(BOOL)force {
    filenames = normalizeFilenames(filenames);
    ASLogInfo(@"filenames=%@ force=%d", filenames, force);

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    // Default to opening in tabs if layout is invalid or set to "windows".
    int layout = [ud integerForKey:MMOpenLayoutKey];
    if (layout < 0 || layout > MMLayoutTabs)
        layout = MMLayoutTabs;

    BOOL splitVert = [ud boolForKey:MMVerticalSplitKey];
    if (splitVert && MMLayoutHorizontalSplit == layout)
        layout = MMLayoutVerticalSplit;

    NSDictionary *args = @{
            @"layout" : @(layout),
            @"filenames" : filenames,
            @"forceOpen" : @(force),
    };

    [self sendMessage:DropFilesMsgID data:[args dictionaryAsData]];
    [self.delegate vimController:self dropFiles:filenames forceOpen:force];
}

- (void)file:(NSString *)filename draggedToTabAtIndex:(NSUInteger)tabIndex {
    filename = normalizeFilename(filename);
    ASLogInfo(@"filename=%@ index=%ld", filename, tabIndex);

    NSString *fnEsc = [filename stringByEscapingSpecialFilenameCharacters];
    NSString *input = [NSString stringWithFormat:@"<C-\\><C-N>:silent "
                                                         "tabnext %ld |"
                                                         "edit! %@<CR>", tabIndex + 1, fnEsc];
    [self addVimInput:input];
}

- (void)filesDraggedToTabBar:(NSArray *)filenames {
    filenames = normalizeFilenames(filenames);
    ASLogInfo(@"%@", filenames);

    NSUInteger i, count = [filenames count];
    NSMutableString *input = [NSMutableString stringWithString:@"<C-\\><C-N>"
            ":silent! tabnext 9999"];
    for (i = 0; i < count; i++) {
        NSString *fn = [filenames objectAtIndex:i];
        NSString *fnEsc = [fn stringByEscapingSpecialFilenameCharacters];
        [input appendFormat:@"|tabedit %@", fnEsc];
    }
    [input appendString:@"<CR>"];
    [self addVimInput:input];
}

- (void)dropString:(NSString *)string {
    ASLogInfo(@"%@", string);
    int len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    if (len > 0) {
        NSMutableData *data = [NSMutableData data];

        [data appendBytes:&len length:sizeof(int)];
        [data appendBytes:[string UTF8String] length:(NSUInteger) len];

        [self sendMessage:DropStringMsgID data:data];
    }
}

- (void)passArguments:(NSDictionary *)args {
    if (!args) return;

    ASLogDebug(@"args=%@", args);

    [self sendMessage:OpenWithArgumentsMsgID data:[args dictionaryAsData]];
}

- (void)sendMessage:(int)msgid data:(NSData *)data {
    ASLogDebug(@"msg=%s (isInitialized=%d)",
    MessageStrings[msgid], isInitialized);

    if (!isInitialized) return;

    @try {
        [backendProxy processInput:msgid data:data];
    }
    @catch (NSException *ex) {
        ASLogDebug(@"processInput:data: failed: pid=%d id=%d msg=%s reason=%@",
        pid, identifier, MessageStrings[msgid], ex);
    }
}

- (BOOL)sendMessageNow:(int)msgid data:(NSData *)data
               timeout:(NSTimeInterval)timeout {
    // Send a message with a timeout.  USE WITH EXTREME CAUTION!  Sending
    // messages in rapid succession with a timeout may cause MacVim to beach
    // ball forever.  In almost all circumstances sendMessage:data: should be
    // used instead.

    ASLogDebug(@"msg=%s (isInitialized=%d)",
    MessageStrings[msgid], isInitialized);

    if (!isInitialized)
        return NO;

    if (timeout < 0) timeout = 0;

    BOOL sendOk = YES;
    NSConnection *conn = [backendProxy connectionForProxy];
    NSTimeInterval oldTimeout = [conn requestTimeout];

    [conn setRequestTimeout:timeout];

    @try {
        [backendProxy processInput:msgid data:data];
    }
    @catch (NSException *ex) {
        sendOk = NO;
        ASLogDebug(@"processInput:data: failed: pid=%d id=%d msg=%s reason=%@",
        pid, identifier, MessageStrings[msgid], ex);
    }
    @finally {
        [conn setRequestTimeout:oldTimeout];
    }

    return sendOk;
}

- (void)addVimInput:(NSString *)string {
    ASLogDebug(@"%@", string);

    // This is a very general method of adding input to the Vim process.  It is
    // basically the same as calling remote_send() on the process (see
    // ':h remote_send').
    if (string) {
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        [self sendMessage:AddInputMsgID data:data];
    }
}

- (NSString *)evaluateVimExpression:(NSString *)expr {
    NSString *eval = nil;

    @try {
        eval = [backendProxy evaluateExpression:expr];
        ASLogDebug(@"eval(%@)=%@", expr, eval);
    }
    @catch (NSException *ex) {
        ASLogDebug(@"evaluateExpression: failed: pid=%d id=%d reason=%@",
        pid, identifier, ex);
    }

    return eval;
}

- (id)backendProxy {
    return backendProxy;
}

- (void)cleanup {
    if (!isInitialized) return;

    // Remove any delayed calls made on this object.
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    isInitialized = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)processInputQueue:(NSArray *)queue {
    if (!isInitialized) return;

    // NOTE: This method must not raise any exceptions (see comment in the
    // calling method).
    @try {
        [self doProcessInputQueue:queue];
        [self.delegate vimController:self processFinishedForInputQueue:queue];
    }
    @catch (NSException *ex) {
        ASLogDebug(@"Exception: pid=%d id=%d reason=%@", pid, identifier, ex);
    }
}


- (BOOL)tellBackend:(id)obj {
    BOOL success = NO;
    @try {
        [backendProxy setDialogReturn:obj];
        success = YES;
    } @catch (NSException *ex) {
        ASLogDebug(@"setDialogReturn: failed: pid=%d id=%d reason=%@", pid, identifier, ex);
    }

    return success;
}

- (BOOL)sendDialogReturnToBackend:(id)obj {
    // NOTE! setDialogReturn: is a synchronous call so set a proper timeout to
    // avoid waiting forever for it to finish.  We make this a synchronous call
    // so that we can be fairly certain that Vim doesn't think the dialog box
    // is still showing when MacVim has in fact already dismissed it.
    NSConnection *conn = [backendProxy connectionForProxy];
    NSTimeInterval oldTimeout = [conn requestTimeout];
    [conn setRequestTimeout:MMSetDialogReturnTimeout];

    BOOL success = [self tellBackend:obj];
    [conn setRequestTimeout:oldTimeout];

    return success;
}

@end // MMVimController



@implementation MMVimController (Private)

- (void)doProcessInputQueue:(NSArray *)queue {
    NSMutableArray *delayQueue = nil;

    unsigned i, count = [queue count];
    if (count % 2) {
        ASLogWarn(@"Uneven number of components (%d) in command queue.  "
                "Skipping...", count);
        return;
    }

    for (i = 0; i < count; i += 2) {
        NSData *value = [queue objectAtIndex:i];
        NSData *data = [queue objectAtIndex:i + 1];

        int msgid = *((int *) [value bytes]);

        BOOL inDefaultMode = [[[NSRunLoop currentRunLoop] currentMode]
                isEqual:NSDefaultRunLoopMode];
        if (!inDefaultMode && isUnsafeMessage(msgid)) {
            // NOTE: Because we may be listening to DO messages in "event
            // tracking mode" we have to take extra care when doing things
            // like releasing view items (and other Cocoa objects).
            // Messages that may be potentially "unsafe" are delayed until
            // the run loop is back to default mode at which time they are
            // safe to call again.
            //   A problem with this approach is that it is hard to
            // classify which messages are unsafe.  As a rule of thumb, if
            // a message may release an object used by the Cocoa framework
            // (e.g. views) then the message should be considered unsafe.
            //   Delaying messages may have undesired side-effects since it
            // means that messages may not be processed in the order Vim
            // sent them, so beware.
            if (!delayQueue)
                delayQueue = [NSMutableArray array];

            ASLogDebug(@"Adding unsafe message '%s' to delay queue (mode=%@)",
            MessageStrings[msgid],
            [[NSRunLoop currentRunLoop] currentMode]);
            [delayQueue addObject:value];
            [delayQueue addObject:data];
        } else {
            [self handleMessage:msgid data:data];
        }
    }

    if (delayQueue) {
        ASLogDebug(@"    Flushing delay queue (%ld items)",
        [delayQueue count] / 2);
        [self performSelector:@selector(processInputQueue:)
                   withObject:delayQueue
                   afterDelay:0];
    }
}

- (void)handleMessage:(int)msgid data:(NSData *)data {
    if (OpenWindowMsgID == msgid) {
        [self.delegate vimController:self openWindowWithData:data];
        return;
    }

    if (BatchDrawMsgID == msgid) {
        [[self.vimView textView] performBatchDrawWithData:data];
        return;
    }

    if (SelectTabMsgID == msgid) {
        // NOTE: Tab selection is done inside updateTabsWithData:.
        return;
    }

    if (UpdateTabBarMsgID == msgid) {
        [self.vimView updateTabsWithData:data];
        return;
    }

    if (ShowTabBarMsgID == msgid) {
        [self.delegate vimController:self showTabBarWithData:data];
        return;
    }

    if (HideTabBarMsgID == msgid) {
        [self.delegate vimController:self hideTabBarWithData:data];
        return;
    }

    if (SetTextDimensionsMsgID == msgid || LiveResizeMsgID == msgid || SetTextDimensionsReplyMsgID == msgid) {
        const void *bytes = [data bytes];
        int rows = *((int *) bytes);
        bytes += sizeof(int);
        int cols = *((int *) bytes);

        // NOTE: When a resize message originated in the frontend, Vim
        // acknowledges it with a reply message.  When this happens the window
        // should not move (the frontend would already have moved the window).
        BOOL onScreen = SetTextDimensionsReplyMsgID != msgid;
        BOOL isLive = LiveResizeMsgID == msgid;

        [self.delegate vimController:self
           setTextDimensionsWithRows:rows
                             columns:cols
                              isLive:isLive
                        keepOnScreen:onScreen
                                data:data];
        return;
    }

    if (SetWindowTitleMsgID == msgid) {
        const void *bytes = [data bytes];
        int len = *((int *) bytes);
        bytes += sizeof(int);

        NSString *title = [[NSString alloc] initWithBytes:(void *) bytes
                                                   length:(NSUInteger) len
                                                 encoding:NSUTF8StringEncoding];

        [self.delegate vimController:self setWindowTitle:title data:data];

        [title release];
        return;
    }

    if (SetDocumentFilenameMsgID == msgid) {
        const void *bytes = [data bytes];
        int len = *((int *) bytes);
        bytes += sizeof(int);

        NSString *filename;
        if (len > 0) {
            filename = [[NSString alloc] initWithBytes:(void *) bytes
                                                length:(NSUInteger) len
                                              encoding:NSUTF8StringEncoding];
        } else {
            filename = [[NSString alloc] initWithString:@""];
        }

        [self.delegate vimController:self setDocumentFilename:filename data:data];

        [filename release];
        return;
    }

    if (AddMenuMsgID == msgid) {
        NSDictionary *attrs = [NSDictionary dictionaryWithData:data];
        [self addMenuWithDescriptor:attrs[@"descriptor"] atIndex:[attrs[@"index"] intValue]];

        return;
    }

    if (AddMenuItemMsgID == msgid) {
        NSDictionary *attrs = [NSDictionary dictionaryWithData:data];
        [self addMenuItemWithDescriptor:attrs[@"descriptor"]
                                atIndex:[attrs[@"index"] intValue]
                                    tip:attrs[@"tip"]
                                   icon:attrs[@"icon"]
                          keyEquivalent:attrs[@"keyEquivalent"]
                           modifierMask:[attrs[@"modifierMask"] intValue]
                                 action:attrs[@"action"]
                            isAlternate:[attrs[@"isAlternate"] boolValue]];

        return;
    }

    if (RemoveMenuItemMsgID == msgid) {
        NSDictionary *attrs = [NSDictionary dictionaryWithData:data];
        [self removeMenuItemWithDescriptor:attrs[@"descriptor"]];

        return;
    }

    if (EnableMenuItemMsgID == msgid) {
        NSDictionary *attrs = [NSDictionary dictionaryWithData:data];
        [self enableMenuItemWithDescriptor:attrs[@"descriptor"] state:[attrs[@"enable"] boolValue]];

        return;
    }

    if (ShowToolbarMsgID == msgid) {
        const void *bytes = [data bytes];
        int enable = *((int *) bytes);
        bytes += sizeof(int);
        int flags = *((int *) bytes);

        [self.delegate vimController:self showToolbar:(BOOL) enable flags:flags data:data];
        return;
    }

    if (CreateScrollbarMsgID == msgid) {
        const void *bytes = [data bytes];
        int32_t ident = *((int32_t *) bytes);
        bytes += sizeof(int32_t);
        int type = *((int *) bytes);

        [self.vimView createScrollbarWithIdentifier:identifier type:type];
        if ([self.delegate respondsToSelector:@selector(vimController:createScrollbarWithIdentifier:type:data:)]) {
            [self.delegate vimController:self createScrollbarWithIdentifier:ident type:type data:data];
        }

        return;
    }

    if (DestroyScrollbarMsgID == msgid) {
        const void *bytes = [data bytes];
        int32_t ident = *((int32_t *) bytes);

        [self.delegate vimController:self destroyScrollbarWithIdentifier:ident data:data];
        return;
    }

    if (ShowScrollbarMsgID == msgid) {
        const void *bytes = [data bytes];
        int32_t ident = *((int32_t *) bytes);
        bytes += sizeof(int32_t);
        int visible = *((int *) bytes);

        [self.delegate vimController:self showScrollbarWithIdentifier:ident state:(BOOL) visible data:data];
        return;
    }

    if (SetScrollbarPositionMsgID == msgid) {
        const void *bytes = [data bytes];
        int32_t ident = *((int32_t *) bytes);
        bytes += sizeof(int32_t);
        int pos = *((int *) bytes);
        bytes += sizeof(int);
        int len = *((int *) bytes);

        [self.delegate vimController:self setScrollbarPosition:pos length:len identifier:ident data:data];
        return;
    }

    if (SetScrollbarThumbMsgID == msgid) {
        const void *bytes = [data bytes];
        int32_t ident = *((int32_t *) bytes);
        bytes += sizeof(int32_t);
        float val = *((float *) bytes);
        bytes += sizeof(float);
        float prop = *((float *) bytes);

        [self.delegate vimController:self setScrollbarThumbValue:val proportion:prop identifier:ident data:data];
        return;
    }

    if (SetFontMsgID == msgid) {
        const void *bytes = [data bytes];
        float size = *((float *) bytes);
        bytes += sizeof(float);
        int len = *((int *) bytes);
        bytes += sizeof(int);

        NSString *name = [[NSString alloc] initWithBytes:(void *) bytes
                                                  length:(NSUInteger) len
                                                encoding:NSUTF8StringEncoding];
        NSFont *font = [NSFont fontWithName:name size:size];
        [name release];

        if (!font) {
            // This should only happen if the system default font has changed
            // name since MacVim was compiled in which case we fall back on
            // using the user fixed width font.
            font = [NSFont userFixedPitchFontOfSize:size];
        }

        self.vimView.textView.font = font;
        if ([self.delegate respondsToSelector:@selector(vimController:setFont:data:)]) {
            [self.delegate vimController:self setFont:font data:data];
        }

        return;
    }

    if (SetWideFontMsgID == msgid) {
        const void *bytes = [data bytes];
        float size = *((float *) bytes);
        bytes += sizeof(float);
        int len = *((int *) bytes);
        bytes += sizeof(int);

        NSFont *font = nil;
        if (len > 0) {
            NSString *name = [[NSString alloc] initWithBytes:(void *) bytes
                                                      length:(NSUInteger) len
                                                    encoding:NSUTF8StringEncoding];
            font = [NSFont fontWithName:name size:size];
            [name release];
        }

        self.vimView.textView.wideFont = font;
        if ([self.delegate respondsToSelector:@selector(vimController:setWideFont:data:)]) {
            [self.delegate vimController:self setWideFont:font data:data];
        }

        return;
    }

    if (SetDefaultColorsMsgID == msgid) {
        const void *bytes = [data bytes];
        unsigned bg = *((unsigned *) bytes);
        bytes += sizeof(unsigned);
        unsigned fg = *((unsigned *) bytes);

        NSColor *back = [NSColor colorWithArgbInt:bg];
        NSColor *fore = [NSColor colorWithRgbInt:fg];

        [self.vimView setDefaultColorsBackground:back foreground:fore];
        if ([self.delegate respondsToSelector:@selector(vimController:setDefaultColorsBackground:foreground:data:)]) {
            [self.delegate vimController:self setDefaultColorsBackground:back foreground:fore data:data];
        }

        return;
    }

    if (ExecuteActionMsgID == msgid) {
        const void *bytes = [data bytes];
        int len = *((int *) bytes);
        bytes += sizeof(int);
        NSString *actionName = [[NSString alloc] initWithBytes:(void *) bytes
                                                        length:(NSUInteger) len
                                                      encoding:NSUTF8StringEncoding];

        SEL sel = NSSelectorFromString(actionName);
        [NSApp sendAction:sel to:nil from:self];

        [actionName release];
        return;
    }

    if (ShowPopupMenuMsgID == msgid) {
        NSDictionary *attrs = [NSDictionary dictionaryWithData:data];

        ASLogInfo(@"show popup");
        // The popup menu enters a modal loop so delay this call so that we
        // don't block inside processInputQueue:.
        [self performSelector:@selector(popupMenuWithAttributes:)
                   withObject:attrs
                   afterDelay:0];

        return;
    }

    if (SetMouseShapeMsgID == msgid) {
        const void *bytes = [data bytes];
        int shape = *((int *) bytes);

        [self.delegate vimController:self setMouseShape:shape data:data];
        return;
    }

    if (AdjustLinespaceMsgID == msgid) {
        const void *bytes = [data bytes];
        int linespace = *((int *) bytes);

        self.vimView.textView.linespace = (float) linespace;
        if ([self.delegate respondsToSelector:@selector(vimController:adjustLinespace:data:)]) {
            [self.delegate vimController:self adjustLinespace:linespace data:data];
        }

        return;
    }

    if (ActivateMsgID == msgid) {
        [self.delegate vimController:self activateWithData:data];
        return;
    }

    if (SetServerNameMsgID == msgid) {
        NSString *name = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self setServerName:name];

        [name release];
        return;
    }

    if (EnterFullScreenMsgID == msgid) {
        const void *bytes = [data bytes];
        int fuoptions = *((int *) bytes);
        bytes += sizeof(int);
        int bg = *((int *) bytes);

        NSColor *back = [NSColor colorWithArgbInt:(unsigned int) bg];

        [self.delegate vimController:self enterFullScreen:fuoptions backgroundColor:back data:data];
        return;
    }

    if (LeaveFullScreenMsgID == msgid) {
        [self.delegate vimController:self leaveFullScreenWithData:data];
        return;
    }

    if (SetBuffersModifiedMsgID == msgid) {
        const void *bytes = [data bytes];
        // state < 0  <->  some buffer modified
        // state > 0  <->  current buffer modified
        int state = *((int *) bytes);

        // NOTE: The window controller tracks whether current buffer is
        // modified or not (and greys out the proxy icon as well as putting a
        // dot in the red "close button" if necessary).  The Vim controller
        // tracks whether any buffer has been modified (used to decide whether
        // to show a warning or not when quitting).
        //
        // TODO: Make 'hasModifiedBuffer' part of the Vim state?
        [self.delegate vimController:self setBufferModified:(state > 0) data:data];
        hasModifiedBuffer = (state != 0);

        return;
    }

    if (SetPreEditPositionMsgID == msgid) {
        const int *dim = (const int *) [data bytes];

        [self.delegate vimController:self setPreEditRow:dim[0] column:dim[1] data:data];
        return;
    }

    if (EnableAntialiasMsgID == msgid) {
        [self.delegate vimController:self setAntialias:YES data:data];
        return;
    }

    if (DisableAntialiasMsgID == msgid) {
        [self.delegate vimController:self setAntialias:NO data:data];
        return;
    }

    if (SetVimStateMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        if (dict) {
            [vimState release];
            vimState = [dict retain];
        }

        return;
    }

    if (CloseWindowMsgID == msgid) {
        // TODO: work to do
        [self scheduleClose];
        return;
    }

    if (SetFullScreenColorMsgID == msgid) {
        const int *bg = (const int *) [data bytes];
        NSColor *color = [NSColor colorWithRgbInt:(unsigned int) *bg];

        [self.delegate vimController:self setFullScreenBackgroundColor:color data:data];
        return;
    }

    if (ShowFindReplaceDialogMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        if (dict) {
            [self.delegate vimController:self
           showFindReplaceDialogWithText:dict[@"text"]
                                   flags:[dict[@"flags"] intValue]
                                    data:data];
        }

        return;
    }

    if (ActivateKeyScriptMsgID == msgid) {
        [self.delegate vimController:self activateIm:YES data:data];
        return;
    }

    if (DeactivateKeyScriptMsgID == msgid) {
        [self.delegate vimController:self activateIm:NO data:data];
        return;
    }

    if (EnableImControlMsgID == msgid) {
        [self.delegate vimController:self setImControl:YES data:data];
        return;
    }

    if (DisableImControlMsgID == msgid) {
        [self.delegate vimController:self setImControl:NO data:data];
        return;
    }

    if (BrowseForFileMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        if (dict)
            [self handleBrowseForFile:dict data:data];
        return;
    }

    if (ShowDialogMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        if (dict)
            [self handleShowDialog:dict data:data];
        return;
    }

    if (DeleteSignMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        if (dict)
            [self handleDeleteSign:dict];
        return;
    }

    if (ZoomMsgID == msgid) {
        const void *bytes = [data bytes];
        int rows = *((int *) bytes);
        bytes += sizeof(int);
        int cols = *((int *) bytes);
        bytes += sizeof(int);
        int state = *((int *) bytes);

        [self.delegate vimController:self zoomWithRows:rows columns:cols state:state data:data];
        return;
    }

    if (SetWindowPositionMsgID == msgid) {
        const void *bytes = [data bytes];
        int x = *((int *) bytes);
        bytes += sizeof(int);
        int y = *((int *) bytes);

        [self.delegate vimController:self setWindowPosition:NSMakePoint(x, y) data:data];
        return;
    }

    // TODO: Tae
    if (SetTooltipMsgID == msgid) {
        NSView <MMTextViewProtocol> *textView = [self.vimView textView];
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        NSString *toolTip = dict ? [dict objectForKey:@"toolTip"] : nil;
        if (toolTip && [toolTip length] > 0)
            [textView setToolTipAtMousePoint:toolTip];
        else
            [textView setToolTipAtMousePoint:nil];
        return;
    }

    if (SetTooltipDelayMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];
        NSNumber *delay = dict ? [dict objectForKey:@"delay"] : nil;
        if (delay)
            [self.delegate vimController:self setTooltipDelay:[delay floatValue]];
        return;
    }

    if (AddToMRUMsgID == msgid) {
        NSDictionary *dict = [NSDictionary dictionaryWithData:data];

        NSArray *filenames = dict ? [dict objectForKey:@"filenames"] : nil;
        if (filenames) {
            [self.delegate vimController:self addToMru:filenames data:data];
        }

        return;
    }

            // IMPORTANT: When adding a new message, make sure to update
            // isUnsafeMessage() if necessary!

            ASLogWarn(@"Unknown message received (msgid=%d)", msgid);
}

- (NSMenuItem *)menuItemForDescriptor:(NSArray *)desc {
    if (!(desc && [desc count] > 0)) return nil;

    NSString *rootName = [desc objectAtIndex:0];
    NSArray *rootItems = [rootName hasPrefix:@"PopUp"] ? popupMenuItems
            : [mainMenu itemArray];

    NSMenuItem *item = nil;
    int i, count = [rootItems count];
    for (i = 0; i < count; ++i) {
        item = [rootItems objectAtIndex:(NSUInteger) i];
        if ([[item title] isEqual:rootName])
            break;
    }

    if (i == count) return nil;

    count = [desc count];
    for (i = 1; i < count; ++i) {
        item = [[item submenu] itemWithTitle:[desc objectAtIndex:(NSUInteger) i]];
        if (!item) return nil;
    }

    return item;
}

- (NSMenu *)parentMenuForDescriptor:(NSArray *)desc {
    if (!(desc && [desc count] > 0)) return nil;

    NSString *rootName = [desc objectAtIndex:0];
    NSArray *rootItems = [rootName hasPrefix:@"PopUp"] ? popupMenuItems
            : [mainMenu itemArray];

    NSMenu *menu = nil;
    int i, count = [rootItems count];
    for (i = 0; i < count; ++i) {
        NSMenuItem *item = [rootItems objectAtIndex:(NSUInteger) i];
        if ([[item title] isEqual:rootName]) {
            menu = [item submenu];
            break;
        }
    }

    if (!menu) return nil;

    count = [desc count] - 1;
    for (i = 1; i < count; ++i) {
        NSMenuItem *item = [menu itemWithTitle:[desc objectAtIndex:(NSUInteger) i]];
        menu = [item submenu];
        if (!menu) return nil;
    }

    return menu;
}

- (void)addMenuWithDescriptor:(NSArray *)desc atIndex:(int)idx {
    if (!(desc && [desc count] > 0 && idx >= 0)) return;

    NSString *rootName = [desc objectAtIndex:0];
    if ([rootName isEqual:@"ToolBar"]) {
        return;
    }

    // This is either a main menu item or a popup menu item.
    NSString *title = [desc lastObject];
    NSMenuItem *item = [[NSMenuItem alloc] init];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:title];

    [item setTitle:title];
    [item setSubmenu:menu];

    NSMenu *parent = [self parentMenuForDescriptor:desc];
    if (!parent && [rootName hasPrefix:@"PopUp"]) {
        if ([popupMenuItems count] <= idx) {
            [popupMenuItems addObject:item];
        } else {
            [popupMenuItems insertObject:item atIndex:(NSUInteger) idx];
        }
    } else {
        // If descriptor has no parent and its not a popup (or toolbar) menu,
        // then it must belong to main menu.
        if (!parent) parent = mainMenu;

        if ([parent numberOfItems] <= idx) {
            [parent addItem:item];
        } else {
            [parent insertItem:item atIndex:idx];
        }
    }

    [item release];
    [menu release];
}

- (void)addMenuItemWithDescriptor:(NSArray *)desc
                          atIndex:(int)idx
                              tip:(NSString *)tip
                             icon:(NSString *)icon
                    keyEquivalent:(NSString *)keyEquivalent
                     modifierMask:(int)modifierMask
                           action:(NSString *)action
                      isAlternate:(BOOL)isAlternate {
    if (!(desc && [desc count] > 1 && idx >= 0)) return;

    NSString *title = [desc lastObject];
    NSString *rootName = [desc objectAtIndex:0];

    if ([rootName isEqual:@"ToolBar"]) {
        if ([desc count] == 2)
            [self.delegate vimController:self addToolbarItemWithLabel:title tip:tip icon:icon atIndex:idx];
        return;
    }

    NSMenu *parent = [self parentMenuForDescriptor:desc];
    if (!parent) {
        ASLogWarn(@"Menu item '%@' has no parent",
        [desc componentsJoinedByString:@"->"]);
        return;
    }

    NSMenuItem *item = nil;
    if (0 == [title length]
            || ([title hasPrefix:@"-"] && [title hasSuffix:@"-"])) {
        item = [NSMenuItem separatorItem];
        [item setTitle:title];
    } else {
        item = [[[NSMenuItem alloc] init] autorelease];
        [item setTitle:title];

        // Note: It is possible to set the action to a message that "doesn't
        // exist" without problems.  We take advantage of this when adding
        // "dummy items" e.g. when dealing with the "Recent Files" menu (in
        // which case a recentFilesDummy: action is set, although it is never
        // used).
        if ([action length] > 0)
            [item setAction:NSSelectorFromString(action)];
        else
            [item setAction:@selector(vimMenuItemAction:)];
        if ([tip length] > 0) [item setToolTip:tip];
        if ([keyEquivalent length] > 0) {
            [item setKeyEquivalent:keyEquivalent];
            [item setKeyEquivalentModifierMask:(NSUInteger) modifierMask];
        }
        [item setAlternate:isAlternate];

        // The tag is used to indicate whether Vim thinks a menu item should be
        // enabled or disabled.  By default Vim thinks menu items are enabled.
        [item setTag:1];
    }

    if ([parent numberOfItems] <= idx) {
        [parent addItem:item];
    } else {
        [parent insertItem:item atIndex:idx];
    }
}

- (void)removeMenuItemWithDescriptor:(NSArray *)desc {
    if (!(desc && [desc count] > 0)) return;

    NSString *title = [desc lastObject];
    NSString *rootName = [desc objectAtIndex:0];
    if ([rootName isEqual:@"ToolBar"]) {
        if ([desc count] == 2) {
            [self.delegate vimController:self removeToolbarItemWithIdentifier:title];
        }

        return;
    }

    NSMenuItem *item = [self menuItemForDescriptor:desc];
    if (!item) {
        ASLogWarn(@"Failed to remove menu item, descriptor not found: %@",
        [desc componentsJoinedByString:@"->"]);
        return;
    }

    [item retain];

    if ([item menu] == [NSApp mainMenu] || ![item menu]) {
        // NOTE: To be on the safe side we try to remove the item from
        // both arrays (it is ok to call removeObject: even if an array
        // does not contain the object to remove).
        [popupMenuItems removeObject:item];
    }

    if ([item menu])
        [[item menu] removeItem:item];

    [item release];
}

- (void)enableMenuItemWithDescriptor:(NSArray *)desc state:(BOOL)on {
    if (!(desc && [desc count] > 0)) return;

    NSString *rootName = [desc objectAtIndex:0];
    if ([rootName isEqual:@"ToolBar"]) {
        if ([desc count] == 2) {
            NSString *title = [desc lastObject];
            [self.delegate vimController:self setStateToolbarItemWithIdentifier:title state:on];
        }
    } else {
        // Use tag to set whether item is enabled or disabled instead of
        // calling setEnabled:.  This way the menus can autoenable themselves
        // but at the same time Vim can set if a menu is enabled whenever it
        // wants to.
        [[self menuItemForDescriptor:desc] setTag:on];
    }
}

- (void)popupMenuWithDescriptor:(NSArray *)desc
                          atRow:(NSNumber *)row
                         column:(NSNumber *)col {
    NSMenu *menu = [[self menuItemForDescriptor:desc] submenu];
    if (!menu) return;

    id textView = [[self vimView] textView];
    NSPoint pt;
    if (row && col) {
        // TODO: Let textView convert (row,col) to NSPoint.
        int r = [row intValue];
        int c = [col intValue];
        NSSize cellSize = [textView cellSize];
        pt = NSMakePoint((c + 1) * cellSize.width, (r + 1) * cellSize.height);
        pt = [textView convertPoint:pt toView:nil];
    } else {
        pt = [[self.vimView window] mouseLocationOutsideOfEventStream];
    }

    NSEvent *event = [NSEvent mouseEventWithType:NSRightMouseDown
                                        location:pt
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:[[self.vimView window] windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:0
                                        pressure:1.0];

    [NSMenu popUpContextMenu:menu withEvent:event forView:textView];
}

- (void)popupMenuWithAttributes:(NSDictionary *)attrs {
    if (!attrs) return;

    [self popupMenuWithDescriptor:[attrs objectForKey:@"descriptor"]
                            atRow:[attrs objectForKey:@"row"]
                           column:[attrs objectForKey:@"column"]];
}

- (void)connectionDidDie:(NSNotification *)notification {
    ASLogDebug(@"%@", notification);
    [self scheduleClose];
}

- (void)scheduleClose {
    ASLogDebug(@"pid=%d id=%d", pid, identifier);

    // NOTE!  This message can arrive at pretty much anytime, e.g. while
    // the run loop is the 'event tracking' mode.  This means that Cocoa may
    // well be in the middle of processing some message while this message is
    // received.  If we were to remove the vim controller straight away we may
    // free objects that Cocoa is currently using (e.g. view objects).  The
    // following call ensures that the vim controller is not released until the
    // run loop is back in the 'default' mode.
    // Also, since the app may be multithreaded (e.g. as a result of showing
    // the open panel) we have to ensure this call happens on the main thread,
    // else there is a race condition that may lead to a crash.
    [[MMVimManager sharedManager]
            performSelectorOnMainThread:@selector(removeVimController:)
                             withObject:self
                          waitUntilDone:NO
                                  modes:@[NSDefaultRunLoopMode]];
}

- (void)handleBrowseForFile:(NSDictionary *)attr data:(NSData *)data {
    if (!isInitialized) return;

    NSString *dir = attr[@"dir"];
    BOOL saving = [attr[@"saving"] boolValue];
    BOOL browsedir = [attr[@"browsedir"] boolValue];

    if (!dir) {
        // 'dir == nil' means: set dir to the pwd of the Vim process, or let
        // open dialog decide (depending on the below user default).
        BOOL trackPwd = [[NSUserDefaults standardUserDefaults] boolForKey:MMDialogsTrackPwdKey];
        if (trackPwd)
            dir = vimState[@"pwd"];
    }

    // 10.6+ APIs uses URLs instead of paths
    dir = [dir stringByExpandingTildeInPath];
    NSURL *dirURL = dir ? [NSURL fileURLWithPath:dir isDirectory:YES] : nil;

    [self.delegate vimController:self handleBrowseWithDirectoryUrl:dirURL browseDir:browsedir saving:saving data:data];
}

- (void)handleShowDialog:(NSDictionary *)attr data:(NSData *)data {
    if (!isInitialized) return;

    NSArray *buttonTitles = attr[@"buttonTitles"];
    if (!(buttonTitles && [buttonTitles count])) {
        return;
    }

    NSAlertStyle style = (NSAlertStyle) [attr[@"alertStyle"] intValue];
    NSString *message = attr[@"messageText"];
    NSString *text = attr[@"informativeText"];
    NSString *textFieldString = attr[@"textFieldString"];

    [self.delegate vimController:self handleShowDialogWithButtonTitles:buttonTitles style:style message:message
                            text:text textFieldString:textFieldString data:data];
}

- (void)handleDeleteSign:(NSDictionary *)attr {
    [[self.vimView textView] deleteSign:[attr objectForKey:@"imgName"]];
}

@end // MMVimController (Private)



static BOOL
isUnsafeMessage(int msgid) {
    // Messages that may release Cocoa objects must be added to this list.  For
    // example, UpdateTabBarMsgID may delete NSTabViewItem objects so it goes
    // on this list.
    static int unsafeMessages[] = { // REASON MESSAGE IS ON THIS LIST:
            //OpenWindowMsgID,            // Changes lots of state
            UpdateTabBarMsgID,          // May delete NSTabViewItem
            RemoveMenuItemMsgID,        // Deletes NSMenuItem
            DestroyScrollbarMsgID,      // Deletes NSScroller
            ExecuteActionMsgID,         // Impossible to predict
            ShowPopupMenuMsgID,         // Enters modal loop
            ActivateMsgID,              // ?
            EnterFullScreenMsgID,       // Modifies delegate of window controller
            LeaveFullScreenMsgID,       // Modifies delegate of window controller
            CloseWindowMsgID,           // See note below
            BrowseForFileMsgID,         // Enters modal loop
            ShowDialogMsgID,            // Enters modal loop
    };

    // NOTE about CloseWindowMsgID: If this arrives at the same time as say
    // ExecuteActionMsgID, then the "execute" message will be lost due to it
    // being queued and handled after the "close" message has caused the
    // controller to cleanup...UNLESS we add CloseWindowMsgID to the list of
    // unsafe messages.  This is the _only_ reason it is on this list (since
    // all that happens in response to it is that we schedule another message
    // for later handling).

    int i, count = sizeof(unsafeMessages) / sizeof(unsafeMessages[0]);
    for (i = 0; i < count; ++i)
        if (msgid == unsafeMessages[i])
            return YES;

    return NO;
}
