/* vi:set ts=8 sts=4 sw=4 ft=objc:
 *
 * VIM - Vi IMproved		by Bram Moolenaar
 *				MacVim GUI port by Bjorn Winckler
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#import "MMVimManager.h"
#import "MMLog.h"
#import "MMVimController.h"
#import "MMUserDefaults.h"
#import "MMWindowController.h"
#import "MMTextView.h"
// Need Carbon for TIS...() functions
#import <Carbon/Carbon.h>


// Default timeout intervals on all connections.
static NSTimeInterval MMRequestTimeout = 5;
static NSTimeInterval MMReplyTimeout = 5;


// Latency (in s) between FS event occuring and being reported to MacVim.
// Should be small so that MacVim is notified of changes to the ~/.vim
// directory more or less immediately.
static CFTimeInterval MMEventStreamLatency = 0.1;

static void fsEventCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]) {
    [[MMVimManager sharedManager] handleFSEvent];
}


@interface MMVimManager ()

@property (readonly) NSMutableArray *mutableVimControllers;
@property (readonly) NSMutableArray *mutableCachedVimControllers;

@end


@implementation MMVimManager {
    NSConnection *connection;
    NSMutableDictionary *inputQueues;

    NSMutableArray *_vimControllers;
    NSMutableArray *_cachedVimControllers;

    int numChildProcesses;
    int processingFlag;
    int preloadPid;
    NSMutableDictionary *pidArguments;

    FSEventStreamRef fsEventStream;
    BOOL lastVimControllerHasArgs;
}

@dynamic mutableVimControllers;
@dynamic mutableCachedVimControllers;

#pragma mark Public
- (void)handleFSEvent {
    [self clearPreloadCacheWithCount:-1];

    // Several FS events may arrive in quick succession so make sure to cancel
    // any previous preload requests before making a new one.
    [self cancelVimControllerPreloadRequests];
    [self scheduleVimControllerPreloadAfterDelay:0.5];
}

- (BOOL)readAndResetLastVimControllerHasArgs {
    BOOL result = lastVimControllerHasArgs;

    lastVimControllerHasArgs = NO;

    return result;
}

- (int)maxPreloadCacheSize {
    // The maximum number of Vim processes to keep in the cache can be
    // controlled via the user default "MMPreloadCacheSize".
    int maxCacheSize = [[NSUserDefaults standardUserDefaults]
            integerForKey:MMPreloadCacheSizeKey];
    if (maxCacheSize < 0) maxCacheSize = 0;
    else if (maxCacheSize > 10) maxCacheSize = 10;

    return maxCacheSize;
}

- (void)setUp {
    if ([self maxPreloadCacheSize] > 0) {
        [self scheduleVimControllerPreloadAfterDelay:2];
        [self startWatchingVimDir];
    }

    [self addInputSourceChangedObserver];
}

- (void)rebuildPreloadCache {
    if ([self maxPreloadCacheSize] > 0) {
        [self clearPreloadCacheWithCount:-1];
        [self cancelVimControllerPreloadRequests];
        [self scheduleVimControllerPreloadAfterDelay:1.0];
    }
}

- (void)toggleQuickStart {
    if ([self maxPreloadCacheSize] > 0) {
        [self scheduleVimControllerPreloadAfterDelay:1.0];
        [self startWatchingVimDir];
    } else {
        [self cancelVimControllerPreloadRequests];
        [self clearPreloadCacheWithCount:-1];
        [self stopWatchingVimDir];
    }
}

- (BOOL)openVimController:(MMVimController *)vc withArguments:(NSDictionary *)arguments {
    if (vc) {
        // Open files in a new window using a cached vim controller.  This
        // requires virtually no loading time so the new window will pop up
        // instantaneously.
        [vc passArguments:arguments];
        [[vc backendProxy] acknowledgeConnection];
    } else {
        NSArray *cmdline = nil;
        NSString *cwd = [self workingDirectoryForArguments:arguments];
        arguments = [self convertVimControllerArguments:arguments
                                          toCommandLine:&cmdline];
        int pid = [self launchVimProcessWithArguments:cmdline
                                     workingDirectory:cwd];
        if (-1 == pid)
            return NO;

        // TODO: If the Vim process fails to start, or if it changes PID,
        // then the memory allocated for these parameters will leak.
        // Ensure that this cannot happen or somehow detect it.

        if ([arguments count] > 0)
            [pidArguments setObject:arguments
                             forKey:[NSNumber numberWithInt:pid]];
    }

    return YES;
}

- (MMVimController *)getVimController {
    // NOTE: After calling this message the backend corresponding to the
    // returned vim controller must be sent an acknowledgeConnection message,
    // else the vim process will be stuck.
    //
    // This method may return nil even though the cache might be non-empty; the
    // caller should handle this by starting a new Vim process.

    int i, count = [self countOfCachedVimControllers];
    if (0 == count) return nil;

    // Locate the first Vim controller with up-to-date rc-files sourced.
    NSDate *rcDate = [self rcFilesModificationDate];
    for (i = 0; i < count; ++i) {
        MMVimController *vc = [self objectInCachedVimControllersAtIndex:i];
        NSDate *date = [vc creationDate];
        if ([date compare:rcDate] != NSOrderedAscending)
            break;
    }

    if (i > 0) {
        // Clear out cache entries whose vimrc/gvimrc files were sourced before
        // the latest modification date for those files.  This ensures that the
        // latest rc-files are always sourced for new windows.
        [self clearPreloadCacheWithCount:i];
    }

    if ([self countOfCachedVimControllers] == 0) {
        [self scheduleVimControllerPreloadAfterDelay:2.0];
        return nil;
    }

    MMVimController *vc = [self objectInCachedVimControllersAtIndex:0];
    [self.mutableVimControllers addObject:vc];
    [self.mutableCachedVimControllers removeObjectAtIndex:0];
    [vc setIsPreloading:NO];

    // Since we've taken one controller from the cache we take the opportunity
    // to preload another.
    [self scheduleVimControllerPreloadAfterDelay:1];

    return vc;
}

- (void)removeVimController:(MMVimController *)controller {
    ASLogDebug(@"Remove Vim controller pid=%d id=%d (processingFlag=%d)", controller.pid, controller.vimControllerId, processingFlag);

    NSUInteger idx = [self.vimControllers indexOfObject:controller];
    if (NSNotFound == idx) {
        ASLogDebug(@"Controller not found, probably due to duplicate removal");
        return;
    }

    [controller retain];
    [self.mutableVimControllers removeObjectAtIndex:idx];
    [controller cleanup];
    [controller release];

    // There is a small delay before the Vim process actually exits so wait a
    // little before trying to reap the child process.  If the process still
    // hasn't exited after this wait it won't be reaped until the next time
    // reapChildProcesses: is called (but this should be harmless).
    [self performSelector:@selector(reapChildProcesses:) withObject:nil afterDelay:0.1];
}

- (void)cleanUp {
    [self removeInputSourceChangedObserver];

    [self stopWatchingVimDir];

    [connection invalidate];

    // Try to wait for all child processes to avoid leaving zombies behind (but
    // don't wait around for too long).
    NSDate *timeOutDate = [NSDate dateWithTimeIntervalSinceNow:2];
    while ([timeOutDate timeIntervalSinceNow] > 0) {
        [self reapChildProcesses:nil];

        if (numChildProcesses <= 0) {
            break;
        }

        ASLogDebug(@"%d processes still left, hold on...", numChildProcesses);

        // Run in NSConnectionReplyMode while waiting instead of calling e.g.
        // usleep().  Otherwise incoming messages may clog up the DO queues and
        // the outgoing TerminateNowMsgID sent earlier never reaches the Vim
        // process.
        // This has at least one side-effect, namely we may receive the
        // annoying "dropping incoming DO message".  (E.g. this may happen if
        // you quickly hit Cmd-n several times in a row and then immediately
        // press Cmd-q, Enter.)
        while (CFRunLoopRunInMode((CFStringRef) NSConnectionReplyMode, 0.05, true) == kCFRunLoopRunHandledSource); // do nothing
    }

    if (numChildProcesses > 0) {
        ASLogNotice(@"%d zombies left behind", numChildProcesses);
    }
}

- (BOOL)processesAboutToLaunch {
    // Don't open an untitled window if there are processes about to launch...
    NSUInteger numLaunching = [pidArguments count];
    if (numLaunching > 0) {
        // ...unless the launching process is being preloaded
        NSNumber *key = [NSNumber numberWithInt:preloadPid];
        if (numLaunching != 1 || [pidArguments objectForKey:key] == nil)
            return YES;
    }

    return NO;
}

- (void)terminateAllVimProcesses {
    // Tell all Vim processes to terminate now (otherwise they'll leave swap
    // files behind).
    NSEnumerator *e = [self enumeratorOfVimControllers];
    id vc;
    while ((vc = [e nextObject])) {
        ASLogDebug(@"Terminate pid=%d", [vc pid]);
        [vc sendMessage:TerminateNowMsgID data:nil];
    }

    e = [self enumeratorOfCachedVimControllers];
    while ((vc = [e nextObject])) {
        ASLogDebug(@"Terminate pid=%d (cached)", [vc pid]);
        [vc sendMessage:TerminateNowMsgID data:nil];
    }

    // If a Vim process is being preloaded as we quit we have to forcibly
    // kill it since we have not established a connection yet.
    if (preloadPid > 0) {
        ASLogDebug(@"Kill incomplete preloaded process pid=%d", preloadPid);
        kill(preloadPid, SIGKILL);
    }

    // If a Vim process was loading as we quit we also have to kill it.
    e = [[pidArguments allKeys] objectEnumerator];
    NSNumber *pidKey;
    while ((pidKey = [e nextObject])) {
        ASLogDebug(@"Kill incomplete process pid=%d", [pidKey intValue]);
        kill([pidKey intValue], SIGKILL);
    }

    // Sleep a little to allow all the Vim processes to exit.
    usleep(10000);
}

#pragma mark vimControllers
- (NSMutableArray *)mutableVimControllers {
    @synchronized (self) {
        return _vimControllers;
    }
}

- (NSUInteger)countOfVimControllers {
    return self.vimControllers.count;
}

- (NSEnumerator *)enumeratorOfVimControllers {
    return self.vimControllers.objectEnumerator;
}

- (MMVimController *)objectInVimControllersAtIndex:(NSUInteger)index {
    return self.vimControllers[index];
}

#pragma mark cachedVimControllers
- (NSMutableArray *)mutableCachedVimControllers {
    @synchronized (self) {
        return _cachedVimControllers;
    }
}

- (NSUInteger)countOfCachedVimControllers {
    return self.cachedVimControllers.count;
}

- (NSEnumerator *)enumeratorOfCachedVimControllers {
    return self.cachedVimControllers.objectEnumerator;
}

- (MMVimController *)objectInCachedVimControllersAtIndex:(NSUInteger)index {
    return self.cachedVimControllers[index];
}

#pragma mark NSObject
- (id)init {
    self = [super init];
    if (self) {
        inputQueues = [[NSMutableDictionary alloc] init];
        _vimControllers = [[NSMutableArray alloc] init];
        _cachedVimControllers = [[NSMutableArray alloc] init];

        preloadPid = -1;
        pidArguments = [[NSMutableDictionary alloc] init];

        // NOTE: Do not use the default connection since the Logitech Control
        // Center (LCC) input manager steals and this would cause MacVim to
        // never open any windows.  (This is a bug in LCC but since they are
        // unlikely to fix it, we graciously give them the default connection.)
        connection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        [connection setRootObject:self];
        [connection setRequestTimeout:MMRequestTimeout];
        [connection setReplyTimeout:MMReplyTimeout];

        // NOTE!  If the name of the connection changes here it must also be
        // updated in MMBackend.m.
        NSString *name = [NSString stringWithFormat:@"%@-connection", [[NSBundle mainBundle] bundlePath]];
        if (![connection registerName:name]) {
            ASLogCrit(@"Failed to register connection with name '%@'", name);
            [connection release];
            connection = nil;
        }
    }

    return self;
}

- (void)dealloc {
    [connection release];
    [inputQueues release];
    [_vimControllers release];
    [_cachedVimControllers release];
    [pidArguments release];

    [super dealloc];
}

#pragma mark MMAppProtocol
- (unsigned)connectBackend:(byref in id <MMBackendProtocol>)proxy pid:(int)pid {
    ASLogDebug(@"pid=%d", pid);

    [(NSDistantObject *) proxy setProtocolForProxy:@protocol(MMBackendProtocol)];

    // NOTE: Allocate the vim controller now but don't add it to the list of
    // controllers since this is a distributed object call and as such can
    // arrive at unpredictable times (e.g. while iterating the list of vim
    // controllers).
    // (What if input arrives before the vim controller is added to the list of
    // controllers?  This should not be a problem since the input isn't
    // processed immediately (see processInput:forIdentifier:).)
    // Also, since the app may be multithreaded (e.g. as a result of showing
    // the open panel) we have to ensure this call happens on the main thread,
    // else there is a race condition that may lead to a crash.
    MMVimController *vc = [[MMVimController alloc] initWithBackend:proxy pid:pid];

    [self performSelectorOnMainThread:@selector(addVimController:)
                           withObject:vc
                        waitUntilDone:NO
                                modes:@[NSDefaultRunLoopMode]];

    [vc release];

    return [vc vimControllerId];
}

- (oneway void)processInput:(in bycopy NSArray *)queue forIdentifier:(unsigned)identifier {
    // NOTE: Input is not handled immediately since this is a distributed
    // object call and as such can arrive at unpredictable times.  Instead,
    // queue the input and process it when the run loop is updated.

    if (!(queue && identifier)) {
        ASLogWarn(@"Bad input for identifier=%d", identifier);
        return;
    }

    ASLogDebug(@"QUEUE for identifier=%d: <<< %@>>>", identifier,
    debugStringForMessageQueue(queue));

    NSNumber *key = [NSNumber numberWithUnsignedInt:identifier];
    NSArray *q = [inputQueues objectForKey:key];
    if (q) {
        q = [q arrayByAddingObjectsFromArray:queue];
        [inputQueues setObject:q forKey:key];
    } else {
        [inputQueues setObject:queue forKey:key];
    }

    // NOTE: We must use "event tracking mode" as well as "default mode",
    // otherwise the input queue will not be processed e.g. during live
    // resizing.
    // Also, since the app may be multithreaded (e.g. as a result of showing
    // the open panel) we have to ensure this call happens on the main thread,
    // else there is a race condition that may lead to a crash.
    [self performSelectorOnMainThread:@selector(processInputQueues:)
                           withObject:nil
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:
                                        NSDefaultRunLoopMode,
                                        NSEventTrackingRunLoopMode, nil]];
}

- (NSArray *)serverList {
    NSMutableArray *array = [NSMutableArray array];

    unsigned i, count = self.countOfVimControllers;
    for (i = 0; i < count; ++i) {
        MMVimController *controller = [self objectInVimControllersAtIndex:i];
        if ([controller serverName])
            [array addObject:[controller serverName]];
    }

    return array;
}

#pragma mark Static
+ (MMVimManager *)sharedManager {
    static MMVimManager *_instance = nil;

    @synchronized (self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
        }
    }

    return _instance;
}

#pragma mark Private
- (void)reapChildProcesses:(id)sender {
    // NOTE: numChildProcesses (currently) only counts the number of Vim
    // processes that have been started with executeInLoginShell::.  If other
    // processes are spawned this code may need to be adjusted (or
    // numChildProcesses needs to be incremented when such a process is
    // started).
    while (numChildProcesses > 0) {
        int status = 0;
        int pid = waitpid(-1, &status, WNOHANG);
        if (pid <= 0)
            break;

        ASLogDebug(@"Wait for pid=%d complete", pid);
        --numChildProcesses;
    }
}

- (void)processInputQueues:(id)sender {
    // NOTE: Because we use distributed objects it is quite possible for this
    // function to be re-entered.  This can cause all sorts of unexpected
    // problems so we guard against it here so that the rest of the code does
    // not need to worry about it.

    // The processing flag is > 0 if this function is already on the call
    // stack; < 0 if this function was also re-entered.
    if (processingFlag != 0) {
        ASLogDebug(@"BUSY!");
        processingFlag = -1;
        return;
    }

    // NOTE: Be _very_ careful that no exceptions can be raised between here
    // and the point at which 'processingFlag' is reset.  Otherwise the above
    // test could end up always failing and no input queues would ever be
    // processed!
    processingFlag = 1;

    // NOTE: New input may arrive while we're busy processing; we deal with
    // this by putting the current queue aside and creating a new input queue
    // for future input.
    NSDictionary *queues = inputQueues;
    inputQueues = [NSMutableDictionary new];

    // Pass each input queue on to the vim controller with matching
    // identifier (and note that it could be cached).
    NSEnumerator *e = [queues keyEnumerator];
    NSNumber *key;
    while ((key = [e nextObject])) {
        unsigned ukey = [key unsignedIntValue];
        int i = 0, count = self.countOfVimControllers;
        for (i = 0; i < count; ++i) {
            MMVimController *vc = [self objectInVimControllersAtIndex:i];
            if (ukey == [vc vimControllerId]) {
                [vc processInputQueue:[queues objectForKey:key]]; // !exceptions
                break;
            }
        }

        if (i < count) continue;

        count = [self countOfCachedVimControllers];
        for (i = 0; i < count; ++i) {
            MMVimController *vc = [self objectInCachedVimControllersAtIndex:i];
            if (ukey == [vc vimControllerId]) {
                [vc processInputQueue:[queues objectForKey:key]]; // !exceptions
                break;
            }
        }

        if (i == count) {
            ASLogWarn(@"No Vim controller for identifier=%d", ukey);
        }
    }

    [queues release];

    // If new input arrived while we were processing it would have been
    // blocked so we have to schedule it to be processed again.
    if (processingFlag < 0)
        [self performSelectorOnMainThread:@selector(processInputQueues:)
                               withObject:nil
                            waitUntilDone:NO
                                    modes:@[NSDefaultRunLoopMode, NSEventTrackingRunLoopMode]];

    processingFlag = 0;
}

// HACK: fileAttributesAtPath was deprecated in 10.5
#define MM_fileAttributes(fm,p) [fm attributesOfItemAtPath:p error:NULL]

- (NSDate *)rcFilesModificationDate {
    // Check modification dates for ~/.vimrc and ~/.gvimrc and return the
    // latest modification date.  If ~/.vimrc does not exist, check ~/_vimrc
    // and similarly for gvimrc.
    // Returns distantPath if no rc files were found.

    NSDate *date = [NSDate distantPast];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *path = [@"~/.vimrc" stringByExpandingTildeInPath];
    NSDictionary *attr = MM_fileAttributes(fm, path);
    if (!attr) {
        path = [@"~/_vimrc" stringByExpandingTildeInPath];
        attr = MM_fileAttributes(fm, path);
    }
    NSDate *modDate = [attr objectForKey:NSFileModificationDate];
    if (modDate)
        date = modDate;

    path = [@"~/.gvimrc" stringByExpandingTildeInPath];
    attr = MM_fileAttributes(fm, path);
    if (!attr) {
        path = [@"~/_gvimrc" stringByExpandingTildeInPath];
        attr = MM_fileAttributes(fm, path);
    }
    modDate = [attr objectForKey:NSFileModificationDate];
    if (modDate)
        date = [date laterDate:modDate];

    return date;
}

#undef MM_fileAttributes


- (void)startWatchingVimDir {
    if (fsEventStream)
        return;
    if (NULL == FSEventStreamStart)
        return; // FSEvent functions are weakly linked

    NSString *path = [@"~/.vim" stringByExpandingTildeInPath];
    NSArray *pathsToWatch = [NSArray arrayWithObject:path];

    fsEventStream = FSEventStreamCreate(NULL, &fsEventCallback, NULL,
            (CFArrayRef) pathsToWatch, kFSEventStreamEventIdSinceNow,
            MMEventStreamLatency, kFSEventStreamCreateFlagNone);

    FSEventStreamScheduleWithRunLoop(fsEventStream,
            [[NSRunLoop currentRunLoop] getCFRunLoop],
            kCFRunLoopDefaultMode);

    FSEventStreamStart(fsEventStream);
    ASLogDebug(@"Started FS event stream");
}

- (void)stopWatchingVimDir {
    if (NULL == FSEventStreamStop)
        return; // FSEvent functions are weakly linked

    if (fsEventStream) {
        FSEventStreamStop(fsEventStream);
        FSEventStreamInvalidate(fsEventStream);
        FSEventStreamRelease(fsEventStream);
        fsEventStream = NULL;
        ASLogDebug(@"Stopped FS event stream");
    }
}

- (void)clearPreloadCacheWithCount:(int)count {
    // Remove the 'count' first entries in the preload cache.  It is assumed
    // that objects are added/removed from the cache in a FIFO manner so that
    // this effectively clears the 'count' oldest entries.
    // If 'count' is negative, then the entire cache is cleared.

    if ([self countOfCachedVimControllers] == 0 || count == 0)
        return;

    if (count < 0)
        count = [self countOfCachedVimControllers];

    // Make sure the preloaded Vim processes get killed or they'll just hang
    // around being useless until MacVim is terminated.
    NSEnumerator *e = [self enumeratorOfCachedVimControllers];
    MMVimController *vc;
    int n = count;
    while ((vc = [e nextObject]) && n-- > 0) {
        [[NSNotificationCenter defaultCenter] removeObserver:vc];
        [vc sendMessage:TerminateNowMsgID data:nil];

        // Since the preloaded processes were killed "prematurely" we have to
        // manually tell them to cleanup (it is not enough to simply release
        // them since deallocation and cleanup are separated).
        [vc cleanup];
    }

    n = count;
    while (n-- > 0 && [self countOfCachedVimControllers] > 0)
        [self.mutableCachedVimControllers removeObjectAtIndex:0];

    // There is a small delay before the Vim process actually exits so wait a
    // little before trying to reap the child process.  If the process still
    // hasn't exited after this wait it won't be reaped until the next time
    // reapChildProcesses: is called (but this should be harmless).
    [self performSelector:@selector(reapChildProcesses:)
               withObject:nil
               afterDelay:0.1];
}

- (void)scheduleVimControllerPreloadAfterDelay:(NSTimeInterval)delay {
    [self performSelector:@selector(preloadVimController:) withObject:nil afterDelay:delay];
}

- (void)cancelVimControllerPreloadRequests {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(preloadVimController:) object:nil];
}

- (void)preloadVimController:(id)sender {
    // We only allow preloading of one Vim process at a time (to avoid hogging
    // CPU), so schedule another preload in a little while if necessary.
    if (-1 != preloadPid) {
        [self scheduleVimControllerPreloadAfterDelay:2];
        return;
    }

    if ([self countOfCachedVimControllers] >= [self maxPreloadCacheSize])
        return;

    preloadPid = [self launchVimProcessWithArguments:
            [NSArray arrayWithObject:@"--mmwaitforack"]
                                    workingDirectory:nil];

    // This method is kicked off via FSEvents, so if MacVim is in the
    // background, the runloop won't bother flushing the autorelease pool.
    // Triggering an NSEvent works around this.
    // http://www.mikeash.com/pyblog/more-fun-with-autorelease.html
    NSEvent *event = [NSEvent otherEventWithType:NSApplicationDefined
                                        location:NSZeroPoint
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:0
                                         context:nil
                                         subtype:0
                                           data1:0
                                           data2:0];
    [NSApp postEvent:event atStart:NO];
}

- (int)launchVimProcessWithArguments:(NSArray *)args workingDirectory:(NSString *)cwd {
    int pid = -1;
    NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"Vim"];

    if (!path) {
        ASLogCrit(@"Vim executable could not be found inside app bundle!");
        return -1;
    }

    // Change current working directory so that the child process picks it up.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *restoreCwd = nil;
    if (cwd) {
        restoreCwd = [fm currentDirectoryPath];
        [fm changeCurrentDirectoryPath:cwd];
    }

    NSArray *taskArgs = [NSArray arrayWithObjects:@"-g", @"-f", nil];
    if (args)
        taskArgs = [taskArgs arrayByAddingObjectsFromArray:args];

    BOOL useLoginShell = [[NSUserDefaults standardUserDefaults]
            boolForKey:MMLoginShellKey];
    if (useLoginShell) {
        // Run process with a login shell, roughly:
        //   echo "exec Vim -g -f args" | ARGV0=-`basename $SHELL` $SHELL [-l]
        pid = [self executeInLoginShell:path arguments:taskArgs];
    } else {
        // Run process directly:
        //   Vim -g -f args
        NSTask *task = [NSTask launchedTaskWithLaunchPath:path
                                                arguments:taskArgs];
        pid = task ? [task processIdentifier] : -1;
    }

    if (-1 != pid) {
        // The 'pidArguments' dictionary keeps arguments to be passed to the
        // process when it connects (this is in contrast to arguments which are
        // passed on the command line, like '-f' and '-g').
        // NOTE: If there are no arguments to pass we still add a null object
        // so that we can use this dictionary to check if there are any
        // processes loading.
        NSNumber *pidKey = [NSNumber numberWithInt:pid];
        if (![pidArguments objectForKey:pidKey])
            [pidArguments setObject:[NSNull null] forKey:pidKey];
    } else {
        ASLogWarn(@"Failed to launch Vim process: args=%@, useLoginShell=%d",
        args, useLoginShell);
    }

    // Now that child has launched, restore the current working directory.
    if (restoreCwd)
        [fm changeCurrentDirectoryPath:restoreCwd];

    return pid;
}

- (int)executeInLoginShell:(NSString *)path arguments:(NSArray *)args {
    // Start a login shell and execute the command 'path' with arguments 'args'
    // in the shell.  This ensures that user environment variables are set even
    // when MacVim was started from the Finder.

    int pid = -1;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    // Determine which shell to use to execute the command.  The user
    // may decide which shell to use by setting a user default or the
    // $SHELL environment variable.
    NSString *shell = [ud stringForKey:MMLoginShellCommandKey];
    if (!shell || [shell length] == 0)
        shell = [[[NSProcessInfo processInfo] environment]
                objectForKey:@"SHELL"];
    if (!shell)
        shell = @"/bin/bash";

    // Bash needs the '-l' flag to launch a login shell.  The user may add
    // flags by setting a user default.
    NSString *shellArgument = [ud stringForKey:MMLoginShellArgumentKey];
    if (!shellArgument || [shellArgument length] == 0) {
        if ([[shell lastPathComponent] isEqual:@"bash"])
            shellArgument = @"-l";
        else
            shellArgument = nil;
    }

    // Build input string to pipe to the login shell.
    NSMutableString *input = [NSMutableString stringWithFormat:
            @"exec \"%@\"", path];
    if (args) {
        // Append all arguments, making sure they are properly quoted, even
        // when they contain single quotes.
        NSEnumerator *e = [args objectEnumerator];
        id obj;

        while ((obj = [e nextObject])) {
            NSMutableString *arg = [NSMutableString stringWithString:obj];
            [arg replaceOccurrencesOfString:@"'" withString:@"'\"'\"'"
                                    options:NSLiteralSearch
                                      range:NSMakeRange(0, [arg length])];
            [input appendFormat:@" '%@'", arg];
        }
    }

    // Build the argument vector used to start the login shell.
    NSString *shellArg0 = [NSString stringWithFormat:@"-%@",
                                                     [shell lastPathComponent]];
    char *shellArgv[3] = {(char *) [shellArg0 UTF8String], NULL, NULL};
    if (shellArgument)
        shellArgv[1] = (char *) [shellArgument UTF8String];

    // Get the C string representation of the shell path before the fork since
    // we must not call Foundation functions after a fork.
    const char *shellPath = [shell fileSystemRepresentation];

    // Fork and execute the process.
    int ds[2];
    if (pipe(ds)) return -1;

    pid = fork();
    if (pid == -1) {
        return -1;
    } else if (pid == 0) {
        // Child process

        if (close(ds[1]) == -1) exit(255);
        if (dup2(ds[0], 0) == -1) exit(255);

        // Without the following call warning messages like this appear on the
        // console:
        //     com.apple.launchd[69] : Stray process with PGID equal to this
        //                             dead job: PID 1589 PPID 1 Vim
        setsid();

        execv(shellPath, shellArgv);

        // Never reached unless execv fails
        exit(255);
    } else {
        // Parent process
        if (close(ds[0]) == -1) return -1;

        // Send input to execute to the child process
        [input appendString:@"\n"];
        int bytes = [input lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

        if (write(ds[1], [input UTF8String], bytes) != bytes) return -1;
        if (close(ds[1]) == -1) return -1;

        ++numChildProcesses;
        ASLogDebug(@"new process pid=%d (count=%d)", pid, numChildProcesses);
    }

    return pid;
}

- (void)addVimController:(MMVimController *)vc {
    ASLogDebug(@"Add Vim controller pid=%d id=%d",
    [vc pid], [vc vimControllerId]);

    int pid = [vc pid];
    NSNumber *pidKey = [NSNumber numberWithInt:pid];
    id args = [pidArguments objectForKey:pidKey];

    if (preloadPid == pid) {
        // This controller was preloaded, so add it to the cache and
        // schedule another vim process to be preloaded.
        preloadPid = -1;
        [vc setIsPreloading:YES];
        [self.mutableCachedVimControllers addObject:vc];
        [self scheduleVimControllerPreloadAfterDelay:1];
    } else {
        [self.mutableVimControllers addObject:vc];

        if (args && [NSNull null] != args)
            [vc passArguments:args];

        // HACK!  MacVim does not get activated if it is launched from the
        // terminal, so we forcibly activate here.  Note that each process
        // launched from MacVim has an entry in the pidArguments dictionary,
        // which is how we detect if the process was launched from the
        // terminal.
        if (!args) [self markLastVimControllerHasArgs];
    }

    if (args)
        [pidArguments removeObjectForKey:pidKey];
}

- (void)markLastVimControllerHasArgs {
    ASLogDebug(@"Activate MacVim when next window opens (last vim controller had arguments)");
    lastVimControllerHasArgs = YES;
}

- (void)addInputSourceChangedObserver {
    // The TIS symbols are weakly linked.
    if (NULL != TISCopyCurrentKeyboardInputSource) {
        // We get here when compiled on >=10.5 and running on >=10.5.

        id nc = [NSDistributedNotificationCenter defaultCenter];
        NSString *notifyInputSourceChanged =
                (NSString *) kTISNotifySelectedKeyboardInputSourceChanged;
        [nc addObserver:self
               selector:@selector(inputSourceChanged:)
                   name:notifyInputSourceChanged
                 object:nil];
    }
}

- (void)inputSourceChanged:(NSNotification *)notification {
    unsigned i, count = [self countOfVimControllers];
    for (i = 0; i < count; ++i) {
        MMVimController *controller = [self objectInVimControllersAtIndex:i];
        MMWindowController *wc = [controller windowController];
        MMTextView *tv = (MMTextView *) [[wc vimView] textView];
        [tv checkImState];
    }
}

- (void)removeInputSourceChangedObserver {
    // The TIS symbols are weakly linked.
    if (NULL != TISCopyCurrentKeyboardInputSource) {
        // We get here when compiled on >=10.5 and running on >=10.5.

        id nc = [NSDistributedNotificationCenter defaultCenter];
        [nc removeObserver:self];
    }
}

- (NSDictionary *)convertVimControllerArguments:(NSDictionary *)args
                                  toCommandLine:(NSArray **)cmdline {
    // Take all arguments out of 'args' and put them on an array suitable to
    // pass as arguments to launchVimProcessWithArguments:.  The untouched
    // dictionary items are returned in a new autoreleased dictionary.

    if (cmdline)
        *cmdline = nil;

    NSArray *filenames = [args objectForKey:@"filenames"];
    int numFiles = filenames ? [filenames count] : 0;
    BOOL openFiles = ![[args objectForKey:@"dontOpen"] boolValue];

    if (numFiles <= 0 || !openFiles)
        return args;

    NSMutableArray *a = [NSMutableArray array];
    NSMutableDictionary *d = [[args mutableCopy] autorelease];

    // Search for text and highlight it (this Vim script avoids warnings in
    // case there is no match for the search text).
    NSString *searchText = [args objectForKey:@"searchText"];
    if (searchText && [searchText length] > 0) {
        [a addObject:@"-c"];
        NSString *s = [NSString stringWithFormat:@"if search('\\V\\c%@','cW')"
                                                         "|let @/='\\V\\c%@'|set hls|endif", searchText, searchText];
        [a addObject:s];

        [d removeObjectForKey:@"searchText"];
    }

    // Position cursor using "+line" or "-c :cal cursor(line,column)".
    NSString *lineString = [args objectForKey:@"cursorLine"];
    if (lineString && [lineString intValue] > 0) {
        NSString *columnString = [args objectForKey:@"cursorColumn"];
        if (columnString && [columnString intValue] > 0) {
            [a addObject:@"-c"];
            [a addObject:[NSString stringWithFormat:@":cal cursor(%@,%@)",
                                                    lineString, columnString]];

            [d removeObjectForKey:@"cursorColumn"];
        } else {
            [a addObject:[NSString stringWithFormat:@"+%@", lineString]];
        }

        [d removeObjectForKey:@"cursorLine"];
    }

    // Set selection using normal mode commands.
    NSString *rangeString = [args objectForKey:@"selectionRange"];
    if (rangeString) {
        NSRange r = NSRangeFromString(rangeString);
        [a addObject:@"-c"];
        if (r.length > 0) {
            // Select given range of characters.
            // TODO: This only works for encodings where 1 byte == 1 character
            [a addObject:[NSString stringWithFormat:@"norm %ldgov%ldgo",
                                                    r.location, NSMaxRange(r) - 1]];
        } else {
            // Position cursor on line at start of range.
            [a addObject:[NSString stringWithFormat:@"norm %ldGz.0",
                                                    r.location]];
        }

        [d removeObjectForKey:@"selectionRange"];
    }

    // Choose file layout using "-[o|O|p]".
    int layout = [[args objectForKey:@"layout"] intValue];
    switch (layout) {
        case MMLayoutHorizontalSplit:
            [a addObject:@"-o"];
            break;
        case MMLayoutVerticalSplit:
            [a addObject:@"-O"];
            break;
        case MMLayoutTabs:
            [a addObject:@"-p"];
            break;
    }
    [d removeObjectForKey:@"layout"];


    // Last of all add the names of all files to open (DO NOT add more args
    // after this point).
    [a addObjectsFromArray:filenames];

    if ([args objectForKey:@"remoteID"]) {
        // These files should be edited remotely so keep the filenames on the
        // argument list -- they will need to be passed back to Vim when it
        // checks in.  Also set the 'dontOpen' flag or the files will be
        // opened twice.
        [d setObject:[NSNumber numberWithBool:YES] forKey:@"dontOpen"];
    } else {
        [d removeObjectForKey:@"dontOpen"];
        [d removeObjectForKey:@"filenames"];
    }

    if (cmdline)
        *cmdline = a;

    return d;
}

- (NSString *)workingDirectoryForArguments:(NSDictionary *)args {
    // Find the "filenames" argument and pick the first path that actually
    // exists and return it.
    // TODO: Return common parent directory in the case of multiple files?
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *filenames = [args objectForKey:@"filenames"];
    NSUInteger i, count = [filenames count];
    for (i = 0; i < count; ++i) {
        BOOL isdir;
        NSString *file = [filenames objectAtIndex:i];
        if ([fm fileExistsAtPath:file isDirectory:&isdir])
            return isdir ? file : [file stringByDeletingLastPathComponent];
    }

    return nil;
}

@end