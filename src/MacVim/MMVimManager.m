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


// Default timeout intervals on all connections.
static NSTimeInterval MMRequestTimeout = 5;
static NSTimeInterval MMReplyTimeout = 5;


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
}

@synthesize mutableVimControllers = _vimControllers;
@synthesize mutableCachedVimControllers = _cachedVimControllers;

#pragma mark Public
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

#pragma mark vimControllers
- (NSUInteger)countOfVimControllers {
    return self.vimControllers.count;
}

- (NSEnumerator *)enumeratorOfVimControllers {
    return self.vimControllers.objectEnumerator;
}

#pragma mark cachedVimControllers
- (NSEnumerator *)enumeratorOfCachedVimControllers {
    return self.cachedVimControllers.objectEnumerator;
}

#pragma mark NSObject
- (id)init {
    self = [super init];
    if (self) {
        inputQueues = [[NSMutableDictionary alloc] init];
        _vimControllers = [[NSMutableArray alloc] init];
        _cachedVimControllers = [[NSMutableArray alloc] init];

        // NOTE: Do not use the default connection since the Logitech Control
        // Center (LCC) input manager steals and this would cause MacVim to
        // never open any windows.  (This is a bug in LCC but since they are
        // unlikely to fix it, we graciously give them the default connection.)
        connection = [[NSConnection alloc] initWithReceivePort:[NSPort port]
                                                      sendPort:nil];
        [connection setRootObject:self];
        [connection setRequestTimeout:MMRequestTimeout];
        [connection setReplyTimeout:MMReplyTimeout];

        // NOTE!  If the name of the connection changes here it must also be
        // updated in MMBackend.m.
        NSString *name = [NSString stringWithFormat:@"%@-connection",
                                                    [[NSBundle mainBundle] bundlePath]];
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
    MMVimController *vc = [[MMVimController alloc] initWithBackend:proxy
                                                               pid:pid];
    [self performSelectorOnMainThread:@selector(addVimController:)
                           withObject:vc
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObject:
                                        NSDefaultRunLoopMode]];

    [vc release];

    return [vc vimControllerId];
}

- (oneway void)processInput:(in bycopy NSArray *)queue
              forIdentifier:(unsigned)identifier {
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

    unsigned i, count = [_vimControllers count];
    for (i = 0; i < count; ++i) {
        MMVimController *controller = [_vimControllers objectAtIndex:i];
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

@end